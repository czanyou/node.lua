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
local core 	= require('core')
local net 	= require('net')
local timer = require('timer')
local url 	= require('url')
local utils = require('util')
local json  = require('json')

local rtsp 		= require('rtsp/message')
local rtp 		= require('rtsp/rtp')
local session 	= require('media/session')
local source 	= require('media/source')

local RtspConnection = require('rtsp/connection').RtspConnection

local exports = { }

local TAG = "RtspProxy"

exports = { meta = exports }

-------------------------------------------------------------------------------
--- ProxySession

local MediaSource = source.MediaSource

local ProxySession = MediaSource:extend()
exports.ProxySession = ProxySession

function ProxySession:initialize()
	MediaSource.initialize(self)

	self.proxy 			= nil
	self.pathname		= nil
	self.packetIndex	= 0
	self.lastActiveTime = 0

	self.lastActiveTime = process.now()

	self.interval = timer.setInterval(10 * 1000, function()
		if (self:isTimeout()) then
			self:close()

			self:emit('timeout')
		end
	end)
end

function ProxySession:close()
	MediaSource.close(self)

	self.proxy 			= nil
	self.packetIndex	= 0

	if (self.interval) then
		timer.clearInterval(self.interval)
		self.interval = nil

		self:emit('close')
	end
end

function ProxySession:isTimeout(timeout)
	if (not timeout) then
		timeout = 1000 * 60
	end

	local now = process.now()
	local span = math.abs(now - self.lastActiveTime)
	return span > timeout
end

function ProxySession:reset()
	self.packetIndex	= 0
end

function ProxySession:writeStream(meta, rtpPacket, offset)
	local limit  = #rtpPacket

	local sampleTime = meta.sampleTime * 1000
	local flags = 0

	if (self.packetIndex == 0) then
		local code, pid = string.unpack('>BI2', rtpPacket, offset)

		pid = pid & 0x1fff
		--print('_on_rtp_session', code, pid)
		if (pid == 0) then
			flags = 0x01
		end
	end

	while (offset <= limit) do
		if (meta.marker) and ((offset + 188) > limit) then
			flags = flags + 0x02
		end

		--console.log('_on_rtp_session', offset, limit)
		local packet = rtpPacket:sub(offset, offset + 188 - 1)
		self:writeTSPacket(packet, sampleTime, flags)

		offset = offset + 188
		flags = 0
	end

	self.packetIndex = self.packetIndex + 1

	if (meta.marker) then
		self.packetIndex = 0
	end

	self.lastActiveTime = process.now()
end

function ProxySession:writeTSPacket(packet, sampleTime, flags)
	self:writeSample(packet, sampleTime, flags)
end

-------------------------------------------------------------------------------
--- RtspProxy

local RtspProxy = core.Emitter:extend()
exports.RtspProxy = RtspProxy

function RtspProxy:initialize()
	self.connections  = {}
	self.sessions     = {}
	self.connectionId = 1
	self.serverSocket = nil
end

function RtspProxy:close()
	-- connections
	for k,connection in pairs(self.connections) do
		connection:close()
	end
	self.connections = {}

	-- sessions
	for key,proxySession in pairs(self.sessions) do
		print(TAG, 'close', proxySession.pathname)
		proxySession:close()
	end
	self.sessions = {}

	-- socket
	if (self.serverSocket) then
		self.serverSocket:close()
		self.serverSocket = nil

		self:emit('close')
	end
end

function RtspProxy:get(request)
	return console.dump(self)
end

function RtspProxy:getProxySession(pathname, create)
	if (not pathname) then
		return nil
	end

	local proxySession = self.sessions[pathname]
	if ((not proxySession) and create) then
		proxySession = ProxySession:new()
		proxySession.pathname = pathname

		self.sessions[pathname] = proxySession

		proxySession:on('close', function()
			self.sessions[pathname] = nil
		end)

		self:emit('session', proxySession)
	end

	return proxySession
end

function RtspProxy:newMediaSession(pathname)
	local proxySession = self:getProxySession(pathname, false)
	if (proxySession) then
		return proxySession:newMediaSession()
	end
end

function RtspProxy:removeProxySession(proxySession)
	local pathname = nil
	if (type(proxySession) == 'string') then
		pathname = proxySession
		proxySession = self.sessions[pathname]
	else
		pathname = proxySession.pathname
	end

	if (proxySession) then
		proxySession:close()
	end

	if (pathname) then
		self.sessions[pathname] = nil
	end
end

function RtspProxy:start(port)
	local serverSocket = net.createServer(function(socket)
	  	local connection = RtspConnection:new(socket)

	  	self:emit('connection', connection)
	  	connection.rtspServer   = self
	  	connection.connectionId = self.connectionId

	  	print(TAG, "connection", self.connectionId)

	  	connection:on('close', function()
	  		print(TAG, "close", connection.connectionId)
	  		self.connections[connection.connectionId] = nil
	  	end)

	  	connection:on('announce', function(pathname)
			print(TAG, 'announce', pathname)

			local proxySession = self:getProxySession(pathname, true)
			if (proxySession) then
				connection.proxySession = proxySession
			end
		end)

	  	connection.onTSPacket = function(connection, meta, packet, offset)
			--local data = packet:sub(offset, offset + 16)
			--console.printBuffer(data)

			local proxySession = connection.proxySession
			if (proxySession) then
				proxySession:writeStream(meta, packet, offset)
			end
			--console.log('RtspProxy', path)
		end

	  	connection:start()

	  	self.connectionId = self.connectionId + 1
	  	self.connections[connection.connectionId] = connection
	end)

	--print("RtspProxy:start", "listen at " .. port)

	self.serverSocket = serverSocket
	serverSocket:listen(port or 554)
end

-------------------------------------------------------------------------------
--- exports

function exports.startServer(port, options)
	local rtspProxy = RtspProxy:new(options)
	rtspProxy:start(port)
	return rtspProxy
end

return exports

