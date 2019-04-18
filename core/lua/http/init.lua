--[[

Copyright 2015 The Luvit Authors. All Rights Reserved.
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

local meta = { }
meta.name        = "lnode/http"
meta.version     = "1.2.3"
meta.license     = "Apache 2"
meta.description = "Node-style http client and server module for lnode"
meta.tags        = { "lnode", "http", "stream" }

local exports = { meta = meta }

local net   = require('net')
local url   = require('url')
local utils = require('util')
local codec = require('http/codec')

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

local ServerResponse = Writable:extend()
exports.ServerResponse = ServerResponse

function ServerResponse:initialize(socket)
    Writable.initialize(self)
    local encode = codec.encoder()
    self.socket      = socket
    self.encode      = encode
    self.statusCode  = 200
    self.headersSent = false
    self.headers     = setmetatable( { }, headerMeta)

    for _, evt in pairs( { 'close', 'drain', 'end' }) do
        self.socket:on(evt, utils.bind(self.emit, self, evt))
    end
end

-- Override this in the instance to not send the date
ServerResponse.sendDate = true

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
    if self.headersSent then return end
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
    local h = self.encode(head)
    self.socket:write(h)
end

function ServerResponse:write(chunk, callback)
    if chunk and #chunk > 0 then
        self.hasBody = true
    end

    self:flushHeaders()
    return self.socket:write(self.encode(chunk), callback)
end

function ServerResponse:done(chunk)
    if chunk and #chunk > 0 then
        self.hasBody = true
    end

    self:flushHeaders()
    local last = ""
    if chunk then
        last = last .. self.encode(chunk)
    end

    last = last ..(self.encode("") or "")
    local _maybeClose = function ()
        self:emit('finish')
        if not self.keepAlive then
            self.socket:_end()
        end
    end

    if #last > 0 then
        self.socket:write(last, function()
            _maybeClose()
        end )
    else
        _maybeClose()
    end
end

ServerResponse._end   = ServerResponse.done
ServerResponse.finish = ServerResponse.done


function ServerResponse:writeHead(newStatusCode, newHeaders)
    if (self.headersSent) then
        print('writeHead', "headers already sent")
        return
    end

    self.statusCode = newStatusCode

    if (not self.headers) then
        self.headers = setmetatable( { }, headerMeta)
    end

    for k, v in pairs(newHeaders) do
        self.headers[k] = v
    end
end

-------------------------------------------------------------------------------
-- handleConnection

function exports.handleConnection(socket, onRequest)

    local decoder = nil
    local request, response

    local _onFlush = function ()
        request:push()
        request = nil
    end

    local _onTimeout = function ()
        socket:_end()
    end

    local _onEnd = function ()
        process:removeListener('exit', _onTimeout)
        -- Just in case the stream ended and we still had an open request,
        -- end it.
        if request then _onFlush() end
    end

    local _onHeadersEnd = function(event)
        -- If there was an old request that never closed, end it.
        if request then
            _onFlush()
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
            socket:removeListener("timeout", _onTimeout)
            socket:removeListener("data",    _onData)
            socket:removeListener("end",     _onEnd)

            process:removeListener('exit', _onTimeout)
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
            _onFlush()
            return
        end

        -- Forward non-empty body chunks to the request stream.
        if not request:push(chunk) then
            -- If it's queue is full, pause the source stream
            -- This will be resumed by IncomingMessage:_read
            socket:pause()
        end
    end

    -- [[
    decoder = codec.createDecoder({}, function(event, error)
        --console.log('event', event, error)

        if (error) then
            socket:emit('error', error)

        elseif type(event) == "table" then
            return _onHeadersEnd(event)

        elseif request and type(event) == "string" then
            return _onContentData(event)
        end
    end)

    local _onData = function (chunk)
        decoder.decode(chunk)
    end
    --]]

    socket:once('timeout', _onTimeout)

    -- set socket timeout
    socket:setTimeout(120000)
    socket:on('data', _onData)
    socket:on('end',  _onEnd)

    process:once('exit', _onTimeout)
end

function exports.createServer(onRequest)
    return net.createServer(function(socket)
        return exports.handleConnection(socket, onRequest)
    end)
end

-------------------------------------------------------------------------------
-- ClientRequest

local ClientRequest = Writable:extend()
exports.ClientRequest = ClientRequest

function exports.ClientRequest.getDefaultUserAgent()
    if exports.ClientRequest._defaultUserAgent == nil then
        exports.ClientRequest._defaultUserAgent = 'lnode/http/' .. exports.meta.version
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

    self.host       = options.host
    self.method     =(options.method or 'GET'):upper()
    self.path       = options.path or '/'
    self.port       = options.port or 80
    self.self_sent  = false
    self.connection = connection_found

    if (self.host == 'rpc') then
        self.host = nil
        self.port = self.path
        self.path = '/'
        --console.log('ClientRequest:initialize', options)
    end

    self.encode = codec.encoder()

    local decoder = nil
    local buffer = ''
    local response

    local _onFlush = function ()
        response:push()
        response = nil
    end

    local socket = options.socket or net.createConnection(self.port, self.host)
    local connect_emitter = options.connect_emitter or 'connect'

    self.socket = socket
    socket:on('error', function(...) self:emit('error', ...) end)
    socket:on(connect_emitter, function()
        self.connected = true
        self:emit('socket', socket)

        --console.log('request', self)

        local _onEnd = function ()
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
                    socket:removeListener("data", _onData)
                    socket:removeListener("end",  _onEnd)
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

        local _onData = function (chunk)
            decoder.decode(chunk)
        end
        --]]

        socket:on('data', _onData)
        socket:on('end', _onEnd)

        if self.ended then
            self:_done(self.ended.data, self.ended.cb)
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

function ClientRequest:_done(data, callback)
    self:_end(data, function()
        if callback then
            callback()
        end
    end )
end

function ClientRequest:_setConnection()
    if not self.connection then
        table.insert(self, { 'connection', 'close' })
    end
end

function ClientRequest:done(data, callback)
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
        self:_done(ended.data, ended.cb)
    else
        self.ended = ended
    end
end

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
    request:done()
    return request
end

return exports
