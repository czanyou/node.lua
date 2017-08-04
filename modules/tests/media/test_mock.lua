local init 	= require('init')
local utils = require('utils')
local url 	= require('url')
local fs 	= require('fs')
local path  = require('path')
local timer = require('timer')
local assert = require("assert")

local rtp 	= require('rtsp/rtp')
local sdp 	= require('rtsp/sdp')
local rtsp 	= require('rtsp/message')

local camera = require('media/camera')
local mock   = require('media/mock')


local basePath = utils.dirname()

local function test_snaphost()
	local options = { basePath = path.join(basePath, "/../../") }
	local ret = mock.snapshot(options, function(data, type)
		console.log(#data, type)
	end)
end


local function test_video_encoder()
	--console.log(mock)

	local ret = mock.init()
	assert.equal(ret, 0)

	local ret = mock.video_in.init()
	assert.equal(ret, 0)

	local ret = mock.video_in.open()
	console.log(ret)
	--assert.equal(ret, 0)


	local options = { basePath = path.join(basePath, "/../../examples/") }
	local encoder = mock.video_encoder.open(1, options)
	--console.log(ret)

	print(encoder.totalDuration)
	print(encoder.avgDuration)
	assert.equal(#encoder.samples, 224)
	assert.equal(math.floor(encoder.totalDuration / 1000), 9333)
	assert.equal(math.floor(encoder.avgDuration / 1000 + 0.5), 42)

	local index = 0
	local timer 

	timer = setInterval(40, function()
		local id, sample, ts = encoder:get_stream()
		console.log(id, #sample:to_string(), sample:time_seconds(), sample:time_useconds())

		index = index + 1
		if (index > 100) then
			clearInterval(timer)
		end
	end)
end


test_video_encoder()
test_snaphost()




