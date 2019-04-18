local fs 		= require('fs')
local path  	= require('path')
local timer 	= require('timer')
local utils 	= require('util')
local uv 		= require('uv')

local basePath  = utils.dirname()

local camera 	= require('media/camera')

--[[

模拟从摄像头采集视频流或者抓拍图片

--]]
function test_media_camera_preview()
	local filename = path.join(basePath, "/../../examples/641.ts")

	local options = { filename = filename }
	local mock = camera.open(camera.CAMERA_MOCK, options)

	mock:setPreviewCallback(function(sample)
		sample.sampleData = nil
		console.log('Preview Callback', sample)
	end)

	mock:startPreview()

	-- 定时退出
	timer.setTimeout(2000, function ()
	  	if (mock) then
	  		mock:stopPreview()
	  	end
	end)

	timer.setTimeout(3000, function ()
	  	print("mock test timeout! ")
	  	
	  	if (mock) then
	  		mock:release()
	  	end
	end)
end

function test_media_camera_take_picture()

	local options = { filename = filename }
	local mock = camera.open(camera.CAMERA_MOCK, options)

	mock:takePicture(function(sample)
		sample.sampleData = nil
		console.log('takePicture 1', sample)

		mock:takePicture(function(sample)
			sample.sampleData = nil
			console.log('takePicture 2', sample)
		end)
	end)

	-- 定时退出
	timer.setTimeout(2000, function ()
	  	print("mock test timeout! ")
	  	
	  	if (mock) then
	  		mock:release()
	  	end
	end)
end

test_media_camera_preview()
--test_media_camera_take_picture()

run_loop()

