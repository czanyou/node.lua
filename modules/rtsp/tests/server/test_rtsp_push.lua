local core 	= require('core')
local timer = require('timer')

local rtsp 	  = require('rtsp/message')
local push    = require('rtsp/push')
local session = require('media/session')

local rtspPusher = nil

-------------------------------------------------------------------------------
-- MockClientSocket

local color = console.color

local MockClientSocket = core.Emitter:extend()

function MockClientSocket:write(data) 
	print(color('boolean') .. data, color())

	if (data:startsWith("ANNOUNCE")) then
		local message = "RTSP/1.0 200 OK\r\nCSeq: 2\r\n\r\n"
		rtspPusher:handleRawData(message)

	elseif (data:startsWith("OPTIONS")) then
		local message = "RTSP/1.0 200 OK\r\nCSeq: 1\r\n\r\n"
		rtspPusher:handleRawData(message)

	elseif (data:startsWith("SETUP")) then
		local message = "RTSP/1.0 200 OK\r\nCSeq: 3\r\n\r\n"
		rtspPusher:handleRawData(message)

	elseif (data:startsWith("RECORD")) then
		local message = "RTSP/1.0 200 OK\r\nCSeq: 4\r\n\r\n"
		rtspPusher:handleRawData(message)	

	elseif (data:startsWith("TEARDOWN")) then
		local message = "RTSP/1.0 200 OK\r\nCSeq: 5\r\n\r\n"
		rtspPusher:handleRawData(message)			
	end
end

function MockClientSocket:destroy()

end

-------------------------------------------------------------------------------
-- mediaSession

local mediaSession = session.newMediaSession()

function session.getMediaSession(path)
	return mediaSession
end

-------------------------------------------------------------------------------
-- test_rtsp_pusher

local function test_rtsp_pusher()
	rtspPusher = push.RtspPusher:new()
	local socket = MockClientSocket:new()

	local url = "rtsp://127.0.0.1/hd.ts"

	rtspPusher:on('close', function()
		print('close')
	end)

	rtspPusher:on('error', function(err)
		print('error', err)
	end)	

	rtspPusher:on('state', function(state)
		print(color('function') .. 'state = ' .. state, color())

		if (state == push.STATE_RECORDING) then
			rtspPusher:sendTEARDOWN()

		elseif (state == push.STATE_READY) then
			--console.log('mediaTracks', rtspPusher.mediaTracks)
			
		end
	end)

	rtspPusher.sdpString = ""
	rtspPusher.urlString = "/live.mp4"
	rtspPusher.clientSocket = socket
	rtspPusher:sendOPTIONS()

	timer.setTimeout(1000, function ()
	  	console.log("PUSH timeout! ")
	  	
	  	rtspPusher:close()
	end)
end

test_rtsp_pusher()
