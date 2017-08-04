local http 		= require('http')
local net  		= require('net')
local json 		= require('json')
local request 	= require('http/request')
local url 		= require('url')
local core   	= require('core')

local exports = {}

local HT_OPCODE_CONT 		= 0x00
local HT_OPCODE_TEXT 		= 0x01
local HT_OPCODE_BIN 		= 0x02
local HT_OPCODE_JSON 		= 0x03
local HT_OPCODE_CLOSE 		= 0x08
local HT_OPCODE_PING 		= 0x09
local HT_OPCODE_PONG 		= 0x0A
local HT_OPCODE_CONNECT 	= 0x0B
local HT_OPCODE_ACK 		= 0x0C

local HT_FLAG_END 			= 0x10
local HT_FLAG_VERSION 		= 0x80

local HT_HEAD_SIZE 			= 4

local function sendRawMessage(connection, data, flags, channel)
	if (not connection) then
		return
	end

	data    = data or ''
	flags 	= flags or HT_OPCODE_BIN
	channel = channel or 0x00

	local start = HT_FLAG_VERSION | (flags or 0x00)

	local head = string.pack(">BBI2", flags, channel, #data)
	connection:write(head)
	connection:write(data)
end

local function sendJsonMessage(connection, message, channel)
	local data = json.stringify(message)

	local flags = HT_OPCODE_JSON
	sendRawMessage(connection, data, flags, channel)
end

local function sendBinMessage(connection, data, channel)
	local flags = HT_OPCODE_BIN
	sendRawMessage(connection, data, flags, channel)
end

local function sendTextMessage(connection, data, channel)
	local flags = HT_OPCODE_TEXT
	sendRawMessage(connection, data, flags, channel)
end

local function sendConnectMessage(connection, uuid)
	local message = {
		method 	= "connect",
		uuid 	= uuid
	}

	local flags = HT_OPCODE_CONNECT
	local data  = json.stringify(message)
	sendRawMessage(connection, data, flags, 0)
end

local function sendAckMessage(connection, ret)
	local message = {
		method 	= "ack",
		ret 	= ret
	}

	local flags = HT_OPCODE_ACK
	local data  = json.stringify(message)
	sendRawMessage(connection, data, flags, 0)
end

local function sendPingMessage(connection, data)
	local flags = HT_OPCODE_PING
	sendRawMessage(connection, data, flags, 0)
end

local function sendPongMessage(connection, data)
	local flags = HT_OPCODE_PONG
	sendRawMessage(connection, data, flags, 0)
end

local function sendCloseMessage(connection, channel)
	local flags = HT_OPCODE_CLOSE
	sendRawMessage(connection, nil, flags, channel)
end

local function readMessage(connection, buffer, callback)
	if (#buffer < HT_HEAD_SIZE) then
		return
	end

	local flags, channel, length = string.unpack('>BBI2', buffer)
	if (#buffer - HT_HEAD_SIZE < length) then
		return
	end

	local message = buffer:sub(HT_HEAD_SIZE + 1, HT_HEAD_SIZE + length)
	callback(connection, flags, channel, message)

	return buffer:sub(length + HT_HEAD_SIZE + 1)
end

local HT_CLIENT_UUID 	= '70313a69-3dba-4111-ad75-a8a4ae7b5c0f'
local HT_SERVER_PORT 	= 8083
local HT_SERVER_HOST 	= '127.0.0.1'

--/////////////////////////////////////////////////////////////
-- tunnel server

local TunnelServer = core.Object:extend()
exports.TunnelServer = TunnelServer

local function createTunnelServer(self, options)
	local server

	local onConnectMessage = function(connection, message) 
		connection.uuid = message.uuid

		self.sessions[message.uuid] = connection
		console.log('tunnel server connection uuid = ' .. message.uuid)

		sendAckMessage(connection, 0)
	end

	local onDataMessage = function(connection, channel, message) 
		local callbacks = connection.callbacks
		if (not callbacks) then
			return
		end

		local callback = callbacks[channel]
		if (callback) then
			callback(message)
		end
	end

	local onCloseMessage = function(connection, channel)
		console.log('onCloseMessage', channel)

		local callbacks = connection.callbacks
		if (not callbacks) then
			return
		end

		callbacks[channel] = nil
	end

	local onPingMessage = function(connection, channel)
		connection.updated = os.uptime()
		sendPongMessage(connection)
	end	

	local onMessage = function(connection, flags, channel, message) 
		--console.log('server message', message)

		local opcode = flags & 0x0f
		if (opcode == HT_OPCODE_JSON) then
			message = json.parse(message) or {}
			onDataMessage(connection, channel, message)

		elseif (opcode == HT_OPCODE_BIN) then
			onDataMessage(connection, channel, message)

		elseif (opcode == HT_OPCODE_TEXT) then
			onDataMessage(connection, channel, message)

		elseif (opcode == HT_OPCODE_PING) then
			onPingMessage(connection, channel)

		elseif (opcode == HT_OPCODE_CONNECT) then
			message = json.parse(message) or {}
			onConnectMessage(connection, message)

		elseif (opcode == HT_OPCODE_CLOSE) then
			onCloseMessage(connection, channel)
		end
	end

	local onData = function(connection, data)
		--console.log('server data', data)
		if (not connection.buffer) then
			connection.buffer = ''
		end
		connection.buffer = connection.buffer .. data

		-- [[
		while (true) do
			local buffer = connection.buffer
			local ret = readMessage(connection, buffer, onMessage)
			if (not ret) then
				break
			end

			connection.buffer = ret
		end
		--]]
	end

	server = net.createServer(options, function(connection)
		local address = connection:address()
		console.log("connection", address.ip, address.port)

		connection:on('data', function(data)
			onData(connection, data)
		end)

		connection:on('end', function(...)
			console.log('tunnel server connection end', ...)
		end)	
	end)

	self.sessions = {}

	server:on('listening', function()
		console.log("tunnel server listening", options.port)
	end)

	server:on('error', function(...)
		console.log("tunnel server error", ...)
	end)

	server:listen(options.port)

	self.server = server
end

--/////////////////////////////////////////////////////////////
-- http proxy

local function sendHttpResponse(response, title)
	title = title or 'HTS Server'
	local info = "<p>HTTP Tunnel Server " .. os.uptime() .. "</p>"
	local data = "<h1>" .. title .. "</h1>" .. info
	response:setHeader("Content-Type", "text/html")
    response:setHeader("Content-Length", #data)
	response:write(data)
end

local function sendListResponse(self, response)
	local title = 'HTS Server'
	local info = "<p>HTTP Tunnel Server " .. os.uptime() .. "</p>"
	--info = info .. json.stringify(self.sessions)
	console.log(self.sessions)

	local list = {}
	list[#list + 1] = '<html><head>'
	list[#list + 1] = '<style>table td { padding: 4px 8px; }</style>'
	list[#list + 1] = '</head><body>'
	list[#list + 1] = "<h1>" .. title .. "</h1>"

	list[#list + 1] = '<table>'
	list[#list + 1] = '<tr><td>UUID</td><td>Updated</td><td>counter</td><td>channels</td></tr>'

	for key, value in pairs(self.sessions) do
		list[#list + 1] = '<tr><td>'
		list[#list + 1] = key
		list[#list + 1] = '</td><td>'
		list[#list + 1] = math.floor((os.uptime() - (value.updated or 0)) * 100) / 100
		list[#list + 1] = '</td><td>'
		list[#list + 1] = value.channelId or 0
		list[#list + 1] = '</td><td>'
		list[#list + 1] = #(value.callbacks or {})
		list[#list + 1] = '</td></tr>'
	end
	list[#list + 1] = '</table>'


	local data = table.concat(list)
	response:setHeader("Content-Type", "text/html")
    response:setHeader("Content-Length", #data)
	response:write(data)
end

local function sendHttpRequest(connection, request)
	-- channel
	local message = {
		method = "request",
		request = {
			method 	= request.method,
			url 	= request.url,
			headers = request.headers
		}
	}

	local channel = ((connection.channelId or 0) % 65500) + 1
	connection.channelId = channel
	sendJsonMessage(connection, message, channel) -- send message to tunnel client

	--console.log('sendHttpRequest', message)
	return channel
end

local onHttpConnection = function(self, request, response)
	local uri = url.parse(request.url)
	--console.log('uri', uri)

	-- uuid
	local pathname = uri.pathname or ''
	local tokens = pathname:split('/') or {}
	local uuid = tokens[2]

	if (not uuid) or (#uuid == 0) then
		sendListResponse(self, response)
		return
	end

	console.log('proxy request uuid = ' .. uuid)

	-- connection
	local sessions = self.sessions or {}
	local connection = sessions[uuid]
	--console.log(connection)

	if (not connection) then
		sendHttpResponse(response, 'Session Not Found')
		return
	end

	local channel = sendHttpRequest(connection, request)
	console.log(channel)

	-- timeout
	local timerId
	local timeout = 10 * 1000
	timerId = setTimeout(timeout, function()
		sendHttpResponse(response, 'Session Timeout')
	end)

	local closeTimer = function()
		-- clear timeout
		if (timerId) then
			clearTimeout(timerId)
			timerId = nil
		end
	end

	-- callback
	if (not connection.callbacks) then
		connection.callbacks = {}
	end	

	connection.callbacks[channel] = function(data)
		--console.log('tunnel client return:', data)

		if (type(data) == 'table') then
			local ret = data.response or {}
			local headers = ret.headers or {}
			for k, v in pairs(headers) do
				response:setHeader(k, v)
			end
			response.statusCode = ret.statusCode or 200

			local contentLength = tonumber(ret.contentLength or 0)
		    response:setHeader("Content-Length", contentLength or 0)
		
			if (contentLength <= 0) then
				response:done()
				closeTimer()
			end
		else
			-- response
			response:write(data)
			--response:done()

			closeTimer()
		end
	end
end

local function createProxyServer(self, options)
	self.proxy = http.createServer(function(...)
		onHttpConnection(self, ...)
	end)

	self.proxy:listen(options.http_port or 8080)
end

function TunnelServer:initialize(options)
	createProxyServer(self, options)
	createTunnelServer(self, options)
end

function exports.createServer(options)
	local server = TunnelServer:new(options)
	return server
end

--/////////////////////////////////////////////////////////////
-- tunnel client

-- [[
local TunnelClient = core.Object:extend()
exports.TunnelClient = TunnelClient

function TunnelClient:initialize(options)

	self.options = options or {}
end

function TunnelClient:connect(callback)
	local client
	local options = self.options

	local onConnect = function()
		console.log("tunnel client connected")

		sendConnectMessage(client, options.uuid)
	end

	local host = options.host
	local port = options.port

	console.log('tunnel client connecting', host, port)
	client = net.connect(port, host, function()
		setImmediate(onConnect)
	end)
	self.client = client

	local sendResponseMessage = function(channel, response, body)
		local contentLength = 0
		if (body) and (#body > 0) then
			contentLength = #body
		end

		local message = {
			method = 'response',
			response = {
				statusCode 		= response.statusCode,
				headers 		= response.headers,
				contentLength 	= contentLength
			}
		}

		--console.log(contentLength, body)

		sendJsonMessage(client, message, channel)

		if (contentLength > 0) then
			--sendRawMessage(client, body, HT_OPCODE_BIN, channel)

			local leftover = #body
			local offset = 1
			while (leftover > 0) do
				local size = 1024 * 32
				if (leftover < 1024) then
					size = leftover
				end

				local data = body:sub(offset, offset + size - 1)
				sendRawMessage(client, data, HT_OPCODE_BIN, channel)

				offset = offset + size
				leftover = leftover - size
			end
		end

		sendCloseMessage(client, channel)
	end

	local onRequestMessage = function(channel, message) 
		--console.log('client get: ', channel, message)

		-- uuid
		local uri 		= url.parse(message.request.url)
		local pathname 	= uri.pathname or ''
		local tokens 	= pathname:split('/')
		local uuid 	 	= tokens[2] or ''
		local handle 	= tokens[3] or ''
		console.log('tunnel client request uuid = ' .. uuid, handle)

		--console.log('uri', uri)

		table.remove(tokens, 2)
		table.remove(tokens, 2)

		local hosts = self.hosts or {}
		local host = hosts[handle]
		if (not host) then
			local body = json.stringify(self.hosts)
			sendResponseMessage(channel, {statusCode = 200}, body)
			return
		end

		tokens[#tokens + 1] = uri.search or ''

		local newUrl = 'http://' .. host .. table.concat(tokens, '/')
		console.log(newUrl)

		local options = {}
		request.get(newUrl, options, function(err, response, body)
			if (err) then
				console.log(err)
				sendResponseMessage(channel, {statusCode = 404})
				return
			end

			console.log('http client return:', response.statusCode)
			sendResponseMessage(channel, response, body)
		end)
	end

	local onPongMessage = function(connection, channel)
		self.updated = os.uptime()
	end

	local onAckMessage = function(connection, channel)
		self.updated = os.uptime()
		console.log('server ack', channel)
	end

	local onCloseMessage = function(connection, channel)
		console.log('server close', channel)
	end

	local onMessage = function(connection, flags, channel, message) 
		--console.log('server message', message)

		local opcode = flags & 0x0f
		if (opcode == HT_OPCODE_JSON) then
			local value = json.parse(message) or {}
			if (value.method == 'request') then
				onRequestMessage(channel, value)
			end

		elseif (opcode == HT_OPCODE_BIN) then

		elseif (opcode == HT_OPCODE_TEXT) then

		elseif (opcode == HT_OPCODE_PONG) then
			onPongMessage(connection, channel)

		elseif (opcode == HT_OPCODE_ACK) then
			onAckMessage(connection, channel)

		elseif (opcode == HT_OPCODE_CLOSE) then
			onCloseMessage(connection, channel)
		end
	end

	client:on('data', function(data)
		if (not self.buffer) then
			self.buffer = ''
		end
		self.buffer = self.buffer .. data

		while (true) do
			local buffer = self.buffer
			local ret = readMessage(client, buffer, onMessage)
			if (not ret) then
				break
			end

			self.buffer = ret
		end
	end)

	client:on('end', function(...)
		console.log("client end", ...)
	end)

	client:on('error', function(...)
		console.log("client error", ...)
		self:onError(...)
	end)

	self.timerId = setInterval(3000, function()
		self:onTimer()
	end)
end

function TunnelClient:onTimer()
	sendPingMessage(self.client)

	local now = os.uptime()
	local span = now - (self.updated or 0)
	if (span > 10) then
		self.client = nil
		self.updated = os.uptime()
		self:connect()

		console.log('span', span)
	end
end

function TunnelClient:onError(error)

end

function TunnelClient:close(callback)
	if (self.timerId) then
		clearInterval(self.timerId)
		self.timerId = nil
	end
end

--]]

function exports.connect(options, hosts)
	local client = TunnelClient:new(options)
	client.hosts = hosts or {}
	client:connect()
	return client
end

return exports
