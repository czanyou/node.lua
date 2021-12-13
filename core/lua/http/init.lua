--[[

Copyright 2015 The Luvit Authors. All Rights Reserved.
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

local meta = {
    description = "Node-style http client and server module for lnode"
}

local exports = { meta = meta }

local net   = require('net')
local url   = require('url')
local codec = require('http/codec')
local tls   = require('tls')

local Writable = require('stream').Writable

exports.STATUS_CODES = codec.STATUS_CODES

-- Provide a nice case insensitive interface to headers.
-- Pulled from https://github.com/creationix/weblit/blob/master/libs/weblit-app.lua
local headerMeta = {
    __index = function(list, name)
        if type(name) ~= "string" then
            return rawget(list, name)
        end
        name = name:lower()
        for i = 1, #list do
            local key, value = table.unpack(list[i])
            if key:lower() == name then return value end
        end
    end,
    __newindex = function(list, name, value)
        -- non-string keys go through as-is.
        if type(name) ~= "string" then
            return rawset(list, name, value)
        end
        -- First remove any existing pairs with matching key
        local lowerName = name:lower()
        for i = #list, 1, -1 do
            if list[i][1]:lower() == lowerName then
                table.remove(list, i)
            end
        end
        -- If value is nil, we're done
        if value == nil then return end
        -- Otherwise, set the key(s)
        if (type(value) == "table") then
            -- We accept a table of strings
            for i = 1, #value do
                rawset(list, #list + 1, { name, tostring(value[i]) })
            end
        else
            -- Or a single value interperted as string
            rawset(list, #list + 1, { name, tostring(value) })
        end
    end,
}
exports.headerMeta = headerMeta

-------------------------------------------------------------------------------
-- IncomingMessage

---@class IncomingMessage
local IncomingMessage = net.Socket:extend()
exports.IncomingMessage = IncomingMessage

function IncomingMessage:initialize(head, socket)
    net.Socket.initialize(self)
    self.httpVersion = tostring(head.version)
    local headers = setmetatable( { }, headerMeta)
    for i = 1, #head do
        headers[i] = head[i]
    end
    self.headers = headers
    if head.method then
        -- server specific
        self.method = head.method
        self.url = head.path
    else
        -- client specific
        self.statusCode = head.code
        self.statusMessage = head.reason
    end
    self.socket = socket
end

function IncomingMessage:_read()
    self.socket:resume()
end

-------------------------------------------------------------------------------
-- ServerResponse

---@class ServerResponse
local ServerResponse = Writable:extend()
exports.ServerResponse = ServerResponse

-- Override this in the instance to not send the date
ServerResponse.sendDate = true

---@param socket Socket
function ServerResponse:initialize(socket)
    Writable.initialize(self)

    self.encoder        = codec.encoder()
    self.headers        = setmetatable( { }, headerMeta)
    self.headersSent    = false
    self.sendDate       = true
    self.socket         = socket
    self.statusCode     = 200
    self.statusMessage  = nil
    self.writableEnded  = false
    self.writableFinished = false

    local callbacks = {
        onSocketClose = function(...)
            self:emit('close', ...)
        end,
        onSocketDrain = function(...)
            self:emit('drain', ...)
        end,
        onSocketEnd = function(...)
            self:emit('end', ...)
        end
    }
    self._callbacks = callbacks

    -- console.log('close.count', self.socket:listenerCount('close'))
    self.socket:on('close', callbacks.onSocketClose)
    self.socket:on('drain', callbacks.onSocketDrain)
    self.socket:on('end', callbacks.onSocketEnd)
end

function ServerResponse:setHeader(name, value)
    assert(not self.headersSent, "headers already sent")
    self.headers[name] = value
end

function ServerResponse:getHeader(name)
    assert(not self.headersSent, "headers already sent")
    return self.headers[name]
end

function ServerResponse:removeHeader(name)
    assert(not self.headersSent, "headers already sent")
    self.headers[name] = nil
end

function ServerResponse:flushHeaders()
    if self.headersSent then
        return
    end

    self.headersSent = true

    local headers = self.headers
    local statusCode = self.statusCode

    local head = { }
    local sent_date, sent_connection, sent_transfer_encoding, sent_content_length
    for i = 1, #headers do
        local key, value = table.unpack(headers[i])
        local klower = key:lower()
        head[#head + 1] = { tostring(key), tostring(value) }
        if klower == "connection" then
            self.keepAlive = value:lower() ~= "close"
            sent_connection = true

        elseif klower == "transfer-encoding" then
            sent_transfer_encoding = true

        elseif klower == "content-length" then
            sent_content_length = true

        elseif klower == "date" then
            sent_date = true
        end

        head[i] = headers[i]
    end

    if not sent_date and self.sendDate then
        head[#head + 1] = { "Date", os.date("!%a, %d %b %Y %H:%M:%S GMT") }
    end

    if self.hasBody and not sent_transfer_encoding and not sent_content_length then
        sent_transfer_encoding = true
        head[#head + 1] = { "Transfer-Encoding", "chunked" }
    end

    if not sent_connection then
        if self.keepAlive then
            if self.hasBody then
                if sent_transfer_encoding or sent_content_length then
                    head[#head + 1] = { "Connection", "keep-alive" }
                else
                    -- body has no length so close to indicate end
                    self.keepAlive = false
                    head[#head + 1] = { "Connection", "close" }
                end

            elseif statusCode >= 300 then
                self.keepAlive = false
                head[#head + 1] = { "Connection", "close" }

            else
                head[#head + 1] = { "Connection", "keep-alive" }
            end

        else
            self.keepAlive = false
            head[#head + 1] = { "Connection", "close" }
        end
    end

    head.code = statusCode
    local headerData = self.encoder(head)
    self.socket:write(headerData)
end

-- 此方法向服务器发出信号，表明已发送所有响应头和主体，该服务器应该视为此消息已完成。 
-- 必须在每个响应上调用此 response:finish() 方法。
function ServerResponse:finish(chunk)
    if (self.writableEnded) then
        return
    end

    if chunk and #chunk > 0 then
        self.hasBody = true
    end

    self:flushHeaders()
    local last = ""
    if chunk then
        last = last .. self.encoder(chunk)
    end

    last = last .. (self.encoder("") or "")

    self.writableEnded = true

    -- end
    local _maybeEnd = function ()
        -- console.log('_maybeEnd: finish')
        -- self:emit('finish')

        -- close socket
        if not self.keepAlive then
            self.socket:finish()
        end

        -- clean all listeners
        local callbacks = self._callbacks
        self._callbacks = nil
        if (callbacks) then
            self.socket:removeListener('close', callbacks.onSocketClose)
            self.socket:removeListener('drain', callbacks.onSocketDrain)
            self.socket:removeListener('end', callbacks.onSocketEnd)
        end

        self.encoder = nil
        self.headers = nil

        -- end this writable
        Writable.finish(self)
    end

    if #last > 0 then
        self.socket:write(last, function()
            _maybeEnd()
        end)
    else
        _maybeEnd()
    end
end

ServerResponse._end = ServerResponse.finish

function ServerResponse:write(chunk, callback)
    if chunk and #chunk > 0 then
        self.hasBody = true
    end

    self:flushHeaders()
    return self.socket:write(self.encoder(chunk), callback)
end

function ServerResponse:writeHead(newStatusCode, newHeaders)
    if (self.headersSent) then
        print('writeHead', "headers already sent")
        return
    end

    self.statusCode = newStatusCode

    if (not self.headers) then
        self.headers = setmetatable( { }, headerMeta)
    end

    for name, value in pairs(newHeaders) do
        self.headers[name] = value
    end
end

-------------------------------------------------------------------------------
-- handleConnection

---@param socket Socket
---@param onRequest function
function exports.handleConnection(socket, onRequest)

    local decoder = nil
    local request, response

    local _onSocketData = nil

    local _onRequestFlush = function ()
        request:push()
        request = nil
    end

    -- Socket timeout
    local _onSocketTimeout = function ()
        socket:finish()
    end

    -- Socket is end
    local _onSocketEnd = function ()
        process:removeListener('exit', _onSocketTimeout)
        -- Just in case the stream ended and we still had an open request,
        -- end it.
        if request then
            _onRequestFlush()
        end
    end

    local _onRequestHeadersEnd = function(event)
        -- If there was an old request that never closed, end it.
        if request then
            _onRequestFlush()
        end

        -- Create a new request object
        request = IncomingMessage:new(event, socket)

        -- Create a new response object
        response = ServerResponse:new(socket)
        response.keepAlive = event.keepAlive

        -- If the request upgrades the protocol then detatch the listeners so http codec is no longer used
        if request.headers.upgrade then
            request.is_upgraded = true
            socket:setTimeout(0)
            socket:removeListener("timeout", _onSocketTimeout)
            socket:removeListener("data",    _onSocketData)
            socket:removeListener("end",     _onSocketEnd)

            process:removeListener('exit', _onSocketTimeout)
            if decoder and #decoder.buffer > 0 then
                socket:pause()
                socket:unshift(decoder.buffer)
            end

            onRequest(request, response)
            return true -- break

        else
            -- Call the user callback to handle the request
            onRequest(request, response)
            return false
        end
    end

    local _onContentData = function(chunk)
        if #chunk == 0 then
            -- Empty string in http-decoder means end of body
            -- End the request stream and remove the request reference.
            _onRequestFlush()
            return
        end

        -- Forward non-empty body chunks to the request stream.
        if not request:push(chunk) then
            -- If it's queue is full, pause the source stream
            -- This will be resumed by IncomingMessage:_read
            socket:pause()
        end
    end

    -- --------------------------------------------------------
    -- decoder

    -- [[
    decoder = codec.createDecoder({}, function(event, error)
        -- console.log('event', event, error)

        if (error) then
            -- error
            socket:emit('error', error)

        elseif type(event) == "table" then
            -- headers
            return _onRequestHeadersEnd(event)

        elseif type(event) == "string" then
            -- content
            if (request) then
                return _onContentData(event)
            end
        end
    end)

    _onSocketData = function (chunk)
        -- console.log('_onSocketData', chunk)
        decoder.decode(chunk)
    end

    --]]

    -- --------------------------------------------------------
    -- socket

    socket:setTimeout(120000 ) -- set socket timeout
    socket:once('timeout', _onSocketTimeout)
    socket:on('data', _onSocketData)
    socket:on('end',  _onSocketEnd)

    -- test only
    -- process:once('exit', _onSocketTimeout)
end

---@param onRequest function
---@return Server
function exports.createServer(onRequest)
    return net.createServer(function(connection)
        return exports.handleConnection(connection, onRequest)
    end)
end

-------------------------------------------------------------------------------
-- ClientRequest

---@class ClientRequest
local ClientRequest = Writable:extend()
exports.ClientRequest = ClientRequest

function exports.ClientRequest.getDefaultUserAgent()
    if exports.ClientRequest._defaultUserAgent == nil then
        exports.ClientRequest._defaultUserAgent = 'lnode/http/' .. process.version
    end

    return exports.ClientRequest._defaultUserAgent
end

function ClientRequest:initialize(options, callback)
    Writable.initialize(self)
    self:cork()

    -- headers
    local headers = setmetatable( { }, headerMeta)
    if options.headers then
        for k, v in pairs(options.headers) do
            headers[k] = v
        end
    end

    -- host
    local host_found, connection_found, user_agent
    for i = 1, #headers do
        self[#self + 1] = headers[i]
        local key, value = table.unpack(headers[i])
        local klower = key:lower()
        if klower == 'host' then host_found = value end
        if klower == 'connection' then connection_found = value end
        if klower == 'user-agent' then user_agent = value end
    end

    -- user agent
    if not user_agent then
        user_agent = self.getDefaultUserAgent()

        if user_agent ~= '' then
            table.insert(self, 1, { 'User-Agent', user_agent })
        end
    end

    -- host
    if not host_found and options.host then
        table.insert(self, 1, { 'Host', options.host })
    end

    -- console.log(options)

    self.protocol   = options.protocol
    self.host       = options.host
    self.method     =(options.method or 'GET'):upper()
    self.path       = options.path or '/'
    self.port       = options.port or 80
    self.self_sent  = false
    self.connection = connection_found

    if (self.protocol == 'https') then
        self.port       = options.port or 443
    end

    if (self.host == 'rpc') then
        self.host = nil
        self.port = self.path
        self.path = '/'
        --console.log('ClientRequest:initialize', options)
    end

    self.encode = codec.encoder()

    local decoder = nil
    local response

    local _onFlush = function ()
        response:push()
        response = nil
    end

    local socket = options.socket
    if (not socket) then
        if (self.protocol == 'https') then
            socket = tls.connect({ host = self.host, port = self.port })
            options.connect_emitter = 'secureConnect'
        else
            socket = net.createConnection(self.port, self.host)
        end
    end

    local connectEmitter = options.connect_emitter or 'connect'

    self.socket = socket
    socket:on('error', function(...) self:emit('error', ...) end)
    socket:on(connectEmitter, function()
        self.connected = true
        self:emit('socket', socket)

        -- console.log('connect', connectEmitter)

        local _onSocketData = nil;

        local _onSocketEnd = function ()
            -- Just in case the stream ended and we still had an open response,
            -- end it.
            if response then _onFlush() end
        end

        local _onHeadersEnd = function(event)
            if self.method ~= 'CONNECT' or response == nil then
                -- If there was an old response that never closed, end it.
                if response then _onFlush() end
                -- Create a new response object
                response = IncomingMessage:new(event, socket)
                -- If the request upgrades the protocol then detatch the listeners so http codec is no longer used
                local is_upgraded
                if response.headers.upgrade then
                    is_upgraded = true
                    socket:removeListener("data", _onSocketData)
                    socket:removeListener("end",  _onSocketEnd)
                    socket:read(0)
                    if decoder and #decoder.buffer > 0 then
                        socket:pause()
                        socket:unshift(decoder.buffer)
                    end
                end
                -- Call the user callback to handle the response
                if callback then
                    callback(response)
                end

                self:emit('response', response)
                if is_upgraded then
                    return true -- break
                end
            end

            if self.method == 'CONNECT' then
                self:emit('connect', response, socket, event)
            end

            return false
        end

        local _onContentData = function(chunk)
            --console.log('_onContentData', chunk)

            if #chunk == 0 then
                -- Empty string in http-decoder means end of body
                -- End the response stream and remove the response reference.
                _onFlush()
            else
                -- Forward non-empty body chunks to the response stream.
                if not response:push(chunk) then
                    -- If it's queue is full, pause the source stream
                    -- This will be resumed by IncomingMessage:_read
                    socket:pause()
                end
            end
        end

        -- [[
        decoder = codec.createDecoder({}, function(event, error)
            --console.log('event', event, error)

            if (error) then
                socket:emit('error', error)

            elseif type(event) == "table" then
                return _onHeadersEnd(event)

            elseif response and type(event) == "string" then
                return _onContentData(event)
            end
        end)

        _onSocketData = function (chunk)
            decoder.decode(chunk)
        end
        --]]

        socket:on('data', _onSocketData)
        socket:on('end', _onSocketEnd)

        if self.ended then
            self:finish(self.ended.data, self.ended.cb)
        end
    end)
end

function ClientRequest:flushHeaders()
    if not self.headers_sent then
        self.headers_sent = true
        -- set connection
        self:_setConnection()
        Writable.write(self, self.encode(self))
    end
end

function ClientRequest:write(data, callback)
    self:flushHeaders()
    local encoded = self.encode(data)

    -- Don't write empty strings to the socket, it breaks HTTPS.
    if encoded and #encoded > 0 then
        return Writable.write(self, encoded, callback)

    else
        if callback then
            callback()
        end

        return false
    end
end

function ClientRequest:_write(data, callback)
    return self.socket:write(data, callback)
end

function ClientRequest:_setConnection()
    if not self.connection then
        table.insert(self, { 'connection', 'close' })
    end
end

function ClientRequest:finish(data, callback)
    -- Optionally send one more chunk
    if data then
        self:write(data)
    end

    self:flushHeaders()

    local ended =
    {
        cb = callback or function() end,
        data = ''
    }

    if self.connected then
        Writable.finish(self, ended.data, ended.cb)
    else
        self.ended = ended
    end
end

ClientRequest._end = ClientRequest.finish

function ClientRequest:setTimeout(msecs, callback)
    if self.socket then
        self.socket:setTimeout(msecs, callback)
    end
end

function ClientRequest:destroy()
    if self.socket then
        self.socket:destroy()
    end
end

function ClientRequest:abort()
    if self.socket then
        self.socket:destroy()
    end
end

-------------------------------------------------------------------------------
-- request

function exports.parseUrl(options)
    if type(options) == 'string' then
        options = url.parse(options)
    end

    return options
end

function exports.request(options, onResponse)
    return ClientRequest:new(exports.parseUrl(options), onResponse)
end

function exports.get(options, onResponse)
    options = exports.parseUrl(options)
    options.method = 'GET'
    local request = exports.request(options, onResponse)
    request:finish()
    return request
end

return exports
