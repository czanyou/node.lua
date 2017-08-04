local utils 	= require('utils')
local path 		= require('path')

local server   	= require('rtsp/server')
local session  	= require('media/session')

local filename = 'mock:' .. path.join(utils.dirname(), "641.ts")
local mediaSession = session.startCameraSession(filename)

local listenPort   = 9554

function main()
	print('Start RTSP server listen at ('.. listenPort .. ') ...')
	local rtspServer = server.startServer(listenPort, function(connection, pathname) 
		return mediaSession
	end)

	print('    URL: rtsp://<localhost>:9554/live.mp4')
end

main()
