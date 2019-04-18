--[[

Copyright 2014-2015 The Luvit Authors. All Rights Reserved.
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

--[[
The net module provides you with an asynchronous network wrapper. It contains
functions for creating both servers and clients (called streams). You can
include this module with require('net');.
--]]
local meta = { }
meta.name        = "lnode/net"
meta.version     = "1.2.1"
meta.license     = "Apache 2"
meta.description = "Node-style net client and server module for lnode"
meta.tags        = { "lnode", "tcp", "pipe", "stream" }

local exports = { meta = meta }

local uv    = require('uv')
local timer = require('timer')
local util = require('util')

local Emitter = require('core').Emitter
local Duplex  = require('stream').Duplex

-------------------------------------------------------------------------------
--[[ Socket ]]--

local Socket = Duplex:extend()
exports.Socket = Socket

function Socket:initialize(options)
    Duplex.initialize(self)

    if type(options) == 'number' then
        options = { fd = options }

    elseif options == nil then
        options = { }
    end

    if options.handle then
        self._handle = options.handle

    elseif options.fd then
        local typ = uv.guess_handle(options.fd);
        if typ == 'TCP' then
            self._handle = uv.new_tcp()

        elseif typ == 'PIPE' then
            self._handle = uv.new_pipe()
        end
    end

    self._connecting = false
    self._reading    = false
    self._destroyed  = false

    self:on('finish', util.bind(self._onSocketFinish, self))
    self:on('_socketEnd', util.bind(self._onSocketEnd, self))
end

function Socket:address()
    return uv.tcp_getpeername(self._handle)
end

function Socket:bind(ip, port)
    --console.log(self._handle, ip, port)
    if (self.is_pipe) then
        return self._handle:bind(port)
    end

    return uv.tcp_bind(self._handle, ip, tonumber(port))
end

function Socket:connect(...)
    local args = { ... }
    local options = { }
    local callback

    if (type(args[1]) == 'table') then
        -- connect(options, [callback])
        options  = args[1]
        callback = args[2]

    elseif (tonumber(args[1]) ~= nil) then
        -- connect(port, [host], [callback])
        options.port = tonumber(args[1])
        if type(args[2]) == 'string' then
            options.host = args[2];
            callback = args[3]
        else
            callback = args[2]
        end

    else
        -- connect(path, [callback])
        callback = args[2]
        options.path = args[1]

    end

    callback = callback or function() end

    timer.active(self)
    self._connecting = true

    -- unix socket
    if (options.path) then
        if not self._handle then
            self._handle = uv.new_pipe(false)
        end

        self.is_pipe = true
        timer.active(self)

        uv.pipe_connect(self._handle, options.path, function(err)
            --print('Socket:connect', err)
            if err then
                return self:destroy(err)
            end

            timer.active(self)
            self._connecting = false
            self:emit('connect')

            if callback then callback() end
        end )

        return self
    end

    -- TCP socket
    if not self._handle then
        self._handle = uv.new_tcp()
    end

    if not options.host then
        options.host = '127.0.0.1'
    end

    --console.log(options)
    uv.getaddrinfo(options.host, options.port, { socktype = "stream" }, function(err, res)
        timer.active(self)
        if err then
            return self:destroy(err)
        end

        --console.log(res)

        local rinfo = res[1]
        if (not rinfo) or (not rinfo.port) then
            return self:destroy('Invalid host address: ' .. tostring(options.host))
        end
        --print('Socket:connect', rinfo.addr, rinfo.port)
        if self.destroyed then return end

        uv.tcp_connect(self._handle, rinfo.addr, rinfo.port, function(err)
            --print('Socket:connect', err)
            if err then
                return self:destroy(err)
            end
            timer.active(self)
            self._connecting = false
            self:emit('connect')
            if callback then callback() end
        end )
    end )

    return self
end

function Socket:done(callback)
    return self:destroy(nil, callback)
end

function Socket:destroy(exception, callback)
    callback = callback or function() end
    if self.destroyed == true or self._handle == nil then
        return callback()
    end

    timer.unenroll(self)
    self.destroyed = true
    self.readable = false
    self.writable = false

    if uv.is_closing(self._handle) then
        timer.setImmediate(callback)
    else
        uv.close(self._handle, function()
            self:emit('close')
            callback()
        end )
    end

    if exception then
        timer.setImmediate( function()
            self:emit('error', exception)
        end )
    end
end

function Socket:getsockname()
    if (self.is_pipe) then
        return uv.pipe_getsockname(self._handle)
    end

    return uv.tcp_getsockname(self._handle)
end

function Socket:keepalive(enable, delay)
    uv.tcp_keepalive(self._handle, enable, delay)
end

function Socket:listen(backlog)
    backlog = backlog or 128

    local _onListen = function()
        local socket = nil
        if (self.is_pipe) then
            local client = uv.new_pipe(false)
            self._handle:accept(client)
            socket = Socket:new( { handle = client })
            socket.is_pipe = true

        else
            local client = uv.new_tcp()
            uv.accept(self._handle, client)
            socket = Socket:new( { handle = client })
        end


        self:emit('connection', socket)
    end

    return uv.listen(self._handle, backlog, _onListen)
end

function Socket:nodelay(enable)
    uv.tcp_nodelay(self._handle, enable)
end

function Socket:_onSocketFinish()
    if self._connecting then
        return self:once('connect', util.bind(self._onSocketFinish, self))
    end
    if not self.readable then
        return self:destroy()
    end
end

function Socket:_onSocketEnd()
    self:once('end', function()
        self:destroy()
    end)
end

function Socket:pause()
    Duplex.pause(self)
    if not self._handle then return end
    self._reading = false
    uv.read_stop(self._handle)
end

function Socket:_read(n)
    local _onRead

    _onRead = function (err, data)
        timer.active(self)
        if err then
            return self:destroy(err)

        elseif data then
            self:push(data)

        else
            self:push(nil)
            self:emit('_socketEnd')
        end
    end

    if self._connecting then
        self:once('connect', util.bind(self._read, self, n))

    elseif not self._reading then
        self._reading = true
        uv.read_start(self._handle, _onRead)
    end
end

function Socket:resume()
    Duplex.resume(self)
    self:_read(0)
end

function Socket:setTimeout(msecs, callback)
    if msecs > 0 then
        timer.enroll(self, msecs)
        timer.active(self)
        if callback then self:once('timeout', callback) end
    elseif msecs == 0 then
        timer.unenroll(self)
    end
end

function Socket:shutdown(callback)
    if self.destroyed == true then
        return callback()
    end

    if uv.is_closing(self._handle) then
        return callback()
    end

    uv.shutdown(self._handle, callback)
end

function Socket:_write(data, callback)
    if not self._handle then return end
    uv.write(self._handle, data, function(err)
        if err then
            self:destroy(err)
            return callback(err)
        end
        callback()
    end )
end

-------------------------------------------------------------------------------
-- Server

local Server = Emitter:extend()
exports.Server = Server

function Server:init(options, callback)
    -- init(callback)
    if type(options) == 'function' then
        callback = options
        options  = {}
    end

    if (callback) then
        self._connectionListener = callback
        self:on('connection', callback)
    end

    if options.handle then
        self._handle = options.handle
    end
end

function Server:address()
    if self._handle then
        return self._handle:getsockname()
    end
end

function Server:close(callback)
    self:destroy(nil, callback)
end

function Server:destroy(err, callback)
    self._handle:destroy(err, callback)
    self:emit('close')
end

function Server:listen(port, host, backlog, callback)
    -- listen(path, backlog, callback)
    if (tonumber(port) == nil) then
        -- TODO: unix socket
        self.is_pipe = true

        backlog  = host
        callback = backlog
        host     = nil
    end

    -- listen(port, callback)
    if (type(host) == 'function') then
        callback = host
        host     = nil
        backlog  = nil

    -- listen(port, host, callback)
    elseif (type(backlog) == 'function') then
        callback = backlog
        backlog  = nil
    end

    host    = host or '0.0.0.0'
    backlog = backlog or 128

    if not self._handle then
        local handle = nil
        if (self.is_pipe) then
            handle = uv.new_pipe(false)
            --console.log(handle)
        else
            handle = uv.new_tcp()
        end
        self._handle = Socket:new({ handle = handle })
    end

    local serverSocket = self._handle
    local ret, message, err

    serverSocket.is_pipe = self.is_pipe
    ret, message, err = serverSocket:bind(host, port)
    if (not ret) then
        --console.log(message, err)
        self:emit('error', message, err)
        self:destroy(err, callback)
        return
    end

    ret, message, err = serverSocket:listen(backlog)
    if (not ret) then
        self:emit('error', message, err)
        self:destroy(err, callback)
        return
    end

    serverSocket:on('connection', function(client)
        self:emit('connection', client)
    end)

    serverSocket:on('error', function(err)
        self:emit('error', err)
    end)

    serverSocket:on('close', function()
        self:emit('close')
    end)

    self:emit('listening')

    if callback then
        timer.setImmediate(callback)
    end

    return self
end

-------------------------------------------------------------------------------
-- Exports

function exports.createConnection(port, host, callback)
    -- connect(options, callback)
    if type(port) == 'table' then
        local options = port
        port    = options.port
        host    = options.host
        callback = host
    end

    local socket = Socket:new()
    socket:connect(port, host, callback)
    return socket
end

exports.connect = exports.createConnection

-- callback: 'connection' listener
function exports.createServer(options, callback)
    local server = Server:new()
    server:init(options, callback)
    return server
end

return exports
