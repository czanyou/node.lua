--[[

Copyright 2014-2015 The Luvit Authors. All Rights Reserved.
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

local fs        = require('fs')
local bind      = require('util').bind

local Writable  = require('stream').Writable
local Readable  = require('stream').Readable

local exports = {}

-------------------------------------------------------------------------------
-- WriteStream

local WriteStream = Writable:extend()
exports.WriteStream = WriteStream

function WriteStream:initialize(path, options)
    Writable.initialize(self)

    self.options    = options or { }
    self.path       = path
    self.fd         = nil
    self.pos        = nil
    self.bytesWritten = 0

    if self.options.fd    then self.fd    = self.options.fd    end
    if self.options.flags then self.flags = self.options.flags else self.flags = 'w' end
    if self.options.mode  then self.mode  = self.options.mode  else self.mode = 438 end
    if self.options.start then self.start = self.options.start end

    self.pos = self.start

    if not self.fd then
        self:open()
    end

    self:on('finish', bind(self.close, self))
end

function WriteStream:open(callback)
    if self.fd then self:destroy() end
    fs.open(self.path, self.flags, nil, function(err, fd)
        if err then
            self:destroy()
            self:emit('error', err)
            if callback then callback(err) end
            return
        end
        self.fd = fd
        self:emit('open', fd)
        if callback then callback() end
    end )
end

function WriteStream:_write(data, callback)
    if not self.fd then
        return self:once('open', function()
            self:_write(data, callback)
        end)
    end

    fs.write(self.fd, nil, data, function(err, bytes)
        if err then
            self:destroy()
            return callback(err)
        end
        self.bytesWritten = self.bytesWritten + bytes
        callback()
    end)
end

function WriteStream:close()
    self:destroy()
end

function WriteStream:destroy()
    if self.fd then
        fs.close(self.fd)
        self.fd = nil
    end
end

-------------------------------------------------------------------------------
-- ReadStream

local CHUNK_SIZE = 65536

local readOptions = {
    flags       = "r",
    mode        = "0644",
    chunkSize   = CHUNK_SIZE,
    fd          = nil,
    reading     = nil,
    length      = nil   -- nil means read to EOF
}

local readMeta = { __index = readOptions }

local ReadStream = Readable:extend()
exports.ReadStream = ReadStream

function ReadStream:initialize(path, options)
    Readable.initialize(self)
    if not options then
        options = readOptions
    else
        setmetatable(options, readMeta)
    end

    self.fd         = options.fd
    self.mode       = options.mode
    self.path       = path
    self.offset     = options.offset
    self.chunkSize  = options.chunkSize
    self.length     = options.length
    self.bytesRead  = 0

    if not self.fd then
        self:open()
    end

    self:on('end', bind(self.close, self))
end

function ReadStream:open(callback)
    if self.fd then self:destroy() end
    fs.open(self.path, self.flags, self.mode, function(err, fd)
        if err then
            self:destroy()
            self:emit('error', err)
            if callback then callback(err) end
            return
        end
        self.fd = fd
        self:emit('open', fd)
        if callback then callback() end
    end )
end

function ReadStream:_read(n)
    if not self.fd then
        return self:once('open', bind(self._read, self, n))
    end

    local toReadSize = self.chunkSize or n
    if self.length then
        -- indicating length was set in option; need to check boundary
        if toReadSize + self.bytesRead > self.length then
            toReadSize = self.length - self.bytesRead
        end
    end

    fs.read(self.fd, toReadSize, self.offset, function(err, bytes)
        if err then return self:destroy(err) end
        if #bytes > 0 then
            self.bytesRead = self.bytesRead + #bytes
            if self.offset then
                self.offset = self.offset + #bytes
            end
            self:push(bytes)
        else
            self:push()
        end
    end)
end

function ReadStream:close()
    self:destroy()
end

function ReadStream:destroy(err)
    if err then self:emit('error', err) end
    if self.fd then
        fs.close(self.fd)
        self.fd = nil
    end
end

function fs.createWriteStream(path, options)
    return WriteStream:new(path, options)
end

function fs.createReadStream(path, options)
    return ReadStream:new(path, options)
end

return exports
