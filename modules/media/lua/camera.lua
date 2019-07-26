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

local core  = require('core')
local utils = require('util')
local uv    = require('luv')

local TAG = "Camera"

local exports = {}

exports.CAMERA_MOCK = 10086
exports.cameras = {}

-------------------------------------------------------------------------------
-- resolutions

exports.resolutions = {
	-- 16:9
	['180p'] 	= { width = 320,  height = 180  },
	['360p'] 	= { width = 640,  height = 360  },
	['540p'] 	= { width = 960,  height = 540  },
	['720p'] 	= { width = 1280, height = 720  },
	['900p'] 	= { width = 1600, height = 900  },
	['1080p'] 	= { width = 1920, height = 1080 },
	['1260p'] 	= { width = 2240, height = 1260 },
	['1440p'] 	= { width = 2560, height = 1440 },
	['1620p'] 	= { width = 2880, height = 1620 },

	['qhd'] 	= { width = 960,  height = 540  },
	['full-hd'] = { width = 1920, height = 1080 },

	-- 4:3
	['qqvga'] 	= { width = 160,  height = 120  },
	['qvga'] 	= { width = 320,  height = 240  },
	['vga'] 	= { width = 640,  height = 480  },
	['svga'] 	= { width = 800,  height = 600  },
	['xga'] 	= { width = 1024, height = 768  },
	['xvga'] 	= { width = 1280, height = 960  },
	['uxga'] 	= { width = 1600, height = 1200 },

	-- 
	['wvga'] 	= { width = 800,  height = 480  },
	['wxga'] 	= { width = 1280, height = 800  },
	['wxga+'] 	= { width = 1440, height = 900  },
	['wuxga'] 	= { width = 1920, height = 1200 },
	['wsxga+'] 	= { width = 1680, height = 1050 },
	
	-- 5:4
	['qcif'] 	= { width = 176,  height = 144  },
	['cif'] 	= { width = 352,  height = 288  },
	['d1'] 		= { width = 704,  height = 576  },
}

-------------------------------------------------------------------------------
-- local functions 

local function onMediaInit(args, lmedia)
	if (exports.videoInput) then
		return
	end

	--console.log(lmedia)

	lmedia.init()
	lmedia.video_in.init()

	-- 打开视频输入通道
	local videoId = 0
	exports.videoInput = lmedia.video_in.open(videoId, 0, 0, 0)

	--print(TAG, 'onMediaInit', channelCount)
end

local function onMediaRelease()
	if (exports.mockCamera) then
		exports.mockCamera:release()
		exports.mockCamera = nil
	end

	if (exports.defaultCamera) then
		exports.defaultCamera:release()
		exports.defaultCamera = nil
	end	

	if (exports.videoInput) then
		exports.videoInput:close()
		exports.videoInput = nil
	end

	--print(TAG, 'onMediaRelease')
end

local function openVideoEncoder(options, lmedia)
	options = options or {}
	options.codec = lmedia.video_encoder.MEDIA_FORMAT_H264

	local videoEncoder = lmedia.video_encoder.open(options.channel, options)
	exports.videoInput:connect(videoEncoder)

	return videoEncoder
end

local function openImageEncoder(options, lmedia)
	options = options or {}
	options.codec = lmedia.video_encoder.MEDIA_FORMAT_JPEG
	local imageEncoder = lmedia.video_encoder.open(options.channel, options)
	exports.videoInput:connect(imageEncoder)

	return imageEncoder
end

-------------------------------------------------------------------------------
-- Camera

local Camera = core.Emitter:extend()
exports.Camera = Camera

function Camera:initialize(cameraId, args, lmedia)
	self.isPreview 		 = false
	self.previewCallback = nil
	self.lmedia			 = lmedia
	self.cameraId 		 = cameraId or 1
	self.model			 = lmedia.TYPE
	self.version		 = lmedia.VERSION
	self.wait			 = lmedia.wait

	if (type(args) ~= 'table') then
		args = {}
	end

	-- 创建编码组
	local videoId = tonumber(self.cameraId) or 1
	videoId = (videoId - 1)

	-- 创建一个编码通道
	local options = {}
	options.basePath 	= args.basePath
	options.bitrate 	= args.bitrate 		or 400
	options.channel 	= videoId
	options.enabled 	= 1
	options.filename 	= args.filename
	options.frameRate 	= args.frameRate 	or 25
	options.gopLength 	= args.gopLength	or options.frameRate * 4
	options.height 		= args.height 		or 720
	options.width 		= args.width 		or 1280
	options.flags		= 0x00400 -- print debug info

	self.options = options
end

-- Reconnects to the camera service after another process used it.
function Camera:reconnect()


end

-- Disconnects and releases the Camera object resources.
function Camera:release()
	if (self.isPreview) then
		self:stopPreview()
	end

	if (self.isSnapshot) then
		self:stopSnapshot()
	end

	if (self.videoEncoder) then
		self.videoEncoder:close()
		self.videoEncoder = nil
	end

	if (self.imageEncoder) then
		self.imageEncoder:close()
		self.imageEncoder = nil
	end	

	self.isPreview 		 	= false
	self.lmedia			 	= nil
	self.options		 	= nil
	self.previewCallback 	= nil
	self.snapshotCallback 	= nil
	self.snapshotCallbacks 	= nil
end

-- Installs a callback to be invoked for every preview frame
function Camera:setPreviewCallback(callback)
	self.previewCallback = callback
end

function Camera:setSnapshotCallback(callback)
	self.snapshotCallback = callback
end

function Camera:startPreview(callback)
	if (self.isPreview) then
		return
	end

	if (type(callback) == 'function') then
		self.previewCallback = callback
	end

	self.isPreview = true
	if (not self.videoEncoder) then
		self.videoEncoder = openVideoEncoder(self.options, self.lmedia)
	end

	local videoEncoder = self.videoEncoder

	local _onMediaStream = function(sampleBuffer, sampleTime, flags)
		if (not sampleBuffer) then
			console.log('sampleBuffer', sampleTime)
			return
		end

		--console.log(sampleBuffer, sampleTime, flags)
		flags = flags or 0

		local sample = {}
		sample.sampleTime 	= sampleTime
		sample.sampleData 	= sampleBuffer
		sample.sampleSize	= #sampleBuffer
		sample.isAudio		= (flags & 0x8000) ~= 0
		sample.syncPoint	= (flags & 0x01) ~= 0

		if (not self.isPreview) then
			--print(TAG, 'not isPreview')
			return
		end

		if (self.previewCallback) then
			self.previewCallback(sample)
			--console.log('sampleBuffer', sampleTime, isAudio)

		else
			print(TAG, 'not previewCallback')
		end
	end

	videoEncoder:start(0, function(ret, ...)
		--console.log(ret, ...)

		local ret, err = pcall(_onMediaStream, ...)
		if (not ret) then
			console.log('start', ret, err)
		end
	end)
end

function Camera:startSnapshot(callback)
	if (self.isSnapshot) then
		print('startSnapshot: isSnapshot')
		return
	end

	if (type(callback) == 'function') then
		self.snapshotCallback = callback
	end	

	self.isSnapshot = true

	local imageEncoder = self.imageEncoder

	local _onMediaStream = function(sampleBuffer, sampleTime)
		if (not sampleBuffer) then
			return

		elseif (not self.isSnapshot) then
			return
		end

		--console.log('sampleBuffer', sampleTime, self.snapshotCallback)
		local sample = {}

		if (type(sampleBuffer) == 'string') then
			sample.sampleTime 	= sampleTime
			sample.sampleData 	= sampleBuffer
			sample.sampleSize	= #sampleBuffer
			sample.syncPoint	= true
			sample.mimetype		= 'image/jpg'

		else
			sample.sampleTime 	= sampleTime
			sample.sampleData 	= sampleBuffer:to_string()
			sample.sampleSize	= sampleBuffer:length()
			sample.syncPoint	= true
			sample.mimetype		= 'image/jpg'
		end

		local callbacks = self.snapshotCallbacks
		if (callbacks) then
			self.snapshotCallbacks = nil
			for _, callback in ipairs(callbacks) do
				callback(sample)
			end
		end

		local callback = self.snapshotCallback
		if (callback) then
			callback(sample)
		end
	end

	imageEncoder:start(0, function(ret, ...)
		pcall(_onMediaStream, ...)
	end)
end

function Camera:stopPreview()
	--print(TAG, 'stopPreview', self.isPreview)

	if (not self.isPreview) then
		return
	end

	self.isPreview = false

	if (self.intervalTimer) then
		clearInterval(self.intervalTimer)
		self.intervalTimer = nil
	end

	-- close poll
	if (self.poll) then
		self.poll:stop()

		if (not self.poll:is_closing()) then
			self.poll:close()
		end

		self.poll = nil
	end

	-- close encoder
	local videoEncoder = self.videoEncoder
	if (videoEncoder) then
		videoEncoder:stop()
	end
end

function Camera:stopSnapshot()
	--print(TAG, 'stopSnapshot', self.isSnapshot)

	if (not self.isSnapshot) then
		return
	end

	self.isSnapshot = false

	if (self.snapshotTimer) then
		clearInterval(self.snapshotTimer)
		self.snapshotTimer = nil
	end

	-- close poll
	local poll = self.snapshotPoll 
	if (poll) then
		poll:stop()

		if (not poll:is_closing()) then
			poll:close()
		end

		self.snapshotPoll = nil
	end

	-- close encoder
	local imageEncoder = self.imageEncoder
	if (imageEncoder) then
		imageEncoder:stop()
	end
end

-- Triggers an asynchronous image capture.
function Camera:takePicture(callback)
	if (not self.snapshotCallbacks) then
		self.snapshotCallbacks = {}
	end

	table.insert(self.snapshotCallbacks, callback)

	if (not self.imageEncoder) then
		local options = self.options
		--console.log('takePicture:', options)
		self.imageEncoder = openImageEncoder(options, self.lmedia)
	end

	if (not self.isSnapshot) then
		self:startSnapshot()
	end
end

-------------------------------------------------------------------------------

local function _openMockCamera(options)
	if (exports.mockCamera) then
		return exports.mockCamera
	end	

	local mock = require("media/mock")

	if (not exports.videoInput) then
		onMediaInit(options, mock)
	end

	local cameraId = nil

	exports.mockCamera = Camera:new(cameraId, options, mock)
	return exports.mockCamera
end

-- Creates a new Camera object to access a particular hardware camera.
function exports.open(cameraId, options)
	if (not cameraId) then
		print(TAG, 'open: Expected cameraId')
		return nil

	elseif (cameraId == exports.CAMERA_MOCK) then
		-- Open a mock camera
		return _openMockCamera(options)

	elseif (type(cameraId) == 'string' and cameraId:startsWith('mock:')) then
		-- Open a mock with filename
		options = options or {}
		options.filename = cameraId:sub(6)
		return _openMockCamera(options)

	else
		local defaultCamera = exports.cameras[cameraId]
		if (defaultCamera) then
			return defaultCamera
		end

		local args = nil

		local lmedia = require("lmedia")
		if (not exports.videoInput) then
			onMediaInit(args, lmedia)
		end

		defaultCamera = Camera:new(cameraId, options, lmedia)

		exports.cameras[cameraId] = defaultCamera
		return defaultCamera
	end
end

function exports.release()
	onMediaRelease()
end

setmetatable(exports, {
	__call = function(self, ...)
		return self.open(...)
	end
})

return exports

