--[[

Copyright 2014 The Luvit Authors. All Rights Reserved.
Copyright 2016-2020 The Node.lua Authors. All Rights Reserved.

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
local timer = require('timer')

local Error  = core.Error

-------------------------------------------------------------------------------
--- WriteRequest

---@class WriteRequest
---@field public chunk string
---@field public callback function
local WriteRequest = core.Object:extend()

function WriteRequest:initialize(chunk, callback)
    self.chunk    = chunk
    self.callback = callback
end

-------------------------------------------------------------------------------
--- WritableState

---@class WritableState
local WritableState = core.Object:extend()

function WritableState:initialize(options)
    options = options or { }

    -- when 'drain' is need emitted
    self.needDrain = false

    -- at the start of calling end()
    self.ending = false

    -- emit prefinish if the only thing we're waiting for is _write cbs
    -- This is relevant for synchronous Transform streams
    self.prefinished = false

    -- not an actual buffer we keep track of, but a measurement
    -- of how much we're waiting to get pushed to some underlying
    -- socket or file.
    -- 队列中缓存的数据的长度
    self.length = 0

    -- a flag to see when we're in the middle of a write.
    -- 如果为 true 则表示已调用 _write 但还没有完成
    self.writing = false

    -- a flag to be able to tell if the onwrite callback is called immediately,
    -- or on a later tick.  We set this to true at first, because any
    -- actions that shouldn't happen until "later" should generally also
    -- not happen before the first write call.
    -- 如果为 true 则表示已调用 _write 但还没有返回
    self.sync = true

    -- a flag to know if we're processing previously buffered items, which
    -- may call the _write() callback in the same tick, so that we don't
    -- end up in an overlapped onwrite situation.
    self.isBufferFlushing = false

    -- the callback that the user supplies to write(chunk, callback)
    --
    self.writeCallback = nil

    -- the amount that is being written when _write is called.
    -- 当前调用 _write 所写的字节长度
    -- self.writelen = 0

    -- chunk buffer
    -- WriteRequest 缓存队列，配合读写指针使用
    self.buffer = {}

    -- chunk buffer write position
    -- 总是指向下一个空的位置，总是大于等于 readPos
    self.writePos = 1

    -- chunk buffer read position
    -- 总是指向队列中第一个有效数据块位置，如果等于 writePos 表示队列为空
    self.readPos = 1

    -- number of pending user-supplied write callbacks
    -- this must be 0 before 'finish' can be emitted
    self.pendingCallbacks = 0

    -- True if the error was already emitted and should not be thrown again
    self.errorEmitted = false
end

function WritableState:_needFinish()
    return   self.ending
        and (self.length == 0)
        and (self.readPos == self.writePos)
        and (not self.writing)
end

-------------------------------------------------------------------------------
--- Writable

--  The Writable stream interface is an abstraction for a destination that you
--  are writing data to.

---@class Writable
local Writable = core.Emitter:extend()

---@param options WritableOptions
function Writable:initialize(options)
    ---@class WritableOptions
    ---@field public highWaterMark number
    ---@field public objectMode boolean
    options = options or {}
    --[[
    -- Writable ctor is applied to Duplexes, though they're not
    -- instanceof Writable, they're instanceof Readable.
    -- if (!(this instanceof Writable) && !(this instanceof Stream.Duplex))
    --  return new Writable(options)
    --]]

    -- when end() has been called, and returned
    -- 这个流已经被终止
    self.writableEnded = false
    self.writable = true

    -- when true all writes will be buffered until .uncork() call
    self.writableCorked = 0

    -- when 'finish' is emitted
    -- 这个流已经完成
    self.writableFinished = false
    self.writableHighWaterMark = nil

    -- 此属性包含准备写入的队列中的字节数（或对象）。 该值提供有关 highWaterMark 状态的内省数据。
    self.writableLength = 0

    -- object stream flag to indicate whether or not this stream
    -- contains buffers or objects.
    self.writableObjectMode = not not options.objectMode

    if core.instanceof(self, require('stream/duplex').Duplex) then
        self.writableObjectMode = self.writableObjectMode or (not not options.writableObjectMode)
    end

    -- the point at which write() starts returning false
    -- Note: 0 is a valid value, means that we always return false if
    -- the entire buffer is not flushed immediately on write()
    local defaultHighWaterMark
    if self.writableObjectMode then
        defaultHighWaterMark = 16
    else
        defaultHighWaterMark = 16 * 1024
    end

    -- 发送队列可以缓存的水位
    self.writableHighWaterMark = options.highWaterMark or defaultHighWaterMark

    self.destroyed = false
    self._writableState = WritableState:new(options)
end

--   Forces buffering of all writes.
--    Buffered data will be flushed either at .uncork() or at .end() call.
function Writable:cork()
    self.writableCorked = self.writableCorked + 1
end

function Writable:destroy(err, callback)
    --
    self:_destroy(err, callback)
end

--    Call this method when no more data will be written to the stream. If
--    supplied, the callback is attached as a listener on the finish event.
--
--    @param chunk String | Buffer Optional data to write
--    @param callback Function Optional callback for when the stream is finished
function Writable:finish(chunk, callback)
    local state = self._writableState

    -- 结束指定的 stream, 但直到所有队列中的缓存数据都发送完才触发 'finish' 事件
    -- @param callback 在这个流完全结束时调用
    local function _endWritable(stream, callback)
        state.ending = true -- start ending

        self:_maybeFinish()

        if callback then
            if stream.writableFinished then
                timer.setImmediate(callback)
            else
                stream:once('finish', callback)
            end
        end

        stream.writableEnded = true  -- end ending
        stream:emit('end')
    end

    -- function(callback)
    if type(chunk) == 'function' then
        callback = chunk
        chunk = nil
    end

    if chunk ~= nil then
        self:write(chunk)
    end

    -- end() fully uncorks
    if self.writableCorked ~= 0 then
        self.writableCorked = 1
        self:uncork()
    end

    -- ignore unnecessary end() calls.
    if (not state.ending) and (not self.writableFinished) then
        _endWritable(self, callback)
    end
end

-- Otherwise people can pipe Writable streams, which is just wrong.
function Writable:pipe()
    self:emit('error', Error:new('Cannot pipe. Not readable.'))
end

-- Flush all data, buffered since .cork() call.
function Writable:uncork()
    local state = self._writableState

    if self.writableCorked ~= 0 then
        self.writableCorked = self.writableCorked - 1

        if not state.writing and not self.writableFinished then
            self:_flushBuffer()
        end
    end
end

-- 返回 true, 表示还可以继续写数据, 返回 false 表示缓存队列已满,
-- 最好等待 'drain' 事件再写.
---@param chunk string
---@param callback fun(err:string)
function Writable:write(chunk, callback)
    local state = self._writableState
    local ret = false

    if type(callback) ~= 'function' then
        callback = function() end
    end

    if self.writableEnded then
        local err = Error:new('write after end')
        self:emit('error', err)
        setImmediate(function() callback(err) end)

    elseif (chunk ~= nil) and (type(chunk) ~= 'string') and not self.writableObjectMode then
        -- If we get something that is not a buffer, string, null, or undefined,
        -- and we're not in objectMode, then that's an error.
        -- Otherwise stream chunks are all considered to be of length=1, and the
        -- watermarks determine how many objects to keep in the buffer, rather than
        -- how many bytes or characters.
        local err = Error:new('Invalid non-string/buffer chunk')
        self:emit('error', err)
        setImmediate(function() callback(err) end)

    else
        state.pendingCallbacks = state.pendingCallbacks + 1
        ret = self:_writeOrBuffer(chunk, callback)
    end

    return ret
end

Writable._destroy = function(err, callback)
    -- TODO:
end

-- if there's something in the buffer waiting, then process it
function Writable:_flushBuffer()
    local state = self._writableState
    if (state.isBufferFlushing) then
        return

    elseif (self.writableCorked > 0) then
        return
    end

    local size = state.writePos - state.readPos
    if (size <= 0) then
        return
    end

    state.isBufferFlushing = true

    size = state.writePos - state.readPos
    if self._writev and size > 1 then
        -- Fast case, write everything using _writev()

        local buffer = {}
        for c = state.readPos, state.writePos - 1 do
            table.insert(buffer, state.buffer[c])
            state.buffer[c] = nil
        end

        state.readPos  = 1
        state.writePos = 1

        -- count the one we are adding, as well.
        -- TODO(isaacs) clean this up
        state.pendingCallbacks = state.pendingCallbacks + 1
        self:_onWrite(true, state.length, buffer, function(err)
            for i = 1, #(buffer) do
                state.pendingCallbacks = state.pendingCallbacks - 1
                buffer[i].callback(err)
            end
        end)

    else
        -- Slow case, write chunks one-by-one
        for c = state.readPos, state.writePos - 1 do
            local entry     = state.buffer[c]
            state.buffer[c] = nil
            state.readPos = state.readPos + 1

            local chunk     = entry.chunk
            local callback  = entry.callback

            local chunkLength = 1
            if not self.writableObjectMode then
                chunkLength = string.len(chunk)
            end

            self:_onWrite(false, chunkLength, chunk, callback)

            -- if we didn't call the onwrite immediately, then
            -- it means that we need to wait until it does.
            -- also, that means that the chunk and callback are currently
            -- being processed, so move the buffer counter past them.
            if state.writing then
                break
            end
        end

        if (state.readPos == state.writePos) then
            state.writePos = 1
            state.readPos  = 1
        end
    end

    state.isBufferFlushing = false
end

function Writable:_maybeFinish()
    local state = self._writableState
    local needFinish = state:_needFinish() and (not self.writableFinished)
    if needFinish then
        -- 这个流已结束但队列中还有缓存的数据未发完
        if not state.prefinished then
            state.prefinished = true
            self:emit('prefinish')
        end

        -- 当所有队列中的数据包都发送成功后，完成这个流
        if state.pendingCallbacks == 0 then
            self.writableFinished = true
            self:emit('finish')
        end
    end

    return needFinish
end

function Writable:_onWrite(writev, len, chunk, callback)
    local state = self._writableState

    self.writableLength = len
    -- test only
    state.writeCallback = callback
    state.writing = true
    state.sync = true

    -- the callback that's passed to _write(chunk, callback)
    --
    local onWrite = function(err)
        self:_onWriteCompleted(err)
    end

    if writev then
        self:_writev(chunk, onWrite)
    else
        self:_write(chunk, onWrite)
    end

    state.sync = false
end

function Writable:_onWriteCompleted(err)
    local function _onWriteCompletedNextTick(stream, needFinish, callback)
        local state = stream._writableState
        state.pendingCallbacks = state.pendingCallbacks - 1

        if not needFinish then
            -- 当缓存区的数据都发送完成后，发出一个 drain 事件
            --[[
            -- Must force callback to be called on nextTick, so that we don't
            -- emit 'drain' before the write() consumer gets the 'false' return
            -- value, and has a chance to attach a 'drain' listener.
            --]]
            if (state.length == 0) and state.needDrain then
                state.needDrain = false
                stream:emit('drain')
            end
        end

        if (callback) then callback() end
        stream:_maybeFinish()
    end

    local state = self._writableState
    local sync = state.sync
    local callback = state.writeCallback

    state.length = state.length - self.writableLength
    state.writing = false
    state.writeCallback  = nil

    self.writableLength = 0

    if err then
        if sync then
            setImmediate(function()
                state.pendingCallbacks = state.pendingCallbacks - 1
                if (callback) then callback(err) end
            end)
        else
            state.pendingCallbacks = state.pendingCallbacks - 1
            if (callback) then callback(err) end
        end

        state.errorEmitted = true
        self:emit('error', err)
        return
    end

    -- Check if we're actually ready to finish, but don't emit yet
    local needFinish = state:_needFinish() and (not self.writableFinished)
    if (not needFinish) then
        self:_flushBuffer()
    end

    if sync then
        setImmediate(function()
            _onWriteCompletedNextTick(self, needFinish, callback)
        end)
    else
        _onWriteCompletedNextTick(self, needFinish, callback)
    end
end

function Writable:_write(chunk, callback)
    callback(Error:new('not implemented'))
end

-- if we're already writing something, then just put this
-- in the queue, and wait our turn.  Otherwise, call _write
-- If we return false, then we need a drain event, so set that flag.
function Writable:_writeOrBuffer(chunk, callback)
    local state = self._writableState

    local chunkLength = 1
    if not self.writableObjectMode then
        chunkLength = string.len(chunk)
    end

    state.length = state.length + chunkLength

    local ret = (state.length < self.writableHighWaterMark)
    if not ret then
        -- we must ensure that previous needDrain will not be reset to false.
        -- 当水位过高时，不应该继续发送数据。等缓存队列中的数据被清空时再
        -- 发出一个 drain 事件通知应用程序又可以继续发送数据了
        state.needDrain = true
    end

    if state.writing or (self.writableCorked ~= 0) then
        -- 已经在发送数据中，将新的数据放到缓存队列先
        state.buffer[state.writePos] = WriteRequest:new(chunk, callback)
        state.writePos = state.writePos + 1

    else
        self:_onWrite(false, chunkLength, chunk, callback)
    end

    return ret
end

Writable._writev = nil
Writable._end = Writable.finish

-------------------------------------------------------------------------------
-- exports

local exports = {}

exports.WritableState = WritableState
exports.Writable = Writable

return exports
