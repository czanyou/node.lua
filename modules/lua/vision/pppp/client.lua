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
local buffer = require('buffer')
local core   = require('core')
local fs   	 = require('fs')
local json 	 = require('json')
local pppp 	 = require('pppp')
local timer  = require('timer')
local utils  = require('utils')

local hls    = require('hls/reader')

local StreamReader = hls.StreamReader
local StreamWriter = hls.StreamWriter
local Buffer = buffer.Buffer

-- version
local exports = { }
exports.VERSION = pppp.version()

-- P2P Data Channels
local P2P_CMDCHANNEL          	= 0
local P2P_VIDEOCHANNEL        	= 1
local P2P_AUDIOCHANNEL       	= 2
local P2P_TALKCHANNEL        	= 3
local P2P_PLAYBACK            	= 4

-- P2P Error Code
exports.ERROR_PPPP_SUCCESSFUL						= 0
exports.ERROR_PPPP_NOT_INITIALIZED					= -1
exports.ERROR_PPPP_ALREADY_INITIALIZED				= -2
exports.ERROR_PPPP_TIME_OUT							= -3
exports.ERROR_PPPP_INVALID_ID						= -4
exports.ERROR_PPPP_INVALID_PARAMETER				= -5
exports.ERROR_PPPP_DEVICE_NOT_ONLINE				= -6
exports.ERROR_PPPP_FAIL_TO_RESOLVE_NAME				= -7
exports.ERROR_PPPP_INVALID_PREFIX					= -8
exports.ERROR_PPPP_ID_OUT_OF_DATE					= -9
exports.ERROR_PPPP_NO_RELAY_SERVER_AVAILABLE		= -10
exports.ERROR_PPPP_INVALID_SESSION_HANDLE			= -11
exports.ERROR_PPPP_SESSION_CLOSED_REMOTE			= -12
exports.ERROR_PPPP_SESSION_CLOSED_TIMEOUT			= -13
exports.ERROR_PPPP_SESSION_CLOSED_CALLED			= -14
exports.ERROR_PPPP_REMOTE_SITE_BUFFER_FULL			= -15
exports.ERROR_PPPP_USER_LISTEN_BREAK				= -16
exports.ERROR_PPPP_MAX_SESSION						= -17
exports.ERROR_PPPP_UDP_PORT_BIND_FAILED				= -18
exports.ERROR_PPPP_USER_CONNECT_BREAK				= -19
exports.ERROR_PPPP_SESSION_CLOSED_INSUFFICIENT_MEMORY	= -20

---============================================================================
--- P2P

function exports.init()
	-- P2P server ID
	local sid = 'BBGIACBPKEIADLJGAHGKFIBFHOJFCLNCDFFNEDHDFFJKOHKIHDFJCALLHMLAMPKEFCMFLFDBLKMHEGDNJHIMIFEOJM'

	local ret = pppp.init(sid)
	console.log('init:', ret, pppp.version());

	local info = pppp.net_info()
	console.log('init:net_info', info);

	exports.net_info = info
end

function exports.release()
	pppp.release()

	exports.net_info = nil
end

---============================================================================
--- P2P Session

local Session = core.Emitter:extend()
exports.Session = Session

function Session:initialize(handle)
	self.handle 		= handle
	self.isStreaming	= false
	self.streamType		= 0
	self.status			= 0
	self.connectTime	= 0
	self.requestTime	= 0
	self.streamTime		= 0
	self.liveTime		= 0
	self.sampleCount	= 0

	self.commandBuffer	= nil
	self.videoBuffer	= nil
	self.audioBuffer 	= nil
end

-- 创建一个新的会话
function Session.connect(uid, callback)
	local uid = uid or 'WGKJ002047KMGJR'

	local handle = pppp.new_session()
	local ret = handle:connect(uid, 1, 0)
	console.log('connect:', ret);

	local info = handle:get_info()
	console.log('connect:get_info', info);

	return Session:new(handle)
end

-- 关闭这个会话
function Session:close()
	if (self.handle) then
		self.handle:close()
		self.handle = nil
	end
end

function Session:onError(errorInfo, ...)
	console.log('error', errorInfo, ...)
end

function Session:onWarn(warnInfo, ...)
	console.log('wran', warnInfo, ...)
end

function Session:fireEndEvent(...)
	self:emit('end', ...)
end

function Session:fireErrorEvent(...)
	self:emit('error', ...)
end

function Session:fireResponseEvent(...)
	self:emit('response', ...)
end

function Session:fireSnapshotEvent(data)
	self:emit('snapshot', data)

	self:startSteaming()
end

function Session:fireVideoEvent(data)
	self:emit('video', data)
end

-- 检查指定的通道是否可读
function Session:isChannelReadable(channel)
	local handle = self.handle
	if (not handle) then
		return false
	end

	local size = handle:check_buffer(channel);
	if size > 0 then 
		return true
	else 
		return false
	end
end

-- 
function Session:onCommandChannelProccess()
	local handle = self.handle
	if (not handle) then
		self:onWarn('onCommandChannelProccess: invalid handle')
		return 
	end

	local HEADER_SIZE = 8
	local buffer = self.commandBuffer
	local size = buffer:size();
	if (size < HEADER_SIZE) then
		return 0 -- 等待接收更多数据
	end

	local header = buffer:toString(1, HEADER_SIZE)
	local startCode, type, length, version, left = string.unpack('<I2I2I2I2', header)
	if (size < HEADER_SIZE + length) then
		return 0 -- 等待接收更多数据
	end

	local data = buffer:toString(HEADER_SIZE + 1, HEADER_SIZE + length)
	buffer:skip(HEADER_SIZE + length)

	self:onCommandChannelResponse(type, data, length)
	return 1
end

function Session:onCommandChannelRead(channel)
	local handle = self.handle
	if (not handle) then
		self:onWarn('onCommandChannelRead: invalid handle')
		return 
	end

	--local channel = P2P_CMDCHANNEL
	local size = handle:check_buffer(channel);
	if (size <= 0) then
		return
	end

	--console.log('read:check_buffer=', size);

	local ret, data = handle:read(channel, size, 0)
	--console.log('read:read=', ret);

	if (not self.commandBuffer) then
		self.commandBuffer = Buffer:new(1024 * 128)
		self.commandBuffer:position(1)
		self.commandBuffer:limit(1)
	end

	local buffer = self.commandBuffer
	local ret = buffer:putBytes(data)
	if (ret <= 0) then
		return
	end

	while true do
		if self:onCommandChannelProccess() == 0 then
			break
		end
	end
end

-- 处理请求和应答消息
function Session:onCommandChannelResponse(type, data, length)
	--console.log('proccessRequest', string:format('%04X', type))

	if (type == 0x6015 ) then
		self:fireSnapshotEvent(data, length)
		return
	end

	if (data) then
		console.log('proccessRequest:data', string.format('%04X', type), data)
	end

	if (type == 0x60a0) then
		self:sendSnapshot()
	end
end

-- 处理视频数据
function Session:onVideoChannelProccess()
	local handle = self.handle
	if (not handle) then
		self:onWarn('onVideoChannelProccess: invalid handle')
		return 
	end

	-- 4, 1, 1, 2, 4, 4, 4, 1, 1, 2, 8 <I4BBI2I4I4I4BBI2I4I4 startCode,type,streamId,militime,sectime,frameNo,len,version,sessionId
	local HEADER_SIZE = 32
	local buffer = self.videoBuffer
	local size = buffer:size();
	if (size < HEADER_SIZE) then
		return 0 -- 等待接收更多数据
	end

	local header = buffer:toString(1, HEADER_SIZE)
	local startCode, type, streamId, militime, sectime, frameNo, length, version, sessionId 
		= string.unpack('<I4BBI2I4I4I4BBI2I4I4', header)

	code = string.format('%08x', startCode)
	console.log('onVideoChannelProccess', code, 'no', frameNo, 'total', HEADER_SIZE + length, 'buffer', size)

	if (startCode ~= 0xa815aa55) then
		self:stop()
		return 0
	end

	if (size < HEADER_SIZE + length) then
		return 0 -- 等待接收更多数据
	end

	local info = {}
	info.type = type
	info.streamId = streamId
	info.militime = militime
	info.sectime = sectime
	info.frameNo = frameNo
	info.length = length
	info.version = version
	info.sessionId = sessionId

	-- sample data
	local data = buffer:toString(HEADER_SIZE + 1, HEADER_SIZE + length)
	buffer:skip(HEADER_SIZE + length)

	-- process
	self:onVideoChannelSample(data, length, info)
	return 1
end

function Session:onVideoChannelRead(channel)
	local handle = self.handle
	if (not handle) then
		self:onWarn('onVideoChannelRead: invalid handle')
		return 
	end

	--local channel = P2P_CMDCHANNEL
	local size = handle:check_buffer(channel);
	if (size <= 0) then
		return
	end

	--print('size=' .. size);

	local ret, data = handle:read(channel, size, 0)

	if (not self.videoBuffer) then
		self.videoBuffer = Buffer:new(1024 * 512)
		self.videoBuffer:position(1)
		self.videoBuffer:limit(1)
	end

	local buffer = self.videoBuffer
	if (buffer:position() > 1024 * 256) then
		buffer:compress()
	end

	--print('onVideoChannelRead=', ret, 'size', size, 'data', #data, 'offset', offset);

	local ret = buffer:putBytes(data)
	if (ret <= 0) then
		self:onWarn('onVideoChannelRead:putBytes', ret)
		return
	end


	while true do
		--print('buffer=', buffer:position(), buffer:limit());
		if self:onVideoChannelProccess() == 0 then
			break
		end
	end
end

-- 处理视频帧
function Session:onVideoChannelSample(data, length, info)
	--console.log(info)
	--console.printBuffer(data:sub(1, 8))

	self.sampleCount = self.sampleCount + 1
	--console.log('onVideoChannelSample', self.sampleCount)

	if (not self.writer) then
		local writer = StreamWriter:new('/media/sf_newwork/hls.ts')
		console.log(writer)

		if (writer) then
			writer:open()
			writer:writePAT()
			writer:writePMT()
			self.writer = writer
		end
	end

	local pts = info.sectime * 1000 + info.militime % 1000

	if (self.writer) then
		self.writer:write(data, pts)
	end
	-- writer:close()
end

function Session:send(cmd, query)
	local handle = self.handle
	if (not handle) then
		self:onWarn('send: invalid handle')
		return
	end

	-- url
	local fmt = "GET /%s?loginuse=%s&loginpas=%s&user=%s&pwd=%s&%s"
	local path = cmd or "check_user.cgi"
	local username = "admin"
	local password = "888888"
	local url = string.format(fmt, path, username, password, username, password, query)
	console.log('send:url=', url);

	-- message
	local length = #url
	local data = string.pack('<I4I2I2z', 0x00000a01, length, 0x0000, url)

	-- send
	local channel = P2P_CMDCHANNEL
	local ret = handle:write(channel, data, #data - 1)
	if (ret <= 0) then
		self:onWarn('send:write=', ret)
	end
	return ret
end

function Session:sendCheckUser()
	return self:send('check_user.cgi')
end

function Session:sendGetCameraParams()
	return self:send('get_camera_params.cgi')
end

function Session:sendSnapshot()
	return self:send('snapshot.cgi')
end

function Session:start()
	if (self.interval) then
		self:onWarn('start: interval not nil')
		return
	end

	self.interval = timer.setInterval(20, function ()
		if (not self.handle) then
			timer.clearInterval(self.interval)
			self.interval = nil

			self:onWarn('clearInterval')
			return
		end

	    if self:isChannelReadable(P2P_CMDCHANNEL) then
	    	self:onCommandChannelRead(P2P_CMDCHANNEL)
	    end

	    if self:isChannelReadable(P2P_VIDEOCHANNEL) then
	    	self:onVideoChannelRead(P2P_VIDEOCHANNEL)
	    end
	end)
end

function Session:startSteaming()
	self.isStreaming = true
	return self:send('livestream.cgi', 'streamid=10&substream=' .. self.streamType)
end

function Session:stop()
	console.log('stop p2p session')

	self.isStreaming = false

	if (self.interval) then
		timer.clearInterval(self.interval)
		self.interval = nil

		self:onWarn('stop')
	end	
end

function Session:stopSteaming()
	self.isStreaming = false
	return self:send('livestream.cgi', 'streamid=16&substream=0')
end

return exports

