local core 	= require('core')
local fs 	= require('fs')
local path 	= require('path')
local timer = require('timer')
local url 	= require('url')
local utils = require('utils')

local TAG   = 'push'

local push  	= require('rtsp/push')
local session  	= require('media/session')

local filename = path.join(process.cwd(), "641.ts")
local mediaSession = session.startCameraSession(filename, 60000)

-------------------------------------------------------------------------------
--- start_rtsp_push

local function start_rtsp_push()
	-- console.log(mediaSession)
	local hostport = '127.0.0.1:9552'
	local urlString = "rtsp://" .. hostport .. "/test.mp4"

	local rtspPusher = push.RtspPusher:new()
	local connectInterval = 1000

	rtspPusher:on('connect', function()
		print(TAG, 'connect')

		connectInterval = 1000
	end)

	rtspPusher:on('close', function(errInfo)
		print(TAG, 'close', errInfo)
	end)

	rtspPusher:on('error', function(errInfo)
		print(TAG, 'error', errInfo)
	end)	

	rtspPusher:on('state', function(state)
		print(TAG, 'state', state)
	end)

	local function _reconnectTimer()
		local lastConnectTime = rtspPusher.lastConnectTime or 0
		local now = process.now()
		local span = math.abs(now - lastConnectTime)

		--print('Pusher', rtspPusher.rtspState, span, connectInterval)
		if (span < connectInterval) then
			return
		end

		rtspPusher:open(urlString, mediaSession)

		connectInterval = connectInterval * 2
		if (connectInterval > 60 * 1000) then
			connectInterval = 60 * 1000
		end
	end

	local interval = timer.setInterval(1000, function()
		if (not rtspPusher.clientSocket) then
			_reconnectTimer()
		end
	end)

	local timeout = 50000
	timer.setTimeout(timeout, function()
		print(TAG, 'timeout', timeout)
	  	rtspPusher:close()

	  	if (interval) then
	  		timer.clearInterval(interval)
	  		interval = nil
	  	end
	end)

	--rtspPusher:open(urlString, mediaSession)
end

start_rtsp_push()
