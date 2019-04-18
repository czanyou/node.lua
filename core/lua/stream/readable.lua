--[[

Copyright 2014 The Luvit Authors. All Rights Reserved.
Copyright 2016 The Node.lua Authors. All Rights Reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS-IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

--]]

local core  = require('core')
local utils = require('util')

local Error  = core.Error

-------------------------------------------------------------------------------
-- len

local len,
_readableEmitEnd,
_readableEmitReadable,
_readableFlow,
_readableMaybeReadMore,
_readableMaybeReadMoreNextTick,
_readablePipeOnDrain,
_readablePushChunk,
_readableRead,
_readableReadFromBuffer,
_readableResume,
_readableResumeNextTick,
_stateCheckChunk,
_stateHowMuchToRead,
_stateNeedMoreData,
_stateReadFromBuffer,
_stateRoundUpToNextPowerOf2,
_stateWriteToBuffer

function len(buf)
    if type(buf) == 'string' then
        return string.len(buf)

    elseif type(buf) == 'table' then
        return #buf

    else
        return -1
    end
end


-------------------------------------------------------------------------------
-- ReadableState

local ReadableState = core.Object:extend()

function ReadableState:initialize(options, stream)
      options = options or { }

      --[[
      // the point at which it stops calling _read() to fill the buffer
      // Note: 0 is a valid value, means "don't call _read preemptively ever"
      --]]
      local defaultHwm = 16
      if not options.objectMode then
          defaultHwm = 16 * 1024
      end

      self.highWaterMark = options.highWaterMark or defaultHwm -- 水位标记, 用来触发 readable 等事件的临界点

      self.buffer     = { }     -- 这个流的内部缓存区
      self.length     = 0       -- 这个流的内部缓存的数据的长度
      self.pipes      = nil     --
      self.pipesCount = 0       --
      self.flowing    = nil     -- 指出当前流是否处于流动模式
      self.ended      = false   -- 指出当前流是否已结束, 表示底层数据源已读完或关闭不会再提供更多数据了
      self.endEmitted = false   -- 指出 'end' 事件是否已发出, 这时才彻底表示这个流已经完全关闭了
      self.reading    = false   -- 指出当前已经调用了 _read 方法请求底层读取数据, 当成功读取到数据后变回 false.

      --[[
      // a flag to be able to tell if the onwrite cb is called immediately,
      // or on a later tick.  We set this to true at first, because any
      // actions that shouldn't happen until "later" should generally also
      // not happen before the first write call.
      --]]
      self.sync       = true    -- 指出当前正在调用 _read 方法且未返回

      --[[
      // whenever we return null, then we set a flag to say
      // that we're awaiting a 'readable' event emission.
      -- 当为 true, 则在下一次有数据 push 到缓存池时发出 'readable' 事件
      --]]
      self.needReadable      = false -- 当缓存区为空或没有足够的数据时, 即没有达到需要的水位线时
      self.emittedReadable   = false -- 当 'readable' 事件已发出
      self.readableListening = false -- 当添加了 'readable' 事件侦听器

      -- object stream flag. Used to make read(n) ignore n and to
      -- make all the buffer merging and length checks go away
      self.objectMode = not not options.objectMode

      --if core.instanceof(stream, Stream.Duplex) then
      --    self.objectMode = self.objectMode or (not not options.readableObjectMode)
      --end

      -- when piping, we only care about 'readable' events that happen
      -- after read()ing all the bytes and not getting any pushback.
      self.ranOut       = false

      -- the number of writers that are awaiting a drain event in .pipe()s
      self.awaitDrain   = 0

      -- if true, a _readableMaybeReadMore has been scheduled
      self.readingMore  = false
end

-- 检查 chunk 类型是否合法
function _stateCheckChunk(state, chunk)
    local err = nil
    if chunk and (type(chunk) ~= 'string') and (not state.objectMode) then
        err = Error:new('Invalid non-string/buffer chunk')
    end

    return err
end

-- 写入指定的数据包到缓存区中
function _stateWriteToBuffer(state, chunk, addToFront)
    if state.objectMode then
        state.length = state.length + 1
    else
        state.length = state.length + len(chunk)
    end

    if addToFront then
        table.insert(state.buffer, 1, chunk)
    else
        table.insert(state.buffer, chunk)
    end
end

-- 从缓存区中读取 n 个字节的数据, 如果缓存区数据小于 n 则返回所有的数据
-- 如果是对象模式, 则只返回队列中的第一个元素.
-- Pluck off n bytes from an array of buffers.
-- Length is the combined lengths of all the buffers in the list.
function _stateReadFromBuffer(state, n)
    n = _stateHowMuchToRead(state, n)

    if (not(n > 0)) then
        return nil
    end

    local list    = state.buffer
    local length  = state.length
    local objectMode = not not state.objectMode
    local ret

    -- nothing in the list, definitely empty.
    if len(list) == 0 then
        return nil
    end

    if length == 0 then
        -- 缓存为空
        ret = nil

    elseif objectMode then
        -- 如果是对象模式, 则只返回队列中的第一个元素.
        ret = table.remove(list, 1)

    elseif (not n) or (n >= length) then
        -- 缓存不足 n 个字节
        ret = table.concat(list, '')
        state.buffer = {}

    else
        -- read just some of it.
        if n < len(list[1]) then
            -- 第一个项目有足够的数据
            -- just take a part of the first list item.
            -- slice is the same for buffers and strings.
            local buf = list[1]
            ret = string.sub(buf, 1, n)
            list[1] = string.sub(buf, n + 1, -1)

        elseif n == len(list[1]) then
            -- 第一个项目刚好有足够的数据
            -- first list is a perfect match
            ret = table.remove(list, 1)

        else
            --[[
            // complex case.
            // we have enough to cover it, but it spans past the first buffer.
            --]]

            -- for better GC efficiency. (http://www.lua.org/pil/11.6.html)
            local tmp = {}
            local c = 0
            for i = 1, len(list), 1 do
                if n - c >= len(list[1]) then
                    -- grab the entire list[1]
                    c = c + list[1]
                    table.insert(tmp, table.remove(list, 1))

                else
                    c = n
                    table.insert(tmp, string.sub(list[1], 1, n - c))
                    list[1] = string.sub(list[1], n + 1, -1)
                    break
                end
            end
            ret = table.concat(tmp)
        end
    end

    if (ret) then
        state.length = state.length - n
    end

    return ret
end

-- 返回实际可以读取的数据长度
-- 0: 如果流已结束而且缓存区为空
-- 0: n == 0
-- state.length: not n & pause mode
-- #state.buffer[1]: not n & flowing mode
-- n: n <= state.length
-- 0: n > state.length
-- state.length: 如果流已结束而且缓存区不为空
function _stateHowMuchToRead(state, n)
    if state.ended and (state.length == 0) then
        return 0
    end

    -------------------------------------------
    -- object mode
    if state.objectMode then
        if n == 0 then
            return 0
        else
            return 1
        end
    end

    -------------------------------------------
    -- 没有指定 n
    -- n ~= n <==> isnan(n)
    if (n ~= n) or (not n) then
        if state.flowing then
            -- 流模式下只返回一个数据包
            local buffer = state.buffer[1]
            if (buffer) then
                return #buffer
            end

            return 0
        else
            -- 暂停模式下返回缓存区中所有数据
            return state.length
        end
    end

    -------------------------------------------
    -- n 为 0
    if (n <= 0) then
        return 0
    end

    --[[
    -- If we're asking for more than the target buffer level,
    -- then raise the water mark.  Bump up to the next highest
    -- power of 2, to prevent increasing it excessively in tiny
    -- amounts.
    --]]
    if n > state.highWaterMark then
        state.highWaterMark = _stateRoundUpToNextPowerOf2(n)
    end

    -------------------------------------------
    -- 缓存区有足够的数据可读
    if n <= state.length then
        return n
    end

    -- 如果缓存区没有那多数据, 而且流已结束则返回缓存区中实际的字节长度
    -- don't have that much. return null, unless we've ended.
    if state.ended then
        return state.length
    end

    return 0
end


--[[
-- 指出是否需要从数据源读取更多的数据.
// if it's past the high water mark, we can push in some more.
// Also, if we have no data yet, we can stand some
// more bytes.  This is to work around cases where hwm=0,
// such as the repl.  Also, if the push() triggered a
// readable event, and the user called read(largeNumber) such that
// needReadable was set, then we ought to push more, so that another
// 'readable' event will be triggered.
--]]
function _stateNeedMoreData(state)
    if (state.ended) then
        return false
    end

    return state.needReadable or (state.length < state.highWaterMark) or (state.length == 0)
end

--[[
// Dont't raise the hwm > 128MB
--]]
local MAX_HWM = 0x800000

function _stateRoundUpToNextPowerOf2(n)
    if n >= MAX_HWM then
        n = MAX_HWM

    else
        n = n - 1
        p = 1
        while p < 32 do
            --n = bit.bor(n, bit.rshift(n, p))
            --p = bit.lshift(p, 1)
            n = n | (n >> p)
            p = (p << 1)
        end
        n = n + 1
    end

    return n
end

-------------------------------------------------------------------------------
-- Readable

-- 结束这个流, 并发出 'end' 的事件
function _readableEmitEnd(stream)
    local state = stream._readableState

    -- If we get here before consuming all the bytes, then that is a
    -- bug in node. Should never happen.
    if state.length > 0 then
        error('_readableEmitEnd called on non-empty stream')
    end

    if state.endEmitted then
        return
    end

    state.ended = true
    process.nextTick(function()
        -- Check that we didn't get one last unshift.
        if (not state.endEmitted) and (state.length == 0) then
            state.endEmitted = true
            stream.readable  = false
            stream:emit('end')
        end
    end)
end

-- 发出 'readable' 事件
-- Don't emit readable right away in sync mode, because this can trigger
-- another read() call => stack overflow. This way, it might trigger
-- a nextTick recursion warning, but that's not so bad.
function _readableEmitReadable(stream)
    local state = stream._readableState
    state.needReadable = false

    if state.emittedReadable then
        return
    end

    state.emittedReadable = true
    if state.sync then
        process.nextTick(function()
            stream:emit('readable')
            _readableFlow(stream)
        end)

    else
        stream:emit('readable')
        _readableFlow(stream)
    end
end

-- 以流的模式一直调用 read() 方法, 直到读到没有数据为止
function _readableFlow(stream)
    local state = stream._readableState
    while state.flowing and (stream:read() ~= nil)  do
        --...
    end
end

-- 推一个数据块 (chunk) 到缓存区中
-- 可能会在 _read 方法中同步调用, 也可能在下一 tick 异步调用这个方法
-- push 方法也会调发下一个 tick 调用 read(0) 方法
-- 返回值指示是否可以继续 push 数据
function _readablePushChunk(stream, chunk, addToFront)
    local state = stream._readableState
    local err = _stateCheckChunk(state, chunk)
    if err then
        -- 传入了无效的参数
        stream:emit('error', err)

    elseif chunk == nil then
        -- 如果调用它时 chunk 传入了 nil 参数，那么它会触发数据结束信号（EOF）。
        state.reading = false
        if not state.ended then
            state.ended = true

            -- emit 'readable' now to make sure it gets picked up.
            _readableEmitReadable(stream)
        end

    elseif state.objectMode or chunk and len(chunk) > 0 then
        if state.ended and not addToFront then
            local err = Error:new('stream.push() after EOF')
            stream:emit('error', err)

        else
            if not addToFront then
                state.reading = false
            end

            if state.flowing and (state.length == 0) and (not state.sync) then
                -- 如果是流模式下异步方式读取到数据, 可以直接用 'data' 事件发出而不用经过缓存池
                -- if we want the data now, just emit it.
                stream:emit('data', chunk)
                stream:read(0)

            else
                -- update the buffer info.
                _stateWriteToBuffer(state, chunk, addToFront)

                if state.needReadable then
                    _readableEmitReadable(stream)
                end

                _readableMaybeReadMore(stream, state)
            end
        end

    elseif not addToFront then
        state.reading = false
    end

    return _stateNeedMoreData(state)
end

--[[
// at this point, the user has presumably seen the 'readable' event,
// and called read() to consume some data.  that may have triggered
// in turn another _read(n) call, in which case reading = true if
// it's in progress.
// However, if we're not ended, or reading, and the length < hwm,
// then go ahead and try to read some more preemptively.
--]]
function _readableMaybeReadMore(stream, state)
    if state.readingMore then
        return
    end

    state.readingMore = true
    process.nextTick(function()
        _readableMaybeReadMoreNextTick(stream, state)
    end)
end

function _readableMaybeReadMoreNextTick(stream, state)
    local lastLength = state.length
    while
            not state.reading
        and not state.flowing
        and not state.ended
        and (state.length < state.highWaterMark)
    do
        stream:read(0)
        if lastLength == state.length then
            -- didn't get any data, stop spinning.
            break
        end

        lastLength = state.length
    end

    state.readingMore = false
end

function _readablePipeOnDrain(src)
    return function()
        local state = src._readableState
        if state.awaitDrain ~= 0 then
            state.awaitDrain = state.awaitDrain - 1
        end

        if state.awaitDrain == 0 and core.Emitter.listenerCount(src, 'data') ~= 0 then
            state.flowing = true
            _readableFlow(src)
        end
    end
end

-- 调用这个方法让指定的流进入流模式
function _readableResume(stream, state)
    if state.resumeScheduled then
        return
    end

    state.resumeScheduled = true
    process.nextTick(function()
        _readableResumeNextTick(stream, state)
    end)
end

function _readableResumeNextTick(stream, state)
    if (not state.reading) then
        stream:read(0)  -- 触发数据读取
    end

    state.resumeScheduled = false
    state.awaitDrain = 0

    stream:emit('resume')
    _readableFlow(stream)
    if state.flowing and not state.reading then
        stream:read(0)
    end
end

-- 从底层读取更多的数据
function _readableRead(stream, n)
    local state = stream._readableState

    -- 如果流已结束则不再有数据可读, 或者已经在读数据中也不再重复读取
    -- however, if we've ended, then there's no point, and if we're already
    -- reading, then it's unnecessary.
    if state.ended then
        return false

    elseif state.reading then
        return false
    end

   --[[
    -- All the actual chunk generation logic needs to be
    -- *below* the call to _read.  The reason is that in certain
    -- synthetic stream cases, such as passthrough streams, _read
    -- may be a completely synchronous operation which may change
    -- the state of the read buffer, providing enough data when
    -- before there was *not* enough.
    --
    -- So, the steps are:
    -- 1. Figure out what the state of things will be after we do
    -- a read from the buffer.
    --
    -- 2. If that resulting state will trigger a _read, then call _read.
    -- Note that this may be asynchronous, or synchronous.  Yes, it is
    -- deeply ugly to write APIs this way, but that still doesn't mean
    -- that the Readable class should behave improperly, as streams are
    -- designed to be sync/async agnostic.
    -- Take note if the _read call is sync or async (ie, if the read call
    -- has returned yet), so that we know whether or not it's safe to emit
    -- 'readable' etc.
    --
    -- 3. Actually pull the requested chunks out of the buffer and return.
    --]]

    -- console.log(state)

    local needRead = false
    if (state.needReadable) then
        -- if we need a readable event, then we need to do some reading.
        -- 如果指明期望 'readable' 事件, 则我们需要读一些数据到缓存中
        needRead = true

    elseif (state.length == 0) then
        -- if we currently have less than the highWaterMark, then also read some
        -- 如果当前缓存的数据低于水位线同样也需要读取一些数据
        needRead = true

    elseif (state.length < state.highWaterMark) then
        needRead = true

    elseif (n and n > 0) then
        n = _stateHowMuchToRead(state, n)
        if (state.length < (state.highWaterMark + n)) then
            needRead = true
        end
    end

    -----------------------------------------------------------
    -- 调用内部 _read 方法从数据源读取数据到内部缓存区

    if needRead then
        -- call internal read method
        state.reading = true
        state.sync    = true
        stream:_read(state.highWaterMark)
        state.sync    = false

        return true
    end

    return false
end

function _readableReadFromBuffer(stream, n)
    local state = stream._readableState

    local ret = _stateReadFromBuffer(state, n)
    if not ret then
        -- 如果缓存区被排空, 则需要重新发出 'readable' 事件
        state.needReadable = true
    end

    -- 如果缓存区被排空, 则需要重新发出 'readable' 事件
    -- If we have nothing in the buffer, then we want to know
    -- as soon as we *do* get something into the buffer.
    if (state.length == 0) and (not state.ended) then
        state.needReadable = true
    end

    --
    -- If we tried to read() past the EOF, then emit end on the next tick.
    --if (nOrig ~= n) and state.ended and (state.length == 0) then
    --    _readableEmitEnd(stream)
    --end

    return ret
end

-------------------------------------------------------------------------------
-- Readable

local Readable = core.Emitter:extend()

function Readable:initialize(options)
    self._readableState = ReadableState:new(options, self)

end

--[[
-- 手动推一些数据到 read() 缓存中
-- 如果没有达到指定水位会返回 true, 表示还可以继续推入一些数据.
-- Manually shove something into the read() buffer.
-- This returns true if the highWaterMark has not been hit yet,
-- similar to how Writable.write() returns true if you should
-- write() some more.
--]]
function Readable:push(chunk)
    return _readablePushChunk(self, chunk, false)
end

-- 这个方法只有在暂停模式下被应用程序调用, 在流模式下会在内部被自动调用.
-- 如果没有指定 n 表示返回缓存区中的所有数据
-- 如果 n 为 0 则只会触发底层读取更多的数据, 而不会实际消耗数据
-- 通过 read 一个缓存区为空的流来触发 'end' 事件
function Readable:read(n)
    local state = self._readableState

    if (type(n) ~= 'number') or (n > 0) then
        state.emittedReadable = false
    end

    -----------------------------------------------------------
    -- 如果 n 为 0, 且有足够的数据, 并且期望 readable 时会触发 'readable' 事件
    -- if we're doing read(0) to trigger a readable event, but we
    -- already have a bunch of data in the buffer, then just trigger
    -- the 'readable' event and move on.
    if (n == 0) and state.needReadable then
        if state.ended then
            if (state.length == 0) then
                _readableEmitEnd(self)
            else
                _readableEmitReadable(self)
            end
            return nil

        elseif (state.length >= state.highWaterMark) then
            if (state.length > 0) then
                _readableEmitReadable(self)
            end
            return nil
        end
    end

    -----------------------------------------------------------
    -- 在流的使用中, 就算底层数据源已关闭, 也要一直读到流的缓存区为空
    -- 时才最终结束这个流, 并发出 'end' 事件
    --
    -- 如果可以返回的数据为 0, 而且流已经结束, 缓存区也清空了, 则发出
    -- 最后的 'end' 事件来彻底完成这个流.

    if state.ended and (state.length == 0) then
        -- 流已经标记为结束 & 缓存区已空
        _readableEmitEnd(self)
        return nil
    end

    -----------------------------------------------------------
    -- 从缓存区中拉取数据

    -- _read 方法可能会同步推一些数据到缓存中, 所以我们要重新计算可以读取的数据
    -- If _read pushed data synchronously, then `reading` will be false,
    -- and we need to re-evaluate how much data we can return to the user.

    --console.log('_readableRead', n)
    _readableRead(self, n)

    local ret = _readableReadFromBuffer(self, n)
    if ret ~= nil then
        -- 当该方法返回了一个有效的数据块时，它同时也会触发 'data' 事件。
        self:emit('data', ret)
    end

    return ret
end

--[[
-- 抽象方法, 实现类必须重写这个方法用来执行实际的读取操作.
-- abstract method. to be overridden in specific implementation classes.
-- call cb(er, data) where data is <= n in length.
-- for virtual (non-string) streams, "length" is somewhat
-- arbitrary, and perhaps not very meaningful.
--]]
function Readable:_read(n)
    self:emit('error', Error:new('not implemented'))
end

function Readable:pipe(dest, pipeOpts)
    local src = self
    local state = self._readableState
    local _endFn, ondrain

    -- local functions
    local onunpipe, onend, cleanup, ondata, onerror, onclose, onfinish, unpipe

    onunpipe = function(readable)
        if readable == src then
            cleanup()
        end
    end

    onend = function()
        dest:_end()
    end

    cleanup = function()
        --[[
        // cleanup event handlers once the pipe is broken
        --]]
        dest:removeListener('close',  onclose)
        dest:removeListener('finish', onfinish)
        dest:removeListener('drain',  ondrain)
        dest:removeListener('error',  onerror)
        dest:removeListener('unpipe', onunpipe)
        src:removeListener('end',  onend)
        src:removeListener('end',  cleanup)
        src:removeListener('data', ondata)

        --[[
        // if the reader is waiting for a drain event from this
        // specific writer, then it would cause it to never start
        // flowing again.
        // So, if this is awaiting a drain, then we just call it now.
        // If we don't know, then assume that we are waiting for one.
        --]]
        if state.awaitDrain and
            (not dest._writableState or dest._writableState.needDrain) then
            ondrain()
        end
    end

    ondata = function(chunk)
        local ret = dest:write(chunk)
        if false == ret then
            src._readableState.awaitDrain = src._readableState.awaitDrain + 1
            src:pause()
        end
    end

    --[[
      // if the dest has an error, then stop piping into it.
      // however, don't suppress the throwing behavior for this.
      --]]
    onerror = function(er)
        unpipe()
        dest:removeListener('error', onerror)
        if core.Emitter.listenerCount(dest, 'error') == 0 then
            dest:emit('error', er)
        end
    end

    --[[
    // Both close and finish should trigger unpipe, but only once.
    --]]
    onclose = function()
        dest:removeListener('finish', onfinish)
        unpipe()
    end

    onfinish = function()
        dest:removeListener('close', onclose)
        unpipe()
    end

    unpipe = function()
        src:unpipe(dest)
    end

    if state.pipesCount == 0 then
        state.pipes = dest
    elseif state.pipesCount == 1 then
        state.pipes = { state.pipes, dest }
    else
        table.insert(state.pipes, dest)
    end
    state.pipesCount = state.pipesCount + 1

    local doEnd = (not pipeOpts or pipeOpts._end ~= false)
      and dest ~= process.stdout
      and dest ~= process.stderr

    if doEnd then
        _endFn = onend
    else
        _endFn = cleanup
    end

    if state.endEmitted then
        process.nextTick(_endFn)
    else
        src:once('end', _endFn)
    end

    dest:on('unpipe', onunpipe)

    --[[
  // when the dest drains, it reduces the awaitDrain counter
  // on the source.  This would be more elegant with a .once()
  // handler in _readableFlow(), but adding and removing repeatedly is
  // too slow.
  --]]
    ondrain = _readablePipeOnDrain(src)
    dest:on('drain', ondrain)

    src:on('data', ondata)

    --[[
  // This is a brutally ugly hack to make sure that our error handler
  // is attached before any userland ones.  NEVER DO THIS.
  if (!dest._events || !dest._events.error)
  dest.on('error', onerror);
  else if (Array.isArray(dest._events.error))
  dest._events.error.unshift(onerror);
  else
  dest._events.error = [onerror, dest._events.error];
  --]]

    dest:once('close', onclose)
    dest:once('finish', onfinish)

    --[[
  // tell the dest that it's being piped to
  --]]
    dest:emit('pipe', src)

    --[[
  // start the _readableFlow if it hasn't been started already.
  --]]
    if not state.flowing then
        src:resume()
    end

    return dest
end

function Readable:unpipe(dest)
    local state = self._readableState

    --[[
  // if we're not piping anywhere, then do nothing.
  --]]
    if state.pipesCount == 0 then
        return self
    end

    --[[
  // just one destination.  most common case.
  --]]
    if state.pipesCount == 1 then
        --[[
    // passed in one, but it's not the right one.
    --]]
        if dest and dest ~= state.pipes then
            return self
        end

        if not dest then
            dest = state.pipes
        end

        --[[
    // got a match.
    --]]
        state.pipes = nil
        state.pipesCount = 0
        state.flowing = false
        if dest then
            dest:emit('unpipe', self)
        end
        return self
    end

    --[[
  // slow case. multiple pipe destinations.
  --]]

    if not dest then
        --[[
    // remove all.
    --]]
        local dests = state.pipes
        local len = state.pipesCount
        state.pipes = nil
        state.pipesCount = 0
        state.flowing = false

        for i = 1, len, 1 do
            dests[i]:emit('unpipe', self)
        end
        return self
    end

    --[[
  // try to find the right one.
  --]]
    local i = state.pipes.indexOf(dest)
    if i == -1 then
        return self
    end

    state.pipes.splice(i, 1)
    state.pipesCount = state.pipesCount - 1
    if state.pipesCount == 1 then
        state.pipes = state.pipes[1]
    end

    dest:emit('unpipe', self)

    return self
end

--[[
-- set up data events if they are asked for
-- Ensure readable listeners eventually get something
--]]
function Readable:on(event, fn)
    local res = core.Emitter.on(self, event, fn)

    local state = self._readableState

    --[[
    -- 侦听 'data' 事件会让这个流自动进入流模式
    -- If listening to data, and it has not explicitly been paused,
    -- then call resume to start the _readableFlow of data on the next tick.
    --]]
    if (event == 'data') then
        if (state.flowing ~= false) then
            self:resume()
        end

    elseif (event == 'readable') then
        if (not state.endEmitted) and (not state.readableListening) then
            state.readableListening = true
            state.emittedReadable   = false
            state.needReadable      = true

            if not state.reading then
                local _self = self
                process.nextTick(function()
                    _self:read(0)
                end)

            elseif state.length then
                _readableEmitReadable(self, state)
            end
        end
    end

    return res
end

Readable.addListener = Readable.on

-- 调用这个方法会让这个流进入暂停模式
function Readable:pause()
    local state = self._readableState
    if (state.flowing ~= false) then
        state.flowing = false
        self:emit('pause')
    end

    return self
end

--[[
-- 调用这个方法会让这个流进入流模式, 添加 'data' 事件侦听会自动调用这个方法.
-- 如果没有添加 'data' 事件侦听, 手动调用这个方法会导致数据丢失
-- pause() and resume() are remnants of the legacy readable stream API
-- If the user uses them, then switch into old mode.
--]]
function Readable:resume()
    local state = self._readableState
    if (not state.flowing) then
        state.flowing = true

        _readableResume(self, state)
    end

    return self
end

-- Unshift should *always* be something directly out of read()
function Readable:unshift(chunk)
    return _readablePushChunk(self, chunk, true)
end

local exports = { }

exports.Readable      = Readable
exports.ReadableState = ReadableState

return exports
