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
local core 	= require('core')
local url 	= require('url')

local codec 	= require('rtsp/codec')
local rtp 		= require('rtsp/rtp')
local rtsp 		= require('rtsp/message')
local sdp 		= require('rtsp/sdp')

local TAG = 'RtspConnection'

local exports 	= {}

exports.STATE_STOPPED	= 0
exports.STATE_INIT 		= 10	-- message sent: SETUP/TEARDOWN
exports.STATE_READY		= 20	-- message sent: PLAY/RECORD/TEARDOWN/SETUP
exports.STATE_PLAYING	= 30	-- message sent: PAUSE/TEARDOWN/PLAY/SETUP
exports.STATE_RECORDING	= 40

-------------------------------------------------------------------------------
--- RtspConnection

---@class RtspConnection
local RtspConnection = core.Emitter:extend()
exports.RtspConnection = RtspConnection

function RtspConnection:initialize(socket)
	self.connectionId   = nil
	self.contentBase 	= nil
	self.isMpegTSMode 	= false		-- 是否为 TS 传输模式
	self.isStreaming 	= false
	self.lastRequest 	= nil
	self.lastResponse 	= nil
	self.mediaCount		= 1
	self.mediaSession 	= nil
	self.mediaTracks    = nil
	self.rtspCodec 		= nil
	self.rtspServer		= nil
	self.rtspState		= 0
	self.sdpSession     = nil
	self.sdpString		= nil
	self.sendLength		= 0
	self.sessionId 		= nil
	self.socket 		= socket;
	self.urlObject		= nil		-- 相关的 URL 对象
	self.urlString 		= nil		-- 相关的 URL 地址

	self._getMediaSession	= nil
end

function RtspConnection:close(errInfo)
	self:stopStreaming()

	if (self.socket) then
		self.socket:destroy()
		self.socket = nil

		self:setState(exports.STATE_STOPPED)
		self:emit('close', errInfo)
	end

	if (self.mediaSession) then
		self.mediaSession:close()
		self.mediaSession = nil
	end

	self.connectionId   = nil
	self.contentBase 	= nil
	self.isMpegTSMode 	= false
	self.isStreaming 	= false
	self.lastRequest 	= nil
	self.lastResponse 	= nil
	self.mediaCount		= 1
	self.mediaSession 	= nil
	self.mediaTracks    = nil
	self.rtspCodec 		= nil
	self.rtspServer		= nil
	self.sdpSession     = nil
	self.sdpString		= nil
	self.sendLength		= 0
	self.sessionId 		= nil
	self.urlObject		= nil
	self.urlString 		= nil

	self._getMediaSession	= nil
end

-- 检查客户端身份认证信息
-- 返回 true 表示不需要认证或通过身份认证，否则表示客户端没有提供正确的身份认证信息
function RtspConnection:_checkAuthorization(request, response)
	if (self.authCallback) then
		return response:checkAuthorization(request, self.authCallback)
	end

	return true
end

-- 返回 RTSP 服务器指定的路径的媒体流的 SDP 描述信息，如果不存在则返回 nil
function RtspConnection:getSdpString(urlString)
	if not urlString then return end
	local urlObject = url.parse(urlString)

	self.urlString = urlString
	self.urlObject = urlObject

	if (not self._getMediaSession) then
		return nil
	end

	local mediaSession = self:_getMediaSession(urlObject.pathname, urlObject.query)
	if (not mediaSession) then
		return nil
	end

	self.mediaSession = mediaSession;
	return mediaSession:getSdpString()
end

function RtspConnection:_initRtspCodec()
	self.rtspCodec = codec.newCodec()

	self.rtspCodec:on('request', function(request)
		self:processRequest(request)
	end)

	self.rtspCodec:on('response', function(response)
		self:processResponse(response)
	end)

	self.rtspCodec:on('packet', function(packet)
		self:processRtspPacket(packet)
	end)
end

function RtspConnection:_parseSdpString(sdpString)
	local sdpSession = sdp.decode(sdpString)

	--pprint(sdpString)
	--pprint(sdpSession)

	if (sdpSession == nil) then
		return
	end

	self.sdpString  = sdpString
	self.sdpSession = sdpSession

	self.mediaTracks = {}
	local medias = sdpSession.medias or {}
	for i = 1, #medias do
		local media = medias[i]
		local attributes = media.attributes or {}

		local track = {}
		track.type 		= media.type
		track.payload 	= media.payload
		track.control   = attributes.control or "1"
		table.insert(self.mediaTracks, track)

		local RTP_PAYLOAD_TS = 33
		if (track.payload == RTP_PAYLOAD_TS) then
			self.isMpegTSMode = true
		end
	end
end

function RtspConnection:processANNOUNCE(request)
	local response = rtsp.newResponse()

	self.urlString = request.path
	self.urlObject = url.parse(self.urlString)

	self:setState(exports.STATE_INIT)

	if (self.rtspState == exports.STATE_INIT) then
		self:_parseSdpString(request.content)

		if (self.mediaTracks == nil) then
			response:setStatusCode(400)

		elseif (self.urlObject == nil) then
			response:setStatusCode(400)

		else
			local pathname = self.urlObject.pathname
			self:emit('announce', pathname, self.mediaTracks)
		end
		--print('sdpString: ' .. sdpString)
		--pprint(self.mediaTracks)
	end

	self:sendResponse(response)
end

function RtspConnection:processOPTIONS(request)
	local response = rtsp.newResponse()

	local methods = table.concat(rtsp.METHODS, ", ");
	response:setHeader('Public', methods)

	self:sendResponse(response)
end

function RtspConnection:processDESCRIBE(request)
	local response = rtsp.newResponse()

	if (not self:_checkAuthorization(request, response)) then
		self:sendResponse(response)
		return
	end

	response:setHeader('Date', rtsp.newDateHeader())

	local sdpString = self:getSdpString(request.path)
	if (sdpString) then
		self:_parseSdpString(sdpString)

		response:setHeader('Content-Type', 'application/sdp')
		response.content = sdpString
		self:sendResponse(response)

		self:setState(exports.STATE_INIT)

	else
		response:setStatusCode(404)
		self:sendResponse(response)
	end
end

function RtspConnection:processGET(request)
	local response = rtsp.newResponse()

	response:setStatusCode(200)

	local content = nil
	if (self.rtspServer and self.rtspServer.get) then
		content = self.rtspServer:get(request)
	end

	if (not content) then
		content = "Empty Content"
	end

	response.scheme = "HTTP"
	response:setHeader('Connection', 'close')
	response:setHeader('Content-Length', #content)
	response:setHeader('Content-Type', 'text/html')
	response.content = content

	self:sendResponse(response)
end

function RtspConnection:processGET_PARAMETER(request)
	local response = rtsp.newResponse()
	self:sendResponse(response)
end

function RtspConnection:processPAUSE(request)
	local response = rtsp.newResponse()

	local state = self.rtspState
	if (state == exports.STATE_PLAYING) or (state == exports.STATE_RECORDING) then
		self:stopStreaming()
		self:setState(exports.STATE_READY)

	else
		response:setStatusCode(455)
	end

	self:sendResponse(response)
end

function RtspConnection:processPLAY(request)
	local response = rtsp.newResponse()

	if (not self.mediaTracks) then
		response:setStatusCode(404)
		self:sendResponse(response)
		return
	end

	local rtpInfo = 'seq=0;rtptime=0'
	response:setHeader('RTP-Info', rtpInfo)

	local state = self.rtspState
	if (state == exports.STATE_READY) then
		self:setState(exports.STATE_PLAYING)
		self:startStreaming()

	elseif (state == exports.STATE_PLAYING) then

	else
		response:setStatusCode(455)
	end

	self:sendResponse(response)
end

function RtspConnection:processRECORD(request)
	local response = rtsp.newResponse()

	local state = self.rtspState
	if (state == exports.STATE_READY) then
		self:setState(exports.STATE_RECORDING)

		local pathname = self.urlObject.pathname
		self:emit('record', pathname, self.mediaTracks)

	elseif (state == exports.STATE_RECORDING) then

	else
		response:setStatusCode(455)
	end

	self:sendResponse(response)
end

function RtspConnection:processREDIRECT(request)
	local response = rtsp.newResponse()
	self:sendResponse(response)

end

function RtspConnection:processSETUP(request)
	local response = rtsp.newResponse()
	if (not self.mediaTracks) then
		response:setStatusCode(404)
		self:sendResponse(response)
		return
	end

	if (not self:_checkAuthorization(request, response)) then
		self:sendResponse(response)
		return
	end

	local sessionId = request:getHeader('Session')
	local transport = request:getHeader('Transport')

	if (not self.sessionId) then
		self.sessionId = process.now()
	end

	if (transport and transport:startsWith("RTP/AVP/TCP")) then
		response:setHeader('Transport', transport)
		response:setHeader('Date', rtsp.newDateHeader())
		self:setState(exports.STATE_READY)

	else
		response:setStatusCode(461)
		response:setHeader('Date', rtsp.newDateHeader())
	end

	self:sendResponse(response)
end

function RtspConnection:processSET_PARAMETER(request)
	local response = rtsp.newResponse()
	self:sendResponse(response)
end

function RtspConnection:processTEARDOWN(request)
	local response = rtsp.newResponse()
	response:setHeader('Connection', 'close')
	self:sendResponse(response)

	local state = self.rtspState
	if (state > exports.STATE_INIT) then
		self:stopStreaming()
		self:setState(exports.STATE_INIT)
	end
end

function RtspConnection:processMessage(message)
	-- pprint('message', message.method, message.statusCode)
	if (message.statusCode) then
		self:processResponse(message)
	else
		self:processRequest(message)
	end
end

function RtspConnection:processRequest(request)
	--print('RtspConnection', 'request', request.method, request.path)
	self.lastRequest = request

	local method = request.method

	if (method == 'ANNOUNCE') then
		self:processANNOUNCE(request)

	elseif (method == 'DESCRIBE') then
		self:processDESCRIBE(request)

	elseif (method == 'GET') then
		self:processGET(request)

	elseif (method == 'GET_PARAMETER') then
		self:processGET_PARAMETER(request)

	elseif (method == 'OPTIONS') then
		self:processOPTIONS(request)

	elseif (method == 'PAUSE') then
		self:processPAUSE(request)

	elseif (method == 'PLAY') then
		self:processPLAY(request)

	elseif (method == 'RECORD') then
		self:processRECORD(request)

	elseif (method == 'REDIRECT') then
		self:processREDIRECT(request)

	elseif (method == 'SETUP') then
		self:processSETUP(request)

	elseif (method == 'SET_PARAMETER') then
		self:processSET_PARAMETER(request)

	elseif (method == 'TEARDOWN') then
		self:processTEARDOWN(request)

	else
		self:processNotImplementedRequest(request)
	end
end

function RtspConnection:processNotImplementedRequest(request)
	local response = rtsp.newResponse(501)

	self:sendResponse(response)
end

function RtspConnection:processResponse(response)
	console.log('response', response.statusCode, response.statusMessage)
end

function RtspConnection:processRtspPacket(packet)
	local head, channel, size = string.unpack('>BBI2', packet)
	if (head ~= 0x24) then
		return
	end

	if (channel == 0) then
		self:_processRtpPacket(packet, 5)
	end
end

function RtspConnection:processRawData(data)
	if (not self.rtspCodec) then
		self:_initRtspCodec()
	end
	self.rtspCodec:decode(data)
end

function RtspConnection:onTSPacket(meta, packet, offset)
	local data = packet:sub(offset, offset + 16)
	console.printBuffer(data)
end

function RtspConnection:_processSampleData(sample)
	--sample.data = nil
	--pprint(sample)

	self:emit('sample', sample)
end

function RtspConnection:_processRtpPacket(packet, offset)
	--console.printBuffer(packet)
	if (not self.rtpSession) then
		self.rtpSession = rtp.RtpSession:new()
	end

	if (self.isMpegTSMode) then
		local meta = self.rtpSession:decodeHeader(packet, offset)
		self:onTSPacket(meta, packet, offset + 12)

	 else
		--local data = packet:sub(1, 20)
		--console.printBuffer(data)
		local sample = self.rtpSession:decode(packet, offset)
		if (sample) then
			self:_processSampleData(sample)
		end
	end
end

function RtspConnection:sendRawData(data)
	if (not data) then
		return true

	elseif (not self.socket) then
		return true
	end

	local dataLength = #data
	self.sendLength = self.sendLength + dataLength

	return self.socket:write(data)
end

function RtspConnection:sendResponse(response)
	if not response then return end

	response:setHeader('Server', 'Node.lua RTSP Server 1.0')

	if (self.sessionId) then
		response:setHeader('Session', self.sessionId)
	end

	if (self.lastRequest) then
		response:setHeader('CSeq', self.lastRequest:getHeader('CSeq'))
	end

	self.lastResponse = response

	if (not self.rtspCodec) then
		self:_initRtspCodec()
	end
	local data = self.rtspCodec:encode(response)
	self:sendRawData(data)
	--pprint('response', data)
end

function RtspConnection:setState(newState)
	if (self.rtspState ~= newState) then
		self.rtspState = newState
		self:emit('state', newState)
	end
end

function RtspConnection:startStreaming()
	if (not self.mediaSession) then
		return

	elseif (self.isStreaming) then
		return
	end

	self.isStreaming = true

	print(TAG, 'startStreaming', self.urlString)
	self.mediaSession:readStart(function(rtpPacket)
		if (not self:sendRawData(rtpPacket)) then
			self.mediaSession:readStop()
		end
	end)
end

function RtspConnection:start()
	local socket = self.socket
	if (not socket) then
		print(TAG, "invalid socket")
	    self:close()
		return
	end

	socket:on('data', function(chunk)
		if (not chunk) then
	    -- If data is set the client has sent data, if unset the client has disconnected
	      	print(TAG, "empty data")
	      	self:close()
	      	return
	    end

		self:processRawData(chunk)
	end)

	socket:on('end', function()
		--print(TAG, "end")
	    self:close()
	end)

	socket:on('close', function()
		--print(TAG, "close")
	    self:close()
	end)

	socket:on('error', function(err)
		-- If error, print and close connection
		--print(TAG, "error", err)
      	self:close(err)
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

	return
end

function RtspConnection:stopStreaming()
	if (self.isStreaming) then
		self.isStreaming = false
		print(TAG, 'stopStreaming', self.urlString)
	end

	if (self.mediaSession) then
		self.mediaSession:readStop()
	end
end

return exports
