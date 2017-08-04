local utils   = require('utils')
local lmedia  = require('lmedia')
local thread  = require('thread')
local uv      = require('uv')
local fs      = require('fs')
local thread  = require('thread')

local video_input
local video_group
local video_encoder

local function start_mpp()
	--console.log(lmedia)
	local type = lmedia.TYPE or ''
	print('video camera type: ' .. type)

	--console.log(lmedia)

	local ret = lmedia.init()
	if (ret ~= 0) then
		print('init error', ret, string.format("0x%x", ret & 0xffffffff))
		return ret
	end

	ret = lmedia.video_in.init()
	if (ret ~= 0) then
		print('video_in.init failed!')
		return ret
	end

	local videoId = 0
	video_input = lmedia.video_in.open(videoId)
	if (not video_input) then
		print('video_in.open failed!')
		return -1
	end

	--print('video_input: ', video_input)

	local options = {}
	options.bitrate 	= 2000
	options.enabled 	= 1
	options.frameRate 	= 25
	options.gopLength 	= 100
	
	options.height 		= 720
	options.width 		= 1280
	
	if (type == 'hi3516a') then
		options.height 	= 1080
		options.width 	= 1920
	end

	if (type == 'uvc') then
		options.height 	= 360
		options.width 	= 640

		options.height 	= 720
		options.width 	= 1280
		options.codec   = lmedia.video_encoder.MEDIA_FORMAT_H264
		options.flags	= 0x00400
	end

	local channel = 0
	video_encoder = lmedia.video_encoder.open(channel, options)
	if (not video_encoder) then
		print('video_encoder.open failed!')
		return -1
	end

	print('video_encoder: ', video_encoder)

	local ret, settings = video_encoder:get_attributes()
	console.log(ret, settings)

	video_input:connect(video_encoder)
	ret = video_encoder:start(0, function(ret, data, sampleTime, flags)
		--console.log('start', ...)
		if (data == nil) then
			-- print('nil data')
			return
		end

		print("frame", ret, #data, sampleTime, flags)
	end)

	return ret
end

local function stop_mpp()

end

-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
-- Main function
-- ~~~~~~~~~
local function main(args)
	--console.log(lmedia)
	start_mpp()
end

main(arg)

setTimeout(100, function() end)
