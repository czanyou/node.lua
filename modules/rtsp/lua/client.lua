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
local util  = require('util')
local url 	= require('url')
local net 	= require('net')

local codec   = require('rtsp/codec')
local rtp 	  = require('rtsp/rtp')
local message = require('rtsp/message')
local sdp     = require('rtsp/sdp')

local exports 	= {}

local RTP_HEADER_SIZE   = 12

local NALU_TYPE_I   	= 5
local NALU_TYPE_SPS 	= 7
local NALU_TYPE_PPS 	= 8
local NALU_TYPE_P   	= 1
local NALU_TYPE_INFO 	= 6

exports.STATE_STOPPED	= 0
exports.STATE_INIT 		= 10	-- message sent: SETUP/TEARDOWN
exports.STATE_READY		= 20	-- message sent: PLAY/RECORD/TEARDOWN/SETUP
exports.STATE_PLAYING	= 30	-- message sent: PAUSE/TEARDOWN/PLAY/SETUP
exports.STATE_RECORDING	= 40

-------------------------------------------------------------------------------
--- MediaSample

---@class MediaSample
---@field public data string[] 数据内容
---@field public isFragment boolean 表示碎片标记
---@field public isSTAP boolean
---@field public isStart boolean 表示一帧开始标记
---@field public isEnd boolean 表示一帧结束标记
---@field public isVideo boolean 表示视频帧标记
---@field public marker boolean 表示一帧结束标记
---@field public payload integer
---@field public sampleTime integer 采样时间
---@field public rtpTime integer
---@field public sequence integer


local MediaSample = {}

--[[
'v=0\r\no=- 1453271342214497 1 IN IP4 10.10.42.66\r\ns=MPEG Transport Stream, streamed by the LIVE555 Media Server\r\ni=hd.ts\r\nt=0 0\r\na=tool:LIVE555 Streaming Media v2015.07.31\r\na=type:broadcast\r\na=control:*\r\na=range:npt=0-\r\na=x-qt-text-nam:MPEG Transport Stream, streamed by the LIVE555 Media Server\r\na=x-qt-text-inf:hd.ts\r\nm=video 0 RTP/AVP 33\r\nc=IN IP4 0.0.0.0\r\nb=AS:5000\r\na=control:track1\r\n'
]]

local function cloneSample(sample, data)
	local newSample = {}
	for k, v in pairs(sample) do
		newSample[k] = v
	end

	newSample.data = { data }
	newSample.marker = nil

	return newSample
end

-------------------------------------------------------------------------------
--- RtspClient

---@class RtspClient
local RtspClient = core.Emitter:extend()
exports.RtspClient = RtspClient

function RtspClient:initialize()
	self.isMpegTSMode 		= false	-- 是否为 TS 流传输模式
	self.lastCSeq 			= 1		-- 最后的 CSeq 值，每发送一个请求消息后加 1
	self.mediaTracks		= nil	-- 相关的媒体信息
	self.numberOfAuthFailed	= 0		-- 已连续认证失败次数，防止反复认证
	self.rtpSession 		= nil   -- 相关的 RTP 会话
	self.rtspCodec 			= nil  	-- 相关的 RTSP 消息编解码器
	self.rtspSocket			= nil	-- 相关的 Socket 对象
	self.rtspState			= exports.STATE_STOPPED 	-- 当前 RTSP 状态
	self.sentRequests   	= {}	-- 已经发送过的请求消息
	self.urlObject			= nil	-- 相关的 URL 对象
	self.urlString 			= nil	-- 相关的 URL 地址

	self.audioSamples 		= 0
	self.audioTrack			= nil
	self.audioTrackId		= nil
	self.videoSamples 		= 0
	self.videoTrack			= nil
	self.videoTrackId		= nil

	self.lastConnectTime	= nil
	self.id = (exports.INSTANCE_ID_COUNTER or 0) + 1
	exports.INSTANCE_ID_COUNTER = self.id

	self:initMessageCodec()
end

function RtspClient:closeConnectTimer()
	if (self.connectTimer) then
		local timer = self.connectTimer
		self.connectTimer = nil
		clearTimeout(timer)
	end
end

function RtspClient:close(error)
	if (self.rtspSocket) then
		self.rtspSocket:destroy()
		self.rtspSocket = nil

		self:setRtspState(exports.STATE_STOPPED)
		self:emit('close')
	end

	self.isMpegTSMode 		= false
	self.lastConnectTime	= nil
	self.lastHeartBeatTime  = 0
	self.lastCSeq 			= 1
	self.mediaTracks		= nil
	self.numberOfAuthFailed	= 0
	self.rtpSession 		= nil
	self.rtspCodec 			= nil
	self.rtspSocket			= nil
	self.rtspState			= exports.STATE_STOPPED
	self.sentRequests   	= {}
	self.urlObject			= nil
	self.urlString 			= nil

	self.audioSamples 		= 0
	self.audioTrack			= nil
	self.audioTrackId		= nil
	self.videoSamples 		= 0
	self.videoTrack			= nil
	self.videoTrackId		= nil

	self.lastPPS			= nil
	self.lastSPS			= nil

	if (error) then
		self:emit('error', error)
	end

	self:closeConnectTimer()
end

---@param response RtspMessage
---@return RtspMessage request
function RtspClient:getRequest(response)
	local headers = response and response.headers
	local cseq = tostring((headers and headers['CSeq']) or 0)
	local request = self.sentRequests[cseq]
	if (not request) then
		console.log('RtspClient:getRequest', "request not found: ", cseq)
		return
	end

	self.sentRequests[cseq] = nil
	return request
end

---@return integer width
---@return integer height
function RtspClient:getVideoSize()
	if (not self.videoTrack) then
		return nil, nil, 'video track is empty'
	end

	local function tointeger(value)
		if (not value) then
			return value
		end

		value = string.trim(value)
		return value and tonumber(value)
	end

	local attributes = self.videoTrack.attributes or {}
	local dimensions = attributes['x-dimensions']
	if (not dimensions) then
		return nil, nil, 'x-dimensions is empty'
	end

	local tokens = dimensions:split(',')
	return tointeger(tokens[1]), tointeger(tokens[2])
end

-- 从 SDP 中提取 H.264 的 SPS 和 PPS 数据集
---@return string sps
---@return string pps
---@return string error
function RtspClient:getParameterSets()
	if (not self.sdpSession) then
		return nil, 'invalid sdp session'
	end

	local session = self.sdpSession
	local video = session:getMedia('video')
	if (not video) then
		return nil, 'video track is empty'
	end

	local fmtp = video:getFmtp()
	if (not fmtp) then
		return nil, 'fmtp is empty'
	end

	local value = fmtp['sprop-parameter-sets']
	if (not value) then
		return nil, 'sprop-parameter-sets is empty'
	end

	local tokens = value:split(',')

	local sps = util.base64Decode(tokens[1])
	local pps = util.base64Decode(tokens[2])
	return { sps = sps, pps = pps }
end

---@param newState integer
function RtspClient:getRtspStateString(newState)
	if (newState == exports.STATE_STOPPED) then
		return 'stopped'

	elseif (newState == exports.STATE_INIT) then
		return 'init'

	elseif (newState == exports.STATE_READY) then
		return 'ready'

	elseif (newState == exports.STATE_PLAYING) then
		return 'playing'

	elseif (newState == exports.STATE_RECORDING) then
		return 'recording'

	else
		return 'state-' .. newState
	end
end

function RtspClient:getStatus()
    local status = {}

    status.lastActiveTime = self.lastActiveTime
    status.rtspState = self.rtspState
    status.sentRequests = self.sentRequests
    status.lastCSeq = self.lastCSeq
    status.lastConnectTime = self.lastConnectTime
    status.id = self.id

    -- audio
    local audio = {}
    status.audio = audio
    audio.samples = self.audioSamples
    -- audio.track = self.audioTrack
    audio.trackId = self.audioTrackId

    -- video
    local video = {}
    status.video = video
    video.samples = self.videoSamples
    -- video.track = self.videoTrack
    video.trackId = self.videoTrackId

    local sets, error = self:getParameterSets()
    if (sets and sets.sps) then
        video.sps = util.hexEncode(sets.sps)
        video.pps = util.hexEncode(sets.pps)
    else
        video.sps = error
    end

    return status
end

function RtspClient:initMessageCodec()
	local rtspCodec = codec.newCodec()
	self.rtspCodec = rtspCodec

	rtspCodec:on('request', function(request)
		self:processRequest(request)
	end)

	rtspCodec:on('response', function(response)
		local request = self:getRequest(response)
		if (request) then
			self:processResponse(request, response)
		end
	end)

	rtspCodec:on('packet', function(packet)
		local START_CODE = 0x24
		local offset = 4 + 1

		local head, channel, size = string.unpack('>BBI2', packet)
		-- print('packet', head, channel, size)
		if (head ~= START_CODE) then
			return
		end

		if (channel == 0) or (channel == 2) then
			self:onRtpPacket(packet, offset)
		else
			self:onRtcpPacket(packet, offset)
		end
	end)
end

function RtspClient:onRtcpPacket(packet, offset)
	--print('rtcp packet', packet:byte(offset + 1), offset)
	--console.printBuffer(packet)
end

---@param packet string
---@param offset integer
function RtspClient:onRtpPacket(packet, offset)
	local rtpSession = self.rtpSession
	if (not rtpSession) then
		self.rtpSession = rtp.RtpSession:new()
		rtpSession = self.rtpSession
	end

	-- console.log('onRtpPacket', packet, offset);
	if (self.isMpegTSMode) then
		local rtpInfo = rtpSession:decodeHeader(packet, offset)
		self:onTSPacket(rtpInfo, packet, offset + RTP_HEADER_SIZE)
		return
	end

	local sample = rtpSession:decode(packet, offset)
	if (not sample) then
		return
	end

	if (sample.isSTAP) then
		-- 将组合包分解成多个独立的包
		local list = sample.data
		sample.data = nil

		local count = #list
		local index = 1

		for _, data in ipairs(list) do
			local newSample = cloneSample(sample, data)
			if (index == count) then
				newSample.marker = sample.marker
			end

			self:onSample(newSample)

			index = index + 1
		end

	else
		self:onSample(sample)
	end
end

---@param data string
function RtspClient:onRtspData(data)
	if (not self.rtspCodec) then
		self:initMessageCodec()
	end

	self.rtspCodec:decode(data)
end

function RtspClient:onAudioSample(sample)

end

---@param sample MediaSample
function RtspClient:onVideoSample(sample)
	sample.isVideo = true

	local buffer = sample.data[1]
	if (not buffer) then
		return
	end

	self.videoSamples = (self.videoSamples or 0) + 1

	-- H.264 video streaming
	if (not sample.isFragment) or (sample.isStart) then
		local naluType = buffer:byte(1) & 0x1f
		--print('onSample.naluType', naluType)
		--console.printBuffer(buffer)

		if (naluType == NALU_TYPE_I) then
			if (not self.lastSPS) then
				local sets = self:getParameterSets()
				if (sets and sets.sps) then
					self:emit('sample', cloneSample(sample, sets.sps))
					self:emit('sample', cloneSample(sample, sets.pps))
				end
			end

			self.lastSPS = nil
			self.lastPPS = nil

		elseif (naluType == NALU_TYPE_SPS) then
			self.lastSPS = buffer

		elseif (naluType == NALU_TYPE_PPS) then
			self.lastPPS = buffer
		end
	end

	-- console.log('onVideoSample', sample)
	self:emit('sample', sample)
end

---@param sample MediaSample
function RtspClient:onSample(sample)
	if (not self.videoTrackId) then
		if (self.videoTrack) then
			self.videoTrackId = self.videoTrack.payload or 0
		end
	end

	-- HeartBeat
	local now = Date.now()
	local span = now - (self.lastHeartBeatTime or 0)
	if (span > 1000 * 60) then
		self.lastHeartBeatTime = now
		self:sendGET_PARAMETER()
	end

	if (sample.payload == self.videoTrackId) then
		self:onVideoSample(sample)

	elseif (sample.payload == self.audioTrackId) then
		self:onAudioSample(sample)

	else
		self:emit('sample', sample)
	end
end

function RtspClient:onTSPacket(rtpInfo, packet, offset)
	self:emit('ts', rtpInfo, packet, offset)
end

---@param urlString string
function RtspClient:open(urlString)
	if (self.rtspSocket) then
		self:close()
	end

	self.urlString = urlString
	self.urlObject = url.parse(urlString)

	if (not urlString) then
		return self:close('Empty rtsp url string')

	elseif (not urlString) then
		return self:close('Invalid rtsp url string')
	end

	local options = {}
	options.protocol = self.urlObject.protocol or 'rtsp'
    options.hostname = self.urlObject.hostname
    options.port     = self.urlObject.port     or 554

	if (not options.hostname) then
		return self:close('Empty rtsp url string')
	end

	local callback = function (err)
		self:setRtspState(exports.STATE_STOPPED)
    	local rtspSocket = self.rtspSocket

    	self:emit('connect')

    	rtspSocket:on('data', function(chunk)
			if (not chunk) then
		    	-- If data is set the client has sent data, if unset the client has disconnected
		      	print("RtspPusher: empty data")
		      	self:close()
		      	return
		    end
			self:onRtspData(chunk)
		end)

		rtspSocket:on('drain', function(err)

		end)

    	self:sendOPTIONS()
    end

    --console.log('connect', options)

    local rtspSocket = net.connect(options.port, options.hostname, callback)
    if (rtspSocket == nil) then
        self:emit('error', 'Couldn`t open RTSP connection')
        return nil
    end

	rtspSocket:on('end', function()
		console.log('connect', 'end')
	    self:close()
	end)

	rtspSocket:on('close', function(err)
	    self:close()
	end)

	rtspSocket:on('error', function(err)
      	self:close(err)
	end)

	self.rtspSocket 	 = rtspSocket;

	local timeout = 1000 * 5
	local onTimeout = function()
		self:close('timeout')
	end

	self.lastConnectTime = process.now()
	self.connectTimer = setTimeout(timeout, onTimeout)
end

function RtspClient:pause()
	self:sendPAUSE()
end

function RtspClient:play()
	self:sendPLAY()
end

---@param request RtspMessage
function RtspClient:processRequest(request)
	self:emit('request', request)
end

---@param request RtspMessage
---@param response RtspMessage
function RtspClient:processResponse(request, response)
	-- console.log('response', response)
	self:emit('response', request, response)

	local statusCode = response.statusCode or 0
	-- console.log('processResponse', statusCode, response.statusMessage)

	if (statusCode == 401) then
		return self:processAuthenticate(request, response)
	end

	self.numberOfAuthFailed = 0

	local method = request.method
	if (method == 'DESCRIBE') then
		return self:processDESCRIBE(request, response)

	elseif (method == 'SETUP') then
		return self:processSETUP(request, response)

	elseif (method == 'PLAY') then
		return self:processPLAY(request, response)

	elseif (method == 'PAUSE') then
		return self:processPAUSE(request, response)

	elseif (method == 'TEARDOWN') then
		return self:processTEARDOWN(request, response)

	elseif (method == 'OPTIONS') then
		return self:processOPTIONS(request, response)
	end
end

function RtspClient:processAuthenticate(request, response)
	local auth = response:getHeader('WWW-Authenticate')

	self.authInfo = message.parseAuthenticate(auth)
	-- console.log('Authenticate', self.authInfo)

	self.numberOfAuthFailed = self.numberOfAuthFailed + 1
	if (self.numberOfAuthFailed > 2) then
		return
	end

	if (self.rtspState == exports.STATE_STOPPED) or (self.rtspState == exports.STATE_INIT) then
		self:sendDESCRIBE()
	end
end

function RtspClient:processDESCRIBE(request, response)
	local statusCode = response.statusCode or 0
	--console.log('response', response)

	if (statusCode >= 400) then
		self:close(response.statusMessage)
		return
	end

	if (self.rtspState ~= exports.STATE_INIT) then
		return
	end

	local sdpString = response.content
	self.sdpSession = sdp.decode(sdpString)
	self.sdpString = sdpString

	self.mediaTracks = {}
	self.videoTrack = nil
	self.audioTrack = nil

	local medias = self.sdpSession.medias or {}
	for i = 1, #medias do
		local media = medias[i]
		local attributes = media.attributes or {}

		local track = {}
		for k, v in pairs(media) do
			track[k] = v
		end
		track.control   = attributes.control or "1"
		track.framerate = media:getFramerate()
		track.framesize = media:getFramesize()

		table.insert(self.mediaTracks, track)

		local RTP_PAYLOAD_TS = 33
		if (track.payload == RTP_PAYLOAD_TS) then
			self.isMpegTSMode = true
		end

		track.rtpmap = media:getRtpmap()
		track.fmtp = media:getFmtp()

		if (track.type == 'video') then
			self.videoTrack = track
			self.videoTrackId = track.payload

		elseif (track.type == 'audio') then
			self.audioTrack = track
			self.audioTrackId = track.payload
		end
	end

	self:emit('describe', sdpString)
	self:sendSETUP()
end

function RtspClient:processOPTIONS(request, response)
	if (self.rtspState == exports.STATE_STOPPED) then
		self:sendDESCRIBE()
	end
end

function RtspClient:processPAUSE(request, response)
	local statusCode = response.statusCode or 0
	if (statusCode >= 400) then
		return
	end

	self:setRtspState(exports.STATE_READY)
end

function RtspClient:processPLAY(request, response)
	local statusCode = response.statusCode or 0
	if (statusCode >= 400) then
		self:close(response.statusMessage)
		return
	end

	self:setRtspState(exports.STATE_PLAYING)
end

function RtspClient:processSETUP(request, response)
	local statusCode = response.statusCode or 0
	if (statusCode >= 400) then
		self:close(response.statusMessage)
		return
	end

	self.sessionId = response:getHeader("Session")
	if (self.sessionId) then
		local ret = self.sessionId:find(";")
		if (ret and ret > 1) then
			 self.sessionId =  self.sessionId:sub(1, ret - 1)
		end
	end

	self:setRtspState(exports.STATE_READY)

	--
	local setupTrackIndex = self.setupTrackIndex or 1
	local mediaTracks = self.mediaTracks or {}
	if (setupTrackIndex > #mediaTracks) then
		self:sendPLAY()
	else
		self:sendSETUP()
	end
end

function RtspClient:processTEARDOWN(request, response)
	local statusCode = response.statusCode or 0
	if (statusCode >= 400) then
		return
	end

	self:setRtspState(exports.STATE_INIT)
end

function RtspClient:sendDESCRIBE()
	self:setRtspState(exports.STATE_INIT)

	local request = message.newRequest('DESCRIBE', self.urlString)

	return self:sendRequest(request)
end

function RtspClient:sendGET_PARAMETER()
	local request = message.newRequest('GET_PARAMETER', self.urlString)
	return self:sendRequest(request)
end

function RtspClient:sendOPTIONS()
	local methods = 'OPTIONS, DESCRIBE, SETUP, TEARDOWN, PLAY, PAUSE, GET_PARAMETER, SET_PARAMETER'

	local request = message.newRequest('OPTIONS', self.urlString)
	request:setHeader('Public', methods)
	return self:sendRequest(request)
end

function RtspClient:sendPAUSE()
	if (self.rtspState ~= exports.STATE_PLAYING) then
		return
	end

	local file = self.urlString or "/"
	local request = message.newRequest('PAUSE', file)
	return self:sendRequest(request)
end

function RtspClient:sendPLAY(scale)
	local state = self.rtspState
	if (state ~= exports.STATE_READY) and (state ~= exports.STATE_PLAYING) then
		return 0, 'Invalid State: ' .. state
	end

	local file = self.urlString or "/"
	local request = message.newRequest('PLAY', file)
	if (scale) then
		request:setHeader('Scale', tostring(scale))
	end

	-- console.log('sendPLAY', request, scale)
	return self:sendRequest(request)
end

function RtspClient:sendSETUP()
	if (self.rtspState == exports.STATE_STOPPED) then
		return 0, 'Invalid State: ' .. self.rtspState

	elseif (self.mediaTracks == nil) or (#self.mediaTracks < 1) then
		self:close('Invalid media tracks')
	end

	local setupTrackIndex = self.setupTrackIndex or 1
	local track = self.mediaTracks[setupTrackIndex]
	if (not track) then
		self:close('Invalid media track')
		return
	end

	self.setupTrackIndex = setupTrackIndex + 1
	-- console.log('setupTrackIndex', setupTrackIndex)

	local interleaved = (self.setupTrackIndex - 1) * 2
	local control = track.control or ("track" .. self.setupTrackIndex)

	local file = self.urlString or "/"
	file = file .. "/" .. control
	local request = message.newRequest('SETUP', file)
	interleaved = interleaved .. '-' .. (interleaved + 1)
	request:setHeader('Transport', "RTP/AVP/TCP;unicast;interleaved=" .. interleaved)
	return self:sendRequest(request)
end

function RtspClient:sendTEARDOWN()
	if (self.rtspState == exports.STATE_STOPPED) then
		return
	end

	local file = self.urlString or "/"
	local request = message.newRequest('TEARDOWN', file)
	return self:sendRequest(request)
end

function RtspClient:sendRequest(request)
	if not request then return end

	request:setHeader('Client', 'Node.lua RTSP Client 2.0')

	if (self.sessionId) then
		request:setHeader('Session', self.sessionId)
	end

	if (self.authInfo and self.username) then
		request:setAuthorization(self.authInfo, self.username, self.password)
	end

	-- console.log('Authenticate', request:getHeader('Authorization'), self.username, self.password)

	local CSeq = self.lastCSeq or 1
	request:setHeader('CSeq', CSeq)
	self.lastCSeq = CSeq + 1
	self.sentRequests[tostring(CSeq)] = request

	if (not self.rtspCodec) then
		self:initMessageCodec()
	end

	local data = self.rtspCodec:encode(request)
	if (self.rtspSocket) then
		self.rtspSocket:write(data)
	end

	--console.log('rtsp:request', data)
	--console.log('request', request)
	--print('request: ' .. request.method)

	return 0
end

-- 设置当前客户端的状态
function RtspClient:setRtspState(newState)
	if (self.rtspState ~= newState) then
		self.rtspState = newState
		self:emit('state', newState)

		if (newState == exports.STATE_PLAYING) then
			self:closeConnectTimer()
		end
	end
end

-------------------------------------------------------------------------------
-- exports

--[[
打开指定的 RTSP URL 地址，并返回相关的 RTSP 客户端对象
@param url RTSP URL 地址, 比如 'rtsp://test.com:554/live.mp4'
]]
function exports.openURL(url)
	local rtspClient = RtspClient:new()
	rtspClient:open(url)
	return rtspClient
end

return exports
