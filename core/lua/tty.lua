--[[

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

local uv = require('luv')

local exports = {}

-- WriteStream

local WriteStream = nil

function exports.createWriteStream(pipe)
    if (WriteStream) then
        return WriteStream:new(pipe)
    end

    local Writable = require('stream').Writable
    WriteStream = Writable:extend()

    function WriteStream:initialize(handle)
        Writable.initialize(self)
        self.handle = handle
    end

    function WriteStream:_write(data, callback)
        uv.write(self.handle, data, callback)
    end

    return WriteStream:new(pipe)
end

exports.WriteStream = WriteStream

-- ReadStream

local ReadStream = nil

function exports.createReadStream(pipe)
    if (ReadStream) then
        return ReadStream:new(pipe)
    end

    local Readable  = require('stream').Readable
    ReadStream = Readable:extend()

    function ReadStream:initialize(handle)
        Readable.initialize(self, { highWaterMark = 0 })
        self._readableState.reading = false
        self.reading = false
        self.handle  = handle

        self:on('pause', function() self:_onPause() end)
    end

    function ReadStream:_onPause()
        self._readableState.reading = false
        self.reading = false
        uv.read_stop(self.handle)
    end

    function ReadStream:_read(n)
        local _onRead = function (err, data)
            if err then
                return self:emit('error', err)
            end
            self:push(data)
        end

        if not uv.is_active(self.handle) then
            self.reading = true
            uv.read_start(self.handle, _onRead)
        end
    end

    return ReadStream:new(pipe)
end

exports.ReadStream = ReadStream

-- isatty

exports.isatty = function(fd)
    return uv.guess_handle(fd) == 'tty'
end

return exports
