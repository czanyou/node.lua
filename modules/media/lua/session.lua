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
local core 		= require('core')
local utils 	= require('util')
local queue 	= require('media/queue')
local lwriter 	= require('media/writer')

local meta 	  	= { }
local exports 	= { meta = meta }

-------------------------------------------------------------------------------
--- MediaSession

--[[
媒体会话
======
用来管理一个 RTSP 会话的媒体流, 这个会话会在内部管理一个缓冲队列, 用来协调数据源和
网络流: 数据源产生的帧会先缓存在队列中, 同时网络层会不断从队列中取出数据并发送.

当网络发送较慢时队列中的帧会越来越多, 当超过缓存上限时, 会丢掉一些较旧的帧. 

- 调用 writeSample 往队列写数据 (如果已经是 TS 流, 则调用 writePacket 即可)
- 连接建立时调用 play 注册发送函数
- 调用 flushBuffer 将缓存区数据依次发送到网络层
- 如果发送函数返回 false 表示网络发送缓存已满, 中止 flushBuffer, 并等待 drain 事件
  才继续发送

通过上述流程即可

--]]
local MediaSession = core.Emitter:extend()
exports.MediaSession = MediaSession

--[[
initialize	

@param options {Object}
- mediaCount
- payload
--]]
function MediaSession:initialize(options)
	options = options or {}

  	-- 这个会话相关的音频信息
	self.audioInfo  	= nil

	-- 当前会话播放状态
	self.isReadStart  	= false

	-- 指出当前会话是否已经被关闭
	self.isStopped  	= false

	-- 当前会话包含的媒体轨道数, 默认只包含一路视频
	self.mediaCount 	= options.mediaCount or 1

	-- 当前会话的 RTP 负载类型, 33 表示 TS 流
	self.payload 		= options.payload or 33 

	-- 回调函数
	self.readCallback 	= nil

	-- 这个会话相关的视频信息
	self.videoInfo  	= 1

	-- 当前会话相关的 RTP 会话, 用来编解码 RTP 数据包等
	self._rtpSession 	= nil

	-- 这个会话相关的视频流缓存队列
	self._videoQueue	= nil

	-- 这个会话相关的音频流缓存队列
	self._audioQueue	= nil

end

function MediaSession:close()
	if (not self.isStopped) then
		self.isStopped = true

		-- end of the stream
		self:onSendPacket(nil)
	end
end

--[[
推送缓存池中的数据，将会话发送队列中的数据推送到网络层。
这个方法会尽量地推送发送队列中的数据直到网络层缓存区也满了为止。
@return 返回成功发送的媒体帧数量，0 表示未发送任何数据
--]]
function MediaSession:flushBuffer()
	local ret = 0

	local audioQueue = self._audioQueue
	if (audioQueue) then
		while (self.isReadStart) do
			local sample = audioQueue:pop()
			if (not sample) then
				break
			end

			--print('MediaSession', 'flushBuffer', sample)

			ret = ret + 1
			sample.isAudio = true
			self:onSendSample(sample)
		end
	end

	local videoQueue = self._videoQueue
	if (videoQueue) then
		while (self.isReadStart) do
			local sample = videoQueue:pop()
			if (not sample) then
				break
			end

			--print('MediaSession', 'flushBuffer', sample)

			ret = ret + 1
			self:onSendSample(sample)
		end
	end

	return ret
end

--[[
返回这个会话的 SDP 描述信息
]]
function MediaSession:getSdpString()
	if (self.sdpString) then
		return self.sdpString
	end

	local sdpString = self:getTSSdpString()
	self.sdpString = sdpString
	return sdpString
end

--[[
返回以 TS 流方式传输的 SDP 描述信息
]]
function MediaSession:getTSSdpString()
	local sb = utils.StringBuffer:new()
	sb:append("v=0\r\n")
	sb:append("o=- 1453439395764824 1 IN IP4 0.0.0.0\r\n")
	sb:append("s=MPEG Transport Stream, streamed by the Vision.lua Media Server\r\n")
	sb:append("i=hd.ts\r\n")
	sb:append("t=0 0\r\n")
	sb:append("a=type:broadcast\r\n")
	sb:append("a=control:*\r\n")
	sb:append("a=range:npt=0-\r\n")

	if (self.videoInfo) then
		sb:append("m=video 0 RTP/AVP 33\r\n")
		sb:append("c=IN IP4 0.0.0.0\r\n")
		sb:append("b=AS:5000\r\n")
		sb:append("a=control:track1\r\n")
	end

	if (self.audioInfo) then
		sb:append("m=audio 0 RTP/AVP 33\r\n")
		sb:append("c=IN IP4 0.0.0.0\r\n")
		sb:append("b=AS:5000\r\n")
		sb:append("a=control:track2\r\n")
	end

	return sb:toString()
end

--[[
发送指定的一帧数据, 这个方法会把这个 sample 编码成多个 RTP 包并发送到网络层。
@param sample {Array} 要发送的数据帧, 1 维数组，组成格式如下: 
	{ sampleTime = ?, 
	  TSPacket, TSPacket, TSPacket ...
	}
	因为一个 RTP 包最大在 1300 多字节左右。
- sample.sampleTime {Number}
]]
function MediaSession:onSendSample(sample)
	if (not sample) then
		return
	end

	self:onSendPacket(table.concat(sample))
end

--[[
这个方法将指定的 RTP 包发送到网络层
@param packet {String} 要发送的 RTP 包
]]
function MediaSession:onSendPacket(packet)
	local sendPacket = self.readCallback
	if (not sendPacket) then
		return
	end

	-- sendPacket 返回 flase 表示发送队列已满，需要等待 'drain' 事件才能继续发送
	self.sendSync = true
	sendPacket(packet)
	self.sendSync = false
end

--[[
开始发送数据流到网络层, 由 RTSP 连接调用，同时提供一个回调函数用来接收要发送的 RTP 包
@param callback {Function} - function(packet) 用于发送数据流的回调函数
]]
function MediaSession:readStart(callback)
	self.isReadStart   	= true
	self.readCallback  = callback

	--print('MediaSession', 'play', self.readCallback)

	if (callback) and (not self.sendSync) then
	    -- self.sendSync 避免循环调用
		self:flushBuffer()
	end
end

--[[
暂停发送数据流到网络层, 由 RTSP 连接调用
]]
function MediaSession:readStop()
	if (self.isReadStart) then
		self.isReadStart = false
	end
end

--[[
write a TS packet

@param packageData {String} 媒体数据，暂时只接受 188 字节长的 TS 包
@param sampleTime {Number} 媒体时间戳, 单位为 1 / 1,000,000 秒
@param flags {Number} 媒体数据标记, 具体定义有为 0x01: 同步点(关键帧), 0x02: 帧结束标记
]]
function MediaSession:writePacket(packageData, sampleTime, flags)
	if (not self.isReadStart) then
		return 0, 'invalid state'
	end

	--print('flags', flags)

	local FLAG_IS_AUDIO = 0x8000
	local FLAG_IS_SYNC  = 0x01

	if (flags & FLAG_IS_AUDIO) ~= 0 then
		if (not self._audioQueue) then
			self._audioQueue = queue.MediaQueue:new()
		end

		flags = flags | FLAG_IS_SYNC -- sync

		self._audioQueue:push(packageData, sampleTime, flags)
		self:flushBuffer()

	else
		if (not self._videoQueue) then
			self._videoQueue = queue.MediaQueue:new()
		end

		self._videoQueue:push(packageData, sampleTime, flags)
		self:flushBuffer()
	end

	return 0
end

--[[	
write a sample，媒体数据先放到会话的内部发送队列中。
因为数据源产生数据流的速度和网络发送数据的速度不一定匹配，这个会话通过
内部发送队列来调节两个流的关系（可能会延时发送或丢掉部分帧）。

@param sample {Object}
- syncPoint {Boolean} 是否是同步点
- sampleData {String} 包含完整的一帧媒体数据
- sampleTime {Number} 单位为 1 / 1,000,000 秒
--]]
function MediaSession:writeSample(sample)
	if (not sample) then
		console.log('empty sample')
		return
	end
	-- TS writer
	local writer = self._writer
	if (not writer) then
		writer = lwriter.open(0x10, function(packet, sampleTime, flags)
			self:writePacket(packet, sampleTime, flags)
			-- console.printBuffer(packet)
		end)

		self._writer = writer
	end

	-- write sample
	local flags = 0
	if (sample.syncPoint) then
		flags = flags | lwriter.FLAG_IS_SYNC
	end

	if (sample.isAudio) then
		flags = flags | lwriter.FLAG_IS_AUDIO
	end

	writer:write(sample.sampleData, sample.sampleTime, flags)
end

-------------------------------------------------------------------------------
-- startMediaSession

local function startMediaSession(cameraDevice, timeout)
	if (not cameraDevice) then
		print(TAG, 'camera open failed!')
		return nil
	end

	-----------------------------------------------------------
	-- mediaSession

	local mediaSession = exports.newMediaSession()
	cameraDevice:setPreviewCallback(function(sample)
		mediaSession:writeSample(sample)
	end)
	cameraDevice:startPreview()

	-----------------------------------------------------------
	-- timeout timer

	if (timeout) then
		setTimeout(timeout, function ()
		  	print(TAG, "camera timeout!", timeout)
		  	
		  	if (cameraDevice) then
		  		cameraDevice:release()
		  	end

		  	if (mediaSession) then
		  		mediaSession:close()
		  	end

		end)
	end

	return mediaSession
end

-------------------------------------------------------------------------------
-- mediaSession

function exports.newMediaSession(options)
	return MediaSession:new(options)
end

function exports.startCameraSession(name, timeout)
	if (not name) then
		return nil, 'invalid camera name!'

	elseif (type(name) == 'table') then
		return startMediaSession(name, timeout)
	end
	-- MediaSteram(ES) => StreamSriter(TS) => MediaSession(RTP) => RtpSession

	local camera = require('media/camera')

	local cameraId = camera.CAMERA_MOCK
	local _onCameraSample = nil
	local filename = nil

	if (name:startsWith('camera:')) then
		cameraId = 1

	elseif (name:startsWith('mock:')) then
		filename = name:sub(6)
	end

	-- camera
	local options = { filename = filename }
	local cameraDevice = camera.open(cameraId, options)
	return startMediaSession(cameraDevice, timeout)
end

return exports
