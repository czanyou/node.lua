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
local timer = require('timer')

local Error  = core.Error

local _writeWriteOrBuffer, 
    _writeWriteAfterEnd, 
    _stateNeedFinish, 
    _writeMaybeFinish, 
    _writeOnWriteCompleted, 
    _writeOnEmitError, 
    _writeOnEmitDrain, 
    _writeOnWriteCompletedNextTick, 
    _writeEndWritable, 
    _writeFlushBuffer, 
    _writeIsValidChunk


-------------------------------------------------------------------------------
--- WriteRequest

local WriteRequest = core.Object:extend()

function WriteRequest:initialize(chunk, callback)
    self.chunk    = chunk
    self.callback = callback
end
    
-------------------------------------------------------------------------------

function _stateNeedFinish(state)
    return   state.ending 
        and (state.length == 0) 
        and (state.readPos == state.writePos)
        and (not state.finished)
        and (not state.writing)
end

-- 结束指定的 stream, 但直到所有队列中的缓存数据都发送完才触发 'finish' 事件
-- @param callback 在这个流完全结束时调用
function _writeEndWritable(stream, callback)
    local state = stream._writableState

    state.ending = true -- start ending

    _writeMaybeFinish(stream)

    if callback then
        if state.finished then
            timer.setImmediate(callback)
        else
            stream:once('finish', callback)
        end
    end

    state.ended = true  -- end ending
    stream:emit('end')
end

--[[
-- if there's something in the buffer waiting, then process it
--]]
function _writeFlushBuffer(stream, state)
    if (state.isBufferFlushing) then
        return

    elseif (state.corked > 0) then
        return
    end

    local size = state.writePos - state.readPos
    if (size <= 0) then
        return
    end

    state.isBufferFlushing = true

    local size = state.writePos - state.readPos

    if stream._writev and size > 1 then
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
        _writeOnWrite(stream, true, state.length, buffer, function(err)
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
            if not state.objectMode then
                chunkLength = string.len(chunk)
            end

            _writeOnWrite(stream, false, chunkLength, chunk, callback)

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

--[[
// If we get something that is not a buffer, string, null, or undefined,
// and we're not in objectMode, then that's an error.
// Otherwise stream chunks are all considered to be of length=1, and the
// watermarks determine how many objects to keep in the buffer, rather than
// how many bytes or characters.
--]]
function _writeIsValidChunk(stream, state, chunk, callback)
    local valid = true
    if (chunk ~= nil) and (type(chunk) ~= 'string') and not state.objectMode then
        local err = Error:new('Invalid non-string/buffer chunk')
        stream:emit('error', err)
        timer.setImmediate(function()
            callback(err)
        end )
        valid = false
    end
    return valid
end

function _writeOnWrite(stream, writev, len, chunk, callback)
    local state = stream._writableState

    state.writelen      = len
    state.writeCallback = callback
    state.writing       = true
    state.sync          = true

    -- the callback that's passed to _write(chunk, callback)
    -- 
    local onwrite = function(err)
        _writeOnWriteCompleted(stream, err)
    end

    if writev then
        stream:_writev(chunk, onwrite)
    else
        stream:_write (chunk, onwrite)
    end

    state.sync     = false
end

function _writeOnWriteCompleted(stream, err)
    local state    = stream._writableState

    local sync     = state.sync
    local callback = state.writeCallback

    state.length   = state.length - state.writelen
    state.writelen = 0
    state.writing  = false
    state.writeCallback  = nil    

    if err then
        _writeOnEmitError(stream, err, callback)
        return
    end

    -- Check if we're actually ready to finish, but don't emit yet
    local needFinish = _stateNeedFinish(state)
    if (not needFinish) then
        _writeFlushBuffer(stream, state)
    end

    if sync then
        setImmediate(function()
            _writeOnWriteCompletedNextTick(stream, needFinish, callback)
        end )
    else
        _writeOnWriteCompletedNextTick(stream, needFinish, callback)
    end
end

function _writeOnWriteCompletedNextTick(stream, needFinish, callback)
    local state = stream._writableState
    state.pendingCallbacks = state.pendingCallbacks - 1

    if not needFinish then
        _writeOnEmitDrain(stream)
    end

    callback()

    _writeMaybeFinish(stream)
end

--[[
-- Must force callback to be called on nextTick, so that we don't
-- emit 'drain' before the write() consumer gets the 'false' return
-- value, and has a chance to attach a 'drain' listener.
--]]
function _writeOnEmitDrain(stream)
    local state = stream._writableState
    -- 当缓存区的数据都发送完成后，发出一个 drain 事件

    if (state.length == 0) and state.needDrain then
        state.needDrain = false
        stream:emit('drain')
    end
end

function _writeOnEmitError(stream, error, callback)
    local state = stream._writableState

    if state.sync then
        setImmediate(function()
            state.pendingCallbacks = state.pendingCallbacks - 1
            callback(error)
        end)
    else
        state.pendingCallbacks = state.pendingCallbacks - 1
        callback(error)
    end

    state.errorEmitted = true
    stream:emit('error', error)
end

function _writeMaybeFinish(stream)
    local state = stream._writableState

    local needFinish = _stateNeedFinish(state)
    if needFinish then
        -- 这个流已结束但队列中还有缓存的数据未发完
        if not state.prefinished then
            state.prefinished = true
            stream:emit('prefinish')
        end

        -- 当所有队列中的数据包都发送成功后，完成这个流
        if state.pendingCallbacks == 0 then
            state.finished = true
            stream:emit('finish')
        end
    end

    return needFinish
end

function _writeWriteAfterEnd(stream, callback)
    local err = Error:new('write after end')
    stream:emit('error', err)
    timer.setImmediate( function()
        callback(err)
    end )
end

--[[
-- if we're already writing something, then just put this
-- in the queue, and wait our turn.  Otherwise, call _write
-- If we return false, then we need a drain event, so set that flag.
--]]
function _writeWriteOrBuffer(stream, chunk, callback)
    local state = stream._writableState

    local chunkLength = 1
    if not state.objectMode then
        chunkLength = string.len(chunk)
    end

    state.length = state.length + chunkLength

    local ret = (state.length < state.highWaterMark)
    if not ret then
        -- we must ensure that previous needDrain will not be reset to false.
        -- 当水位过高时，不应该继续发送数据。等缓存队列中的数据被清空时再
        -- 发出一个 drain 事件通知应用程序又可以继续发送数据了
        state.needDrain = true
    end

    if state.writing or (state.corked ~= 0) then
        -- 已经在发送数据中，将新的数据放到缓存队列先
        state.buffer[state.writePos] = WriteRequest:new(chunk, callback)
        state.writePos = state.writePos + 1

    else
        _writeOnWrite(stream, false, chunkLength, chunk, callback)
    end

    return ret
end

-------------------------------------------------------------------------------
--- WritableState

local WritableState = core.Object:extend()

function WritableState:initialize(options, stream)
    options = options or { }

    --[[
    -- object stream flag to indicate whether or not this stream
    -- contains buffers or objects.
    --]]
    self.objectMode = not not options.objectMode

    if core.instanceof(stream, require('stream/duplex').Duplex) then
        self.objectMode = self.objectMode or not not options.writableObjectMode
    end

    --[[
    -- the point at which write() starts returning false
    -- Note: 0 is a valid value, means that we always return false if
    -- the entire buffer is not flushed immediately on write()
    --]]
    local hwm = options.highWaterMark
    local defaultHwm
    if self.objectMode then
        defaultHwm = 16
    else
        defaultHwm = 16 * 1024
    end

    -- 发送队列可以缓存的水位
    self.highWaterMark = hwm or defaultHwm

    -- when 'drain' is need emitted
    self.needDrain = false

    -- at the start of calling end()
    self.ending = false

    -- when end() has been called, and returned
    -- 这个流已经被终止
    self.ended = false

    -- when 'finish' is emitted
    -- 这个流已经完成
    self.finished = false

    --[[
    -- emit prefinish if the only thing we're waiting for is _write cbs
    -- This is relevant for synchronous Transform streams
    --]]
    self.prefinished = false

    --[[
    -- not an actual buffer we keep track of, but a measurement
    -- of how much we're waiting to get pushed to some underlying
    -- socket or file.
    --]]
    -- 队列中缓存的数据的长度
    self.length = 0

    -- a flag to see when we're in the middle of a write.
    -- 如果为 true 则表示已调用 _write 但还没有完成
    self.writing = false

    -- when true all writes will be buffered until .uncork() call
    self.corked = 0

    --[[
    -- a flag to be able to tell if the onwrite callback is called immediately,
    -- or on a later tick.  We set this to true at first, because any
    -- actions that shouldn't happen until "later" should generally also
    -- not happen before the first write call.
    --]]
    -- 如果为 true 则表示已调用 _write 但还没有返回
    self.sync = true

    --[[
    -- a flag to know if we're processing previously buffered items, which
    -- may call the _write() callback in the same tick, so that we don't
    -- end up in an overlapped onwrite situation.
    --]]
    self.isBufferFlushing = false

    -- the callback that the user supplies to write(chunk, callback)
    -- 
    self.writeCallback = nil

    -- the amount that is being written when _write is called.
    -- 当前调用 _write 所写的字节长度
    self.writelen = 0

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

-------------------------------------------------------------------------------
--- Writable

--  The Writable stream interface is an abstraction for a destination that you 
--  are writing data to.

local Writable = core.Emitter:extend()

function Writable:initialize(options)
    --[[
    -- Writable ctor is applied to Duplexes, though they're not
    -- instanceof Writable, they're instanceof Readable.
    -- if (!(this instanceof Writable) && !(this instanceof Stream.Duplex))
    --  return new Writable(options)
    --]]

    self._writableState = WritableState:new(options, self)
end

--[[
-- Otherwise people can pipe Writable streams, which is just wrong.
--]]
function Writable:pipe()
    self:emit('error', Error:new('Cannot pipe. Not readable.'))
end

-- 返回 true, 表示还可以继续写数据, 返回 false 表示缓存队列已满, 
-- 最好等待 'drain' 事件再写.
function Writable:write(chunk, callback)
    local state = self._writableState
    local ret = false

    if type(callback) ~= 'function' then
        callback = function() end
    end

    if state.ended then
        _writeWriteAfterEnd(self, callback)

    elseif _writeIsValidChunk(self, state, chunk, callback) then
        state.pendingCallbacks = state.pendingCallbacks + 1
        ret = _writeWriteOrBuffer(self, chunk, callback)
    end

    return ret
end

--[[
--   Forces buffering of all writes.
--    Buffered data will be flushed either at .uncork() or at .end() call.
--]]
function Writable:cork()
    local state = self._writableState

    state.corked = state.corked + 1
end

--[[
--    Call this method when no more data will be written to the stream. If 
--    supplied, the callback is attached as a listener on the finish event.
--
--    @param chunk String | Buffer Optional data to write
--    @param callback Function Optional callback for when the stream is finished
--]]
function Writable:close(chunk, callback)
    local state = self._writableState

    -- function(callback)
    if type(chunk) == 'function' then
        callback = chunk
        chunk = nil
    end

    if chunk ~= nil then
        self:write(chunk)
    end

    -- end() fully uncorks
    if state.corked ~= 0 then
        state.corked = 1
        self:uncork()
    end

    -- ignore unnecessary end() calls.
    if (not state.ending) and (not state.finished) then
        _writeEndWritable(self, callback)
    end
end

--[[
--    Flush all data, buffered since .cork() call.
--]]
function Writable:uncork()
    local state = self._writableState

    if state.corked ~= 0 then
        state.corked = state.corked - 1

        if not state.writing and not state.finished then
            _writeFlushBuffer(self, state)
        end
    end
end

function Writable:_write(chunk, callback)
    callback(Error:new('not implemented'))
end

Writable._writev = nil
Writable._end    = Writable.close
Writable.finish  = Writable.close

-------------------------------------------------------------------------------
-- exports

local exports = {}

exports.WriteRequest  = WriteRequest
exports.WritableState = WritableState
exports.Writable      = Writable

return exports
