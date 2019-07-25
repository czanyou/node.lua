--[[

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
local rtspMessage = require('rtsp/message')

local RtspMessage = rtspMessage.RtspMessage
local STATUS_CODES = rtspMessage.STATUS_CODES

local meta 		= { }
local exports 	= { meta = meta }

-------------------------------------------------------------------------------
-- RtspCodec

local RtspCodec = core.Emitter:extend()
exports.RtspCodec = RtspCodec

function RtspCodec:initialize()
    self.buffer = ''
    self.mode   = 0
    
end

function RtspCodec:decode(data)
    local message = nil
    local hasMore = true

    while (hasMore) do
        message, hasMore = self:decodeNext(data)
        if (message == nil) then
            -- break

        elseif (type(message) == 'string') then
            self:emit('packet', message)

        elseif (message.statusCode) then
            self:emit('response', message)

        else
            self:emit('request', message)
        end
        
        data = nil
    end
end

function RtspCodec:decodeNext(chunk)
    if (chunk) then
        self.buffer = self.buffer .. chunk
    end

    if (#self.buffer <= 0) then 
        return 
    end

    local buffer  = self.buffer
    local hasMore = false

    -- start 4 bytes
    -- 
    if (string.byte(buffer, 1) == 0x24) then
        if (#buffer < 4) then 
            return
        end

        local code, channel, length = string.unpack('>BBI2', buffer)
        if #buffer < length + 4 then 
            return 
        end

        local data = buffer:sub(1, length + 4)
        self.buffer = buffer:sub(length + 4 + 1);
        --print('data', #data, #extra)

        hasMore = true
        return data, hasMore
    end

    -- parse message content
    if (self.mode == 1) then
        if (#buffer < self.contentLength) then
            return nil
        end

        local message = self.message;
        message.content = buffer:sub(1, self.contentLength)

        self.buffer     = buffer:sub(self.contentLength + 1)
        self.mode       = 0
        self.message    = nil
        self.contentLength = 0

        hasMore = true
        return message, hasMore
    end

    -- Find message header end
    local _, length = buffer:find("\r?\n\r?\n", 1)
    -- First make sure we have all the head before continuing
    if not length then
        if #buffer < 8 * 1024 then return end
        -- But protect against evil clients by refusing heads over 8K long.
        -- error("entity too large")

        return nil, nil, "entity too large"
    end

    -- Parse the status/request line
    local head = { }
    local _, offset
    local version

    _, offset, version, head.statusCode, head.statusMessage =
        buffer:find("^RTSP/(%d%.%d) (%d+) ([^\r\n]+)\r?\n")

    if offset then
        head.statusCode = tonumber(head.statusCode)

    else
        _, offset, head.method, head.path, version =
            buffer:find("^(%u+) ([^ ]+) RTSP/(%d%.%d)\r?\n")
        if not offset then
            _, offset, head.method, head.path, version =
            buffer:find("^(%u+) ([^ ]+) HTTP/(%d%.%d)\r?\n")

            if not offset then
                -- error("expected RTSP data")
                return nil, nil, 'expected RTSP data'
            end
        end
    end

    version = tonumber(version)
    head.version = version

    -- We need to inspect some headers to know how to parse the body.
    local contentLength = 0

    local message = RtspMessage:new()
    message.method          = head.method;
    message.path            = head.path;
    message.version         = head.version;
    message.statusCode      = head.statusCode;
    message.statusMessage   = head.statusMessage;  

    -- Parse the header lines
    while true do
        local key, value
        _, offset, key, value = buffer:find("^([^:\r\n]+): *([^\r\n]+)\r?\n", offset + 1)
        if not offset then break end
        local lowerKey = key:lower()

        -- Inspect a few headers and remember the values
        if lowerKey == "content-length" then
            contentLength = tonumber(value)
        end

        --head[#head + 1] = { key, value }

        message.headers[key] = value;
    end

    self.buffer = buffer:sub(length + 1)
    hasMore = true

    if contentLength > 0 then
        self.mode = 1
        self.contentLength = contentLength;
        self.message = message
        return nil, hasMore

    else
        return message, hasMore
    end
end

-- @param message {RtspMessage}
function RtspCodec:encode(message)
    local head

    -- start line
    local version = message.version or 1.0
    if message.method then
        -- Request Start Line
        local path = message.path
        assert(path and #path > 0, "expected non-empty path")
        head = { message.method .. ' ' .. path .. ' RTSP/' .. version .. '\r\n' }
   
    else
        -- Response Start Line
        local scheme = message.scheme or 'RTSP'
        local code   = message.statusCode
        local reason = message.statusMessage or STATUS_CODES[message.statusCode] or 'OK'
        head = { scheme .. '/' .. version .. ' ' .. code .. ' ' .. reason .. '\r\n' }
    end

    if (message.content) then
        message:setHeader('Content-Length', #message.content)
    end

    -- headers
    for i = 1, #message.headers do
        -- console.log(i, message.headers[i])

        local key, value = table.unpack(message.headers[i])
        local lowerKey = key:lower()
        value = string.gsub(tostring(value), "[\r\n]+", " ")
        head[#head + 1] = key .. ': ' .. tostring(value) .. '\r\n'
    end

    -- headers end
    head[#head + 1] = '\r\n'

    -- message content
    if (message.content) then
        head[#head + 1] = message.content
    end

    return table.concat(head)        
end

-------------------------------------------------------------------------------
-- exports

function exports.newCodec()
    return RtspCodec:new()
end

function exports.parseHeaderValue(line, sep, eq)
    eq  = eq  or '='
    sep = sep or ';'

    local tokens = line:split(sep)
    local data   = {}
    local value  = tokens[1]

    for i = 2, #tokens do
        local token = tokens[i]
        local ret = token:find(eq)
        if ret then
            data[token:sub(1, ret - 1)] = token:sub(ret + 1)
        else
            data[token] = ''
        end
    end

    return value, data
end

return exports

