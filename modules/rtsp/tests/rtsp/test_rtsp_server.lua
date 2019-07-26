 
local utils = require('util')
local url 	= require('url')
local fs 	= require('fs')
local path 	= require('path')
local timer = require('timer')

local session = require('media/session')
local client  = require('rtsp/client')
local rtsp 	  = require('rtsp/message')
local server  = require('rtsp/server')
local ts	  = require('hls/writer')

local filename = path.join(process.cwd(), "../examples/641.ts")
local mediaSession = session.startCameraSession(filename, 6000)

-------------------------------------------------------------------------------
--- test_rtsp_server

function test_rtsp_server(port, timeout)
	local listPort   = port or 9554

	print('Start RTSP server at ('.. listPort .. ') ...')
	local rtspServer = server.startServer(listPort)

	rtspServer._getMediaSession = function(connection, path) 
		return mediaSession
	end

	rtspServer.authCallback = function(username)
		return '12345'
	end

	local delay = timeout or 5000
	timer.setTimeout(delay, function()
	  	console.log("RTSP server timeout!")
	  	rtspServer:close()
	end)
end

-------------------------------------------------------------------------------
--- test_rtsp_client

function test_start_rtsp_client()
	local rtspClient = client.RtspClient:new()

	rtspClient.username = 'admin'
	rtspClient.password = '12345'

	rtspClient:on('state', function(state)
		print('RtspClient', 'state', state)

		if (state == client.STATE_READY) then
			console.log('RtspClient', rtspClient.mediaTracks)
		end
	end)

	rtspClient.onTSPacket = function(rtspClient, meta, packet, offset)
		local data = packet:sub(offset, offset + 16)
		--console.printBuffer(data)

		meta.sampleTime = meta.sampleTime * 1000
		meta.rtpTime = nil

		if (meta.marker) then
			console.log('ts', offset, #packet, meta)
		end
	end

	local url = "rtsp://127.0.0.1:9554/live.mp4"
	rtspClient:open(url)
end

function test_rtsp_client()
	timer.setTimeout(1000, test_start_rtsp_client)
end

test_rtsp_server()
test_rtsp_client()
