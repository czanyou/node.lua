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
local json  	= require('json')
local fs        = require('fs')
local uv        = require('luv')

local isWindows = os.platform() == "win32"

local BASE_SOCKET_NAME = "/tmp/sock/uv-"
if (isWindows) then
    BASE_SOCKET_NAME = "\\\\?\\pipe\\uv-"
end

local MAX_MESSAGE_SIZE = 640 * 1024

-------------------------------------------------------------------------------
-- exports

local exports = {}

exports.inFlight = 0

-- bind remote methods
function exports.bind(url, ...)
    local methods = table.pack(...)

    local client = {}

    for _, method in ipairs(methods) do
        client[method] = function(...)
            local params = table.pack(...)
            local count = #params
            local callback = nil

            -- console.log(params)

            if (count > 0) then
                callback = params[count]
                params[count] = nil
            end
            params.n = nil

            if (type(callback) ~= 'function') then
                callback = function() end
            end

            exports.call(url, method, params, callback)
        end
    end

    return client
end

-- call remote method
---@param name string
---@param method string remote method name
---@param params any[] method args
---@param options table
---@param callback fun(err:string, result:any)
---@return Pipe
function exports.call(name, method, params, options, callback)
    if (type(params) ~= 'table') then
        params = { params }
    end

    if (type(options) == 'function') then
        callback = options
        options = nil
    end

    options = options or {}

    local id = nil
    local body = { jsonrpc = 2.0, method = method, params = params, id = id }
    local data = json.stringify(body)

    --console.log('body', options.data)
    local filename = BASE_SOCKET_NAME .. name .. ".sock"

    ---@class Pipe
    local client = uv.new_pipe(false)
    local timeoutTimer

    local function onClose()
        if (timeoutTimer) then
            clearTimeout(timeoutTimer)
            timeoutTimer = nil
        end

        if (client) then
            client:read_stop()
            client:close()
            client = nil
        end
    end

    exports.inFlight = (exports.inFlight or 0) + 1

    local function onError(error)
        if (callback) then
            callback(error)
            callback = nil

            exports.inFlight = (exports.inFlight or 0) - 1
        end
    end

    local timeout = options.timeout or 5000
    timeoutTimer = setTimeout(timeout, function()
        timeoutTimer = nil
        onClose()

        onError({ code = -32408, message = 'timeout' })
    end)

    local function handleRpcMessage(message)
        onClose()

        local response = json.parse(message)
        if (not response) then
            onError({ code = -32500, message = 'invalid response format'})
            return
        end

        if (callback) then
            callback(response.error, response.result)
            callback = nil

            exports.inFlight = (exports.inFlight or 0) - 1
        end
    end

    local readBuffer
    local function onRead(err, data)
        if (err) or (not data) then
            onClose()
            onError({ code = -32400, message = err or 'pipe closed'})
            return
        end

        if (readBuffer and #readBuffer > 0) then
            readBuffer = readBuffer .. data
        else
            readBuffer = data
        end

        while (readBuffer and #readBuffer >= 4) do
            local type, length = string.unpack('>BI3', readBuffer)
            if (not length) or (length <= 0) then
                onClose()
                onError({ code = -32400, message = 'invlaid message length'})
                return
            end

            if (length > MAX_MESSAGE_SIZE) then
                onClose()
                onError({ code = -32400, message = 'message length too large'})
                return
            end

            local leftover = #readBuffer - 4
            if (leftover < length) then
                break
            end

            local message = readBuffer:sub(5, length + 4)
            readBuffer = readBuffer:sub(length + 5)

            handleRpcMessage(message)
            break
        end
    end

    local function onConnect(err)
        if (err) then
            onClose()

            onError(err)
            return
        end

        client:read_start(onRead)

        local contentLength = #data
        local messageType = 1
        local header = string.pack('>BI3', messageType, contentLength)
        client:write(header)
        client:write(data)
    end

    client:connect(filename, onConnect)
    return client
end

-- create a IPC server
---@param name string IPC server listen port
---@param handler table
function exports.server(name, handler)
    name = name or 'rpc-server'

    if (not handler) then
        return
    end

    if (not fs.existsSync('/tmp/sock/')) then
        fs.mkdirSync('/tmp/sock/')
    end

    local function sendReponse(connection, response)
        local data = json.stringify(response)

        local contentLength = #data
        local messageType = 2
        local header = string.pack('>BI3', messageType, contentLength)
        connection:write(header)
        connection:write(data)
    end

    local function handleRpcMessage(message, connection)
        local request = json.parse(message)

        -- bad request
        if (not request) then
            return sendReponse(connection, {
                jsonrpc = 2.0,
                error = {code = -32700, message = 'Parse error'}
            })
        end

        local id = request.id

        -- invalid method
        local method = handler[request.method]
        if (not method) then
            return sendReponse(connection, {
                jsonrpc = 2.0,
                id = id,
                error = {code = -32601, message = 'Method not found'}
            })
        end

        local success, result = pcall(method, handler, table.unpack(request.params))
        if (not success) then
            return sendReponse(connection, {
                jsonrpc = 2.0,
                id = id,
                error = {code = -32000, message = result}
            })
        end

        sendReponse(connection, {jsonrpc = 2.0, id = id, result = result})
    end

    --local server = net.createServer(onServerConnection)
    local server = uv.new_pipe(false)

    local function onServerConnection()
        local readBuffer

        local connection = uv.new_pipe(false)
        server:accept(connection)

        local function onClose(err)
            if (connection) then
                connection:read_stop()
                connection:close()
                connection = nil
            end
        end

        local function onRead(err, data)
            if (err) or (not data) then
                return onClose(err or 'pipe closded')
            end

            -- buffer
            if (readBuffer and #readBuffer > 0) then
                readBuffer = readBuffer .. data
            else
                readBuffer = data
            end

            -- parse
            while (readBuffer and #readBuffer >= 4) do
                -- packet header
                local type, length = string.unpack('>BI3', readBuffer)
                if (length > MAX_MESSAGE_SIZE) then
                    return onClose('message length too large')
                end

                if (not length) or (length <= 0) then
                    return onClose('invlaid message length')
                end

                -- packet data
                local leftover = #readBuffer - 4
                if (leftover < length) then
                    break
                end

                local message = readBuffer:sub(5, length + 4)
                readBuffer = readBuffer:sub(length + 5)

                handleRpcMessage(message, connection)
            end
        end

        connection:read_start(onRead)
    end

    local filename = BASE_SOCKET_NAME .. name .. ".sock"
    os.remove(filename)

    server:bind(filename)
    server:listen(128, onServerConnection)

    -- print("RPC: rpc:" .. filename)
    return server
end

-- the same as exports.server
setmetatable(exports, {
    __call = function(self, ...)
        return self:server(...)
    end
})

return exports
