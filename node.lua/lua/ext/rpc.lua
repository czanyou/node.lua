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
local utils 	= require('utils')
local http 		= require('http')
local url 		= require('url')
local json  	= require('json')
local fs     	= require('fs')

local request 	= require('http/request')

local MQTT_PORT = 39901

local isWindows = os.platform() == "win32"

local BASE_SOCKET_NAME = "/tmp/uv-"
if (isWindows) then 
	BASE_SOCKET_NAME = "\\\\?\\pipe\\uv-"
end

-------------------------------------------------------------------------------
-- ServerResponse

local ServerResponse  = http.ServerResponse

function ServerResponse:sendJSON(data)
    local text = json.stringify(data)

    if (not text) then
        self:status(400)

        text = '{error="Bad request body."}'
    end

    self:setHeader("Content-Type", "application/json")
    self:setHeader("Content-Length", #text)

    self:write(text)
end

-------------------------------------------------------------------------------
-- exports

local exports = {}

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
-- @param url {String|Number}
-- @param method {String} remote method name
-- @param params {Array} method args
-- @param callback {Function} - function(err, result)
function exports.call(url, method, params, callback)
	if (type(params) ~= 'table') then
		params = { params }
	end

	-- call(port, method, params, callback)
	if (tonumber(url) ~= nil) then
		url = 'http://127.0.0.1:' .. tostring(url)

	elseif (not url:startsWith('http')) then
		url = 'rpc://rpc' .. BASE_SOCKET_NAME .. url .. ".sock"
	end

	--console.log(url, method, params)
	callback = callback or function() end

	local id = nil
	local body = {jsonrpc = 2.0, method = method, params = params, id = id}

	local options = {}
	options.data = json.stringify(body)
	options.contentType = "application/json"

	--console.log('body', options.data)
	request.post(url, options, function(err, response, body)
		--console.log(err, response, body)
		if (err) then
			callback(err)
			return
		end

		local data = json.parse(body)
		if (not data) then
			callback('invalid response')
			return
		end

		callback(data.error, data.result)
	end)
end

-- send PUBLISH message to mqtt.app
-- @param topic {String} target MQTT topic name
-- @param data {String} MQTT publish message payload
-- @param callback {Function} - function(err, result)
function exports.publish(topic, data, qos, callback)
	exports.call(MQTT_PORT, 'publish', { topic, data, qos }, callback)
end

-- create a IPC server
-- @param port IPC server listen port
-- @param callback {Function} - function(event, data)
function exports.server(port, handler, callback)
	port = port or 9001
	callback = callback or function() end

	local handleRpcRequest = function(handler, request, response)
		local content = request.body
		local body = json.parse(content)

		-- bad request
		if (not body) then
			response:sendJSON({jsonrpc = 2.0, error = { 
				code = -32700, message = 'Parse error'}})
			return
		end

		local id = body.id

		-- invalid method
		local method = handler[body.method]
		if (not method) then
			response:sendJSON({jsonrpc = 2.0, id = id, error = { 
				code = -32601, message = 'Method not found'}})
			return
		end

		utils.async(function()
			local status, ret = pcall(method, handler, table.unpack(body.params))
			if (not status) then
				response:sendJSON({jsonrpc = 2.0, id = id, error = { 
					code = -32000, message = ret}})

				console.log('pcall error: ', ret)
				return
			end

			response:sendJSON({jsonrpc = 2.0, id = id, result = ret})
		end)
	end

	local handleRequest = function(handler, request, response)
		local sb = StringBuffer:new()

		request:on('data', function(data)
			sb:append(data)
		end)

		request:on('end', function(data)
			sb:append(data)
			request.body = sb:toString()

			handleRpcRequest(handler, request, response)
		end)
	end

    local server = http.createServer(function(request, response) 
    	handleRequest(handler, request, response)
    end)

    server:on('error', function(err, name)
        callback('error', err, name)
    end)

    server:on('close', function()
    	callback('close')
    end)

    server:on('listening', function()
        callback('listening')
    end)

    if (tonumber(port) == nil) then
    	local filename = BASE_SOCKET_NAME .. port .. ".sock"
     	os.remove(filename)
   	
	    server:listen(filename)
		print("RPC server listening at " .. filename)

    else
		local IPC_HOST = '127.0.0.1'
	    server:listen(port, IPC_HOST)
		print("RPC server listening at http://" .. IPC_HOST .. ":" .. port)

    end

	return server
end

-- Subscribe a topic with mqtt.app
-- @param options {Object}
-- - topic {String} MQTT topic name
-- - port {Number} local notify callback  port
-- - notify {Function} local notify callback function
-- @param callback {Function} - function(err, result)
function exports.subscribe(options, callback)
	if (type(options) ~= 'table') then
		callback('options excepted')
		return

	elseif (tonumber(options.port) == nil) then
		callback('options.port excepted')
		return

	elseif (options.topic == nil) then
		callback('options.topic excepted')
		return

	elseif (options.notify == nil) then
		callback('options.notify excepted')
		return
	end

	if (not options.server) then
		options.server = exports.server(options.port, options)
	end

	-- subscribe
	local params = {options.topic, '', options.port }
	exports.call(MQTT_PORT, 'subscribe', params, function(err, result)
		if (err) then
			console.log('subscribe', err)
		end

		if (callback) then
			callback(err, result)
		end
	end)

	-- interval
	local expires = options.expires or 30
	options.timer = setInterval(expires * 1000, function()
		exports.call(MQTT_PORT, 'subscribe', params)
	end)
end

-- Unsubscribe a topic with mqtt.app
-- @param options {Object}
-- @param callback {Function} - function(err, result)
function exports.unsubscribe(options, callback)
	if (type(options) ~= 'table') then
		callback('options excepted')
		return
	end

	clearInterval(options.timer)

	local params = { options.topic }
	exports.call(MQTT_PORT, 'unsubscribe', params, function(err, result)
		if (err) then
			console.log('unsubscribe', err)
		end

		if (callback) then
			callback(err, result)
		end
	end)
end

-- the same as exports.server
setmetatable(exports, {
	__call = function(self, ...) 
		return self:server(...)
	end
})

return exports
