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
local url 	= require('url')
local utils = require('util')

local codec 	= require('rtsp/codec')
local rtp 		= require('rtsp/rtp')
local rtsp 		= require('rtsp/message')
local sdp   	= require('rtsp/sdp')
local session 	= require('media/session')

local TAG = "RtspPusher"

local meta 		= { }
local exports 	= { meta = meta }


exports.STATE_STOPPED	= 0
exports.STATE_INIT 		= 10	-- message sent: SETUP/TEARDOWN 
exports.STATE_READY		= 20	-- message sent: PLAY/RECORD/TEARDOWN/SETUP
exports.STATE_PLAYING	= 30	-- message sent: PAUSE/TEARDOWN/PLAY/SETUP
exports.STATE_RECORDING	= 40

-------------------------------------------------------------------------------
--- RtspPusher

--[[
   RtspPusher 主要使用 RTSP RECORD/ANNOUNCE 协议推送流, 主要流程如下:

   C -> M: ANNOUNCE with sdp description
   M -> C: 200 OK
   C -> M: SETUP with tansport
   M -> C: 200 OK
   C -> M: RECORD
   M -> C: 200 OK
   C -> M: RTP Streaming
   C -> M: TEARDOWN
   M -> C: 200 OK

Events:
- error
- close

]]
local RtspPusher = core.Emitter:extend()
exports.RtspPusher = RtspPusher

function RtspPusher:initialize()
	self.clientSocket		= nil
	self.isStreaming		= false
	self.lastConnectTime	= nil
	self.lastCSeq 			= 1
	self.mediaSession   	= nil
	self.rtspCodec 			= nil
	self.rtspState			= 0
	self.sentBytes			= 0
	self.sentRequests   	= {}
	self.sessionId			= nil
	self.urlObject			= nil
	self.urlString			= nil
end

function RtspPusher:close(errInfo)
	if (self.isStreaming) then
		self:_stopStreaming()
	end

	if (self.clientSocket) then
		self.clientSocket:destroy()
		self.clientSocket 	= nil

		self:_setState(exports.STATE_STOPPED)
		self:emit('close', errInfo)
	end

	self.clientSocket		= nil
	self.isStreaming		= false
	self.lastConnectTime	= nil
	self.lastCSeq 			= 1
	self.mediaSession   	= nil
	self.rtspCodec 			= nil
	self.rtspState			= 0
	self.sentBytes			= 0
	self.sentRequests   	= {}
	self.sessionId			= nil
	self.urlObject			= nil
	self.urlString 			= nil
end

function RtspPusher:_getRequest(response)
	local cseq = response.headers['CSeq'] or 0
	local request = self.sentRequests[tostring(cseq)]
	if (not request) then
		--console.log(TAG, '_getRequest', "request not found: ", cseq)
		return
	end
	return request
end

function RtspPusher:_getSdpString(urlString)
	if not urlString then 
		return nil
	end

	local mediaSession = self.mediaSession
	if (not mediaSession) then
		if (not self._getMediaSession) then
			return nil
		end

		local urlObject = url.parse(urlString) or {}
		mediaSession = self:_getMediaSession(urlObject.pathname, urlObject.query)
		if (not mediaSession) then
			return nil
		end
	end

	self.mediaSession = mediaSession;
	return mediaSession:getSdpString()
end

function RtspPusher:_initRtspDecoder()
	self.rtspCodec = codec.newCodec()

	self.rtspCodec:on('response', function(response)
		local request = self:_getRequest(response)
		if (request) then
			self:handleResponse(request, response)
		else
			self:emit('error', 'unknown response!', response)
		end
	end)

	self.rtspCodec:on('packet', function(packet)
		local head, channel, size = string.unpack('>BBI2', packet)
		--print(head, channel, size)
		if (head ~= 0x24) then
			return
		end

		if (channel == 0) then
			self:_processRtpPacket(packet, 5)
		end
	end)
end

function RtspPusher:handleResponse(request, response)
	local statusCode = response.statusCode or 0
	local method = request.method
	--print('RtspPusher', 'handleResponse', method, self.rtspState)

	if (method == 'ANNOUNCE') then
		if (statusCode >= 400) then
			self:emit('error', response.statusMessage)
			self:close()
			return
		end

		if (self.rtspState == exports.STATE_INIT) then	
			--local sdpString = response.content
			--self.sdpSession = sdp.decode(sdpString)

			--print('sdpString: ' .. sdpString)
			--console.log(self.sdpSession)

			self.sdpSession = {}

			self.sdpSession.medias = {}
			self.sdpSession.medias[1] = {}

			self:sendSETUP()
		end

	elseif (method == 'SETUP') then	
		if (statusCode >= 400) then
			self:emit('error', response.statusMessage)
			self:close()
			return
		end

		self.sessionId = response:getHeader("Session")
		if (self.sessionId) then
			local ret = self.sessionId:find(";")
			if (ret and ret > 1) then
				 self.sessionId =  self.sessionId:sub(1, ret - 1)
			end
		end

		self:_setState(exports.STATE_READY)

		if (self.rtspState == exports.STATE_READY) then	
			self:sendRECORD()
		end

	elseif (method == 'RECORD') then
		if (statusCode >= 400) then
			self:emit('error', response.statusMessage)
			self:close()
			return
		end

		if (self.rtspState == exports.STATE_READY) then
			self:_setState(exports.STATE_RECORDING)
			self:_startStreaming()
		end

	elseif (method == 'PAUSE') then
		if (statusCode >= 400) then
			return
		end

		self:_setState(exports.STATE_READY)	

	elseif (method == 'TEARDOWN') then
		if (statusCode >= 400) then
			return
		end

		self:_setState(exports.STATE_INIT)

	elseif (method == 'OPTIONS') then

	end

	if (self.rtspState == 0) then
		self:sendANNOUNCE()
	end
end

function RtspPusher:handleRawData(data)
	if (not self.rtspCodec) then
		self:_initRtspDecoder()
	end

	self.rtspCodec:decode(data)
end

function RtspPusher:open(urlString, mediaSession)
	self.urlString 	  = urlString
	self.urlObject 	  = url.parse(urlString)
	self.mediaSession = mediaSession

	local options = {}
	options.protocol = self.urlObject.protocol or 'rtsp'
    options.hostname = self.urlObject.hostname or '127.0.0.1'
    options.port     = self.urlObject.port     or 554

    local callback = function(err)
    	--print(TAG, 'open', 'callback', err)

    	self:emit("connect", self)
    	self:sendOPTIONS()
    end

    print(TAG, 'open', options.port, options.hostname)
    
     -- connect
    self.lastConnectTime = process.now()

    local socket = net.connect(options.port, options.hostname, callback)
    self.clientSocket = socket

    if (socket == nil) then
        self:emit('error', 'Couldn`t open RTSP connection')
        return nil
    end

	socket:on('end', function() 
		--print(TAG, "socket", "end")
	    self:close()
	end)

	socket:on('close', function() 
		--print(TAG, "socket", "close")
	    self:close()
	end)

	socket:on('error', function(err) 
		-- If error, print and close connection
		--print("RtspConnectin: read error: " .. err)

      	self:emit('error', err)
      	self:close(err)
	end)

    socket:on('data', function(chunk) 
		if (not chunk) then
	    	-- If data is set the socket has sent data,
	    	-- if unset the socket has disconnected
	      	self:close("empty data")
	      	return
	    end

	    --print(TAG, 'data', chunk)
		self:handleRawData(chunk)
	end)

	socket:on('drain', function(err) 
		if (not self.isStreaming) then
			return
		end

		if (self.mediaSession) then
			self.mediaSession:readStart(function(rtpPacket)
				if (not self:sendRawData(rtpPacket)) then
					self.mediaSession:readStop()
				end
			end)
		end
	end)
end

function RtspPusher:sendANNOUNCE()
	self:_setState(exports.STATE_INIT)

	local file = self.urlString or "/"
	local request = rtsp.newRequest('ANNOUNCE', file)

	local sdpString = self:_getSdpString(self.urlString)
	if (sdpString) then
		request:setHeader('Content-Type', 'application/sdp')
		request.content = sdpString

	else
		self:emit('error', 'Invalid SDP string.')
	end

	self:sendRequest(request)
end

function RtspPusher:sendOPTIONS()
	local methods = 'OPTIONS, ANNOUNCE, SETUP, TEARDOWN, RECORD, PAUSE, GET_PARAMETER, SET_PARAMETER'

	local request = rtsp.newRequest('OPTIONS', self.urlString)
	request:setHeader('Public', methods)
	self:sendRequest(request)
end

function RtspPusher:sendPAUSE()
	local file = self.urlString or "/"
	local request = rtsp.newRequest('PAUSE', file)
	self:sendRequest(request)

	if (self.isSteaming) then
		self:_stopStreaming()
	end
end

function RtspPusher:sendRECORD()
	local file = self.urlString or "/"
	local request = rtsp.newRequest('RECORD', file)
	self:sendRequest(request)
end

function RtspPusher:sendSETUP()
	if (not self.sdpSession) or (not self.sdpSession.medias) then 
		print(TAG, "sendSETUP", "Invalid sdp session!")
		self:close("Invalid sdp session!")
		return
	end

	local media = self.sdpSession.medias[1]
	if (not media) then
		print(TAG, "sendSETUP", "Invalid sdp media!")
		self:close("Invalid sdp media!")
		return
	end

	local attributes = media.attributes or {}
	local control = attributes.control or "track-1"

	local file = self.urlString or "/"
	if (not file:endsWith("/")) then
		file = file .. "/"
	end
	file = file .. control
	local request = rtsp.newRequest('SETUP', file)
	request:setHeader('Transport', "RTP/AVP/TCP;unicast;interleaved=0-1")
	self:sendRequest(request)
end

function RtspPusher:sendTEARDOWN()
	local file = self.urlString or "/"
	local request = rtsp.newRequest('TEARDOWN', file)
	self:sendRequest(request)

	if (self.isSteaming) then
		self:_stopStreaming()
	end
end

function RtspPusher:sendRawData(data)
	if (not data) then
		return false

	elseif (not self.clientSocket) then
		return false
	end

	local dataLength = #data
	self.sentBytes = self.sentBytes + dataLength

	return self.clientSocket:write(data)
end

function RtspPusher:sendRequest(request)
	if not request then return end

	request:setHeader('Client', 'Node RTSP Server 1.0')

	if (self.sessionId) then
		request:setHeader('Session', self.sessionId)
	end

	local CSeq = self.lastCSeq or 1
	request:setHeader('CSeq', CSeq)
	self.lastCSeq = CSeq + 1
	self.sentRequests[tostring(CSeq)] = request

	print(TAG, 'sendRequest', request.method)

	if (not self.rtspCodec) then
		self:_initRtspDecoder()
	end

	local data = self.rtspCodec:encode(request)
	--print(TAG, 'sendRequest', data)
	self:sendRawData(data)
end

function RtspPusher:_setState(newState)
	if (self.rtspState == newState) then
		return
	end

	self.rtspState = newState
	self:emit('state', newState)

	if (newState == exports.STATE_RECORDING) then
		self:_startStreaming()

	else
		self:_stopStreaming()
	end
end

function RtspPusher:_startStreaming()
	if (self.isStreaming) then
		return

	elseif (not self.mediaSession) then
		return
	end

	self.isStreaming = true

	self.mediaSession:readStart(function(rtpPacket)
		if (not self:sendRawData(rtpPacket)) then
			self.mediaSession:readStop()
		end
	end)
end

function RtspPusher:_stopStreaming()
	if (self.isStreaming) then
		self.isStreaming = false
	end

	if (self.mediaSession) then
		self.mediaSession:readStop()
	end
end

-------------------------------------------------------------------------------
-- exports

function exports.openURL(url, mediaSession)
	local rtspPusher = RtspPusher:new()
	rtspPusher:open(url, mediaSession)
	return rtspPusher
end

return exports
