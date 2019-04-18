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

local fs 		= require('fs')
local path  	= require('path')
local timer 	= require('timer')
local utils 	= require('util')
local core   	= require('core')

local camera 	 = require('media/camera')
local hls_reader = require('hls/reader')

local TAG = 'Mock'

local exports = {}

local MEDIA_FORMAT_H264 = 0x34363248
local MEDIA_FORMAT_JPEG = 0x4745504a


--[[
The current module is used to simulate the underlying lmedia library, to achieve 
video capture, encoding, audio input and output functions.

]]

--[[
	if (sample) then
		if (self.startTime <= 0) then
			self.startTime = process.now()
		end

		sample.sampleTime = (process.now() - self.startTime) * 1000
	end
--]]

-------------------------------------------------------------------------------
-- VideoEncoder

local VideoEncoder = core.Object:extend()
exports.VideoEncoder = VideoEncoder


--[[
返回一个模拟媒体流
@param id
@param options
@param callback
]]
function VideoEncoder:initialize(channel, options)
	if (type(options) ~= 'table') then
		options = {}
	end

	self.currentSampleId 	= 0
	self.isStopped 			= false
	self.options 			= options
	self.samples 			= {}
	self.videoSamples 		= {}
	self.audioSamples 		= {}
	self.startTime 			= 0

	-- base path
	if (not options.basePath) then
		options.basePath = path.join(process.cwd(), "")
		print(TAG, 'Base path:', options.basePath)
	end

	--console.log('VideoEncoder', options)

	if (options.codec == MEDIA_FORMAT_JPEG) then
		self:_load_image_from_file(options)

	else
		self:_load_video_from_file(options)
	end

	return self
end

function VideoEncoder:close()
	print(TAG, 'close')

	self.currentSampleId 	= 0
	self.isStopped 			= true
	self.samples 			= {}
	self.videoSamples 		= {}
	self.audioSamples 		= {}
	self.startTime 			= 0
	return 0
end


function VideoEncoder:get_stream()
	if (self.isStopped) then
		print('get_stream', 'isStopped')
		return -1
	end

	return self:_read_next_sample()
end

function VideoEncoder:_load_image_from_file(options)
	--local fileName = options.filename or path.join(options.basePath, '641.ts')
	local filename = path.join(options.basePath, 'examples/test.jpg')
	print('_load_image_from_file', filename)
	fs.readFile(filename, function(ret, data)
		if (not data) then
			return
		end

		self.imageData = data
	end)
end

function VideoEncoder:_load_video_from_file(options)
	local startPacketTime = 0

	if (not options) then
		options = {}
	end

	--console.log('_load_video_from_file', options)

	local function _onStreamStart()

	end

	local function getFixedSampleTime(packetTime)
		-- pts offset
		if (startPacketTime == 0) then
			startPacketTime = packetTime
		end

		return packetTime - startPacketTime
	end

	--[[
	@param packet
	@param sampleTime 1 / 1,000,000 S
	@param sync is sync point
	]]
	local function _onStreamVideoPacket(packetData, sampleTime, syncPoint, sps, pps)
		local sampleTime = getFixedSampleTime(sampleTime)
		--print('video', math.floor(sampleTime / 1000))

		--console.log('_onStreamPacket', #packetData, pts, sync);

		-- sample
		local sample = {}
		sample.pps 			= pps
		sample.rawTime 		= sampleTime
		sample.sampleData 	= packetData
		sample.sampleTime 	= sampleTime
		sample.sps 			= sps
		sample.isSyncPoint	= syncPoint

		--console.log('_onStreamPacket', syncPoint, sampleTime, #packetData);

		-- append
		table.insert(self.samples, sample)
		table.insert(self.videoSamples, sample)
	end

	local function _onStreamAudioPacket(packetData, sampleTime)
		local sampleTime = getFixedSampleTime(sampleTime)
		--print('audio', math.floor(sampleTime / 1000))

		-- sample
		local sample = {}
		sample.rawTime 		= sampleTime
		sample.sampleData 	= packetData
		sample.sampleTime 	= sampleTime
		sample.isAudio		= true

		--console.log('_onStreamPacket', sampleTime, #packetData);

		-- append
		table.insert(self.samples, sample)
		table.insert(self.audioSamples, sample)
	end

	local function _onStreamEnd()
		--console.log('stream end', #mockStream.samples);
		local samples = self.videoSamples

		local totalSamples		= #samples
		if (totalSamples < 2) then
			return
		end

		local startSample 		= samples[1]
		local startSampleTime 	= startSample.sampleTime
		local lastSample 		= samples[totalSamples]
		local lastSampleTime 	= lastSample.sampleTime
		
		local totalDuration 	= (lastSampleTime - startSampleTime)
		local avgDuration 		= totalDuration / (totalSamples - 1)
		local framerate         = math.floor(totalSamples * 1000000 / totalDuration)

		self.avgDuration		= avgDuration
		self.startTime 			= 0
		self.totalDuration 		= totalDuration

		print("Video Stream: duration=" .. math.floor(totalDuration / 1000) 
			.. 'ms, avg=' .. math.floor(avgDuration / 1000)
			.. "ms, total=" .. totalSamples .. "frames, fps=" .. framerate)

		local samples = self.audioSamples

		local totalSamples		= #samples
		if (totalSamples < 2) then
			return
		end

		local startSample 		= samples[1]
		local startSampleTime 	= startSample.sampleTime
		local lastSample 		= samples[totalSamples]
		local lastSampleTime 	= lastSample.sampleTime
		
		local totalDuration 	= (lastSampleTime - startSampleTime)
		local avgDuration 		= totalDuration / (totalSamples - 1)
		local framerate         = math.floor(totalSamples * 1000000 / totalDuration)

		print("Audio Stream: duration=" .. math.floor(totalDuration / 1000) 
			.. 'ms, avg=' .. math.floor(avgDuration / 1000)
			.. "ms, total=" .. totalSamples .. "frames, fps=" .. framerate)
	end

	-- open file
	local fileName = options.filename or path.join(options.basePath, '641.ts')
	local fileId = fs.openSync(fileName, 'r', 438)
	if (not fileId) then
		print(TAG, 'Invalid media file: ' .. fileName)
		return
	end

	-- init reader
	local reader = hls_reader.StreamReader:new()
	reader:on('end',	_onStreamEnd)
	reader:on('video',  _onStreamVideoPacket)
	reader:on('audio',  _onStreamAudioPacket)
	reader:on('start', 	_onStreamStart)
	reader:start()
	
	-- read and parse
	local TS_PACKET_SIZE = hls_reader.TS_PACKET_SIZE;
	while true do
		local packet = fs.readSync(fileId, TS_PACKET_SIZE)
		if (not packet) then
			break

		elseif (reader:processPacket(packet) < 0) then
			break
		end
	end

	-- release all
	reader:close()
	fs.closeSync(fileId)
	fileId = -1
end

--[[
加载下一个 Sample
]]
function VideoEncoder:_read_next_sample()
	self.currentSampleId = self.currentSampleId + 1

	local sample

	if (self.imageData) then
		-- image sample
		sample =  {}
		sample.sampleData = self.imageData

	else
		-- video sample
		sample = self:_read_sample(self.currentSampleId)
	end

	--print('_read_next_sample', self.currentSampleId, sample.sampleTime, sample.isAudio)
	return sample
end

--[[
返回指定 ID 的 Sample
@param sampleId Sample ID, 从 1 开始, 以 1 递增
]]
function VideoEncoder:_read_sample(sampleId)
	local samples = self.samples
	if (not samples) then
		return nil
	end

	local totalSamples = #samples
	if (totalSamples < 1) then
		return nil
	end

	local position  	= (sampleId - 1) % totalSamples + 1
	local level 		= math.floor((sampleId - 1) / totalSamples)
	local baseTime 		= level * self.totalDuration

	local sample 		= samples[position]
	local sampleTime 	= baseTime + sample.rawTime + 0.5

	sample.level 		= level
	sample.sampleId 	= sampleId
	sample.sampleTime 	= math.floor(sampleTime)

	return sample
end

function VideoEncoder:start(flags, callback)
	if (type(flags) == 'function') then
		callback = flags
		flags = 0
	end

	flags = flags or 0

	if (self.isStopped ~= false) then
		self.isStopped = false
	end

	self.callback = callback or function() end

	if (self.timerId) then
		clearInterval(self.timerId)
		self.timerId = nil
	end

	local startTime = process.now()
	local lastSample = nil

	self.timerId = setInterval(10, function()
		while (true) do
			local now = (process.now() - startTime) * 1000

			if (lastSample == nil) then
				lastSample = self:get_stream()
				if (lastSample == nil) then
					break
				end
			end

			--console.log(sample.sampleTime)
			local sampleTime = lastSample.sampleTime or 0
			if (sampleTime > now) then
				break
			end

			local sample = lastSample
			lastSample = nil

			local sampleData = sample.sampleData or ''
			local flags      = 0
			local sampleSize = #sampleData

			if (sample.isAudio) then
				flags = flags | 0x8001
			end

			if (sample.isSyncPoint) then
				flags = flags | 0x1
			end	

			--return sampleSize, sampleData, sampleTime, flags
			--print(now / 1000, math.floor(sampleTime / 1000), flags)

			callback(#sampleData, sampleData, sampleTime, flags)
		end
	end)

	return 0
end

function VideoEncoder:stop()
	if (self.isStopped ~= true) then
		self.isStopped = true
	end

	if (self.timerId) then
		clearInterval(self.timerId)
		self.timerId = nil
	end

	return 0
end

-------------------------------------------------------------------------------
-- video_encoder

local video_encoder = {}

exports.video_encoder = video_encoder

video_encoder.MEDIA_FORMAT_H264 = MEDIA_FORMAT_H264
video_encoder.MEDIA_FORMAT_JPEG = MEDIA_FORMAT_JPEG
video_encoder.MAX_CHANNEL_COUNT = 8

function exports.video_encoder.open(channel, options) 
	--console.log(TAG, 'video_encoder', channel, options) 
	if (options.codec == video_encoder.MEDIA_FORMAT_JPEG) then
		if (not exports.imageEncoder) then
			exports.imageEncoder = VideoEncoder:new(channel, options)
		end

		return exports.imageEncoder

	else
		if (not exports.videoEncoder) then
			exports.videoEncoder = VideoEncoder:new(channel, options)
		end

		return exports.videoEncoder
	end
end


-------------------------------------------------------------------------------

local VideoInput = core.Object:extend()
exports.VideoInput = VideoInput

function VideoInput:initialize(channel, width, height)
	--console.log('VideoInput', channel, width, height)
	self.width   = width
	self.height  = height
	self.channel = channel
end

function VideoInput:connect(encoder)
end

function VideoInput:get_framerate(encoder)
end

function VideoInput:set_framerate(encoder)
end

---------------------------------------------------------------
-- video in

local video_in = {}
exports.video_in = video_in

video_in.MAX_CHANNEL_COUNT = 1


function video_in.init()
	return 0
end

function video_in.open(channel, width, height)
	return VideoInput:new(channel, width, height)
end

function video_in.release()
	return 0
end


---------------------------------------------------------------
-- media

exports.VERSION = '1.0'
exports.TYPE    = 'mock'


function exports.init()
	return 0
end

function exports.release()
	return 0
end

function exports.version()
	return "1.0"
end

function exports.type()
	return "mock"
end

function exports.snapshot(options, callback)
	options = options or {}
	if (not options.basePath) then
		print(options.basePath)
	end

	local filename = path.join(options.basePath, 'examples/test.jpg')
	print('mock image: ', filename)

	fs.readFile(filename, function(ret, data)
		if (not data) then
			if (callback) then
				callback(nil, ret)
			end
			return
		end

		--console.log('snapshot', ret, #data)

		if (callback) then
			callback(data, {mimetype='image/jpg'})
		end
	end)

	return 0
end

return exports
