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
local core 			= require('core')
local utils 		= require('util')
local net 			= require('net')
local rtp 			= require('rtsp/rtp')

local rconnection 	= require('rtsp/connection')

local RtspConnection = rconnection.RtspConnection

local meta 		= { }
local exports 	= { meta = meta }


local function onSendSample(self, sample)
	if (not sample) then
		return
	end

	self:onSendRtpPackets(sample)
end

local function onSendRtpPackets(self, sample)
	local count = #sample
	if (count <= 0) then
		return
	end

	local sampleTime = math.floor(sample.sampleTime / 1000)
	--print('onSendSample', count, sampleTime)

	local MAX_TS_PACKET_PER_RTP_PACKET 	= 7  -- (188 * 7 = 1316) < 1500

	local list = {'', ''}
	local rtpSession = self._rtpSession
	if (not rtpSession) then
		rtpSession 			= rtp.RtpSession:new()
		rtpSession.payload 	= self.payload

		self._rtpSession 	= rtpSession
	end

	local channel = 0
	local START_BYTE = 0x24

	for i = 1, count do
		local buffer = sample[i]

		table.insert(list, buffer)

		local isMarker = (i == count)

		if isMarker or (#list > MAX_TS_PACKET_PER_RTP_PACKET) then
			-- RTP header
			list[2] = rtpSession:encodeHeader(sampleTime, isMarker)

			-- RTP over RTSP header
			local packetSize = 0
			for i = 2, #list do
				packetSize = packetSize + #list[i]
			end
			list[1] = string.pack('>BBI2', START_BYTE, channel, packetSize)

			-- send packet
			self:onSendPacket(table.concat(list))

			list = {'', ''}
		end
	end
end

-------------------------------------------------------------------------------
--- RtspServer

local RtspServer = core.Emitter:extend()
exports.RtspServer = RtspServer

function RtspServer:initialize()
	self.connections  		= {}
	self.connectionId 		= 1
	self.serverSocket 		= nil
	self._getMediaSession	= nil
	self.authCallback       = nil
end

function RtspServer:close(errInfo)
	-- close all connections
	for k, connection in pairs(self.connections) do
		connection:close()
	end
	self.connections = {}

	-- close socket
	if (self.serverSocket) then
		self.serverSocket:close()
		self.serverSocket = nil

		self:emit('close', errInfo)
	end
end

function RtspServer:get(request)
	return console.dump(self)
end

function RtspServer:removeConnection(connection)
	if (not connection) then
		return
	end

	self.connections[connection.connectionId] = nil
end

function RtspServer:start(port, callback)
	if (callback) then
		self._getMediaSession = callback
	end

	local getMediaSession = function(connection, pathname)
		if (self._getMediaSession) then
			local mediaSession = self._getMediaSession(connection, pathname)
			mediaSession.onSendRtpPackets = onSendRtpPackets
			mediaSession.onSendSample = onSendSample
			return mediaSession
		end

		print(TAG, 'start', '`_getMediaSession` method not found!')
		return nil
	end

	-- Create listener socket
	local serverSocket = net.createServer(function(socket)
	  	local connection = RtspConnection:new(socket)
	  	connection.rtspServer   	= self
	  	connection.connectionId 	= self.connectionId
	  	connection._getMediaSession = getMediaSession
	  	connection.authCallback     = self.authCallback

	  	self:emit('connection', connection)

	  	connection:on('close', function()
	  		self:removeConnection(connection)
	  	end)
	  	  	
	  	connection:start()

	  	self.connectionId = self.connectionId + 1
	  	self.connections[connection.connectionId] = connection
	end)

	serverSocket:on('error', function(err)
		console.log('RTSP', 'error', err)
		self:emit('error', err)
	end)

	serverSocket:on('close', function(err)
		self:emit('close', err)
	end)

	serverSocket:listen(port or 554)
	self.serverSocket = serverSocket
end

-------------------------------------------------------------------------------
--- exports

function exports.startServer(port, callback)
	local server = RtspServer:new()
	server:start(port, callback)
	return server
end

setmetatable(exports, {
	__call = function(self, ...) 
		return self.startServer(...)
	end
})

return exports
