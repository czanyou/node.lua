 
local utils = require('util')
local path 	= require('path')
local timer = require('timer')

local proxy 	= require('rtsp/proxy')
local push  	= require('rtsp/push')
local session  	= require('media/session')

local filename = path.join(process.cwd(), "../examples/641.ts")
local mediaSession = session.startCameraSession(filename, 6000)

-------------------------------------------------------------------------------
--- test_rtsp_proxy

local function test_rtsp_proxy()
	local rtspProxy = proxy.startServer(9552)

	local timeout = 5100
	timer.setTimeout(timeout, function ()
	  	console.log('Proxy', "timeout! ", timeout)
	  	rtspProxy:close()
	end)
end

-------------------------------------------------------------------------------
--- test_rtsp_push

local function test_rtsp_push()
	local rtspPusher = push.RtspPusher:new()

	rtspPusher:on('close', function(err)
		print('Push', 'close', err)
	end)

	rtspPusher:on('error', function(err)
		print('Push', 'error', err)
	end)	

	rtspPusher:on('state', function(state)
		print('Push', 'state', state)
	end)

	rtspPusher._getMediaSession = function()
		return mediaSession
	end

	local urlString = "rtsp://127.0.0.1:9552/live.mp4?v=1"
	rtspPusher:open(urlString)

	local timeout = 5000
	timer.setTimeout(5000, function ()
	  	rtspPusher:close()
	end)
end

local function test_rtsp_push_delay()
	timer.setTimeout(500, test_rtsp_push)
end

test_rtsp_proxy()
test_rtsp_push_delay()
