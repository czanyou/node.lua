local utils 	= require('utils')
local url 		= require('url')
local fs 		= require('fs')
local core 		= require('core')
local tap 		= require('ext/tap')

local rtp 		= require('rtsp/rtp')
local sdp 		= require('rtsp/sdp')
local message 	= require('rtsp/message')
local server 	= require('rtsp/server')
local connection= require('rtsp/connection')

-------------------------------------------------------------------------------
-- mediaSession

local mediaSession = {}

function mediaSession:getSdpString()
	local sb = utils.StringBuffer:new()
	sb:append("v=0\r\n")
	sb:append("o=- 1453439395764824 1 IN IP4 0.0.0.0\r\n")
	sb:append("s=MPEG Transport Stream, streamed by the Vision.lua Media Server\r\n")
	sb:append("i=hd.ts\r\n")
	sb:append("t=0 0\r\n")
	sb:append("a=type:broadcast\r\n")
	sb:append("a=control:*\r\n")
	sb:append("a=range:npt=0-\r\n")
	sb:append("m=video 0 RTP/AVP 33\r\n")
	sb:append("c=IN IP4 0.0.0.0\r\n")
	sb:append("b=AS:5000\r\n")
	sb:append("a=control:track1\r\n")
	return sb:toString()	
end

function mediaSession:readStart()

end

function mediaSession:readStop()

end

-------------------------------------------------------------------------------
-- MockRtspSocket

local MockRtspSocket = core.Emitter:extend()

function MockRtspSocket:write(data) 
	-- console.log('MockRtspSocket', 'write', data)


end

function MockRtspSocket:close()

end

function MockRtspSocket:destroy()

end

-------------------------------------------------------------------------------
-- test_rtsp_connection_server

function test_rtsp_connection_server()
	--console.log(connection.RtspConnection)
	local socket = MockRtspSocket:new()

	local rtspConnection = connection.RtspConnection:new()
	rtspConnection.socket = socket
	console.log(rtspConnection)

	rtspConnection:on('close', function()
		print('test_rtsp_connection_server', 'close')
	end)

	rtspConnection:on('error', function(err)
		print('test_rtsp_connection_server', 'error', err)
	end)

	rtspConnection:on('state', function(state)
		print('test_rtsp_connection_server', 'state', state)

	end)

	rtspConnection._getMediaSession = function(connection, path)
		print('test_rtsp_connection_server', '_getMediaSession', path)

		return mediaSession
	end

	local request = "OPTIONS / RTSP/1.0\r\nCSeq: 1\r\n\r\n"
	rtspConnection:processRawData(request)

	request = "DESCRIBE /live.mp4 RTSP/1.0\r\nCSeq: 2\r\n\r\n"
	rtspConnection:processRawData(request)

	request = "SETUP /live.mp4/track1 RTSP/1.0\r\nCSeq: 3\r\nTransport: RTP/AVP/TCP;interleaved=0-1\r\n\r\n"
	rtspConnection:processRawData(request)

	request = "PLAY /live.mp4 RTSP/1.0\r\nCSeq: 4\r\nSession: 1\r\n\r\n"
	rtspConnection:processRawData(request)

	request = "PAUSE /live.mp4 RTSP/1.0\r\nCSeq: 5\r\nSession: 1\r\n\r\n"
	rtspConnection:processRawData(request)

	request = "TEARDOWN /live.mp4 RTSP/1.0\r\nCSeq: 6\r\nSession: 1\r\n\r\n"
	rtspConnection:processRawData(request)	
end

-------------------------------------------------------------------------------
-- test_rtsp_connection_push

function test_rtsp_connection_push()
	--console.log(connection.RtspConnection)
	local socket = MockRtspSocket:new()

	local rtspConnection = connection.RtspConnection:new()
	rtspConnection.socket = socket
	--console.log('test_rtsp_connection_push', rtspConnection)

	rtspConnection:on('close', function()
		print('test_rtsp_connection_push', 'close')
	end)

	rtspConnection:on('error', function(err)
		print('test_rtsp_connection_push', 'error', err)
	end)

	rtspConnection:on('state', function(state)
		print('test_rtsp_connection_push', 'state', state)

	end)

	rtspConnection:on('announce', function(pathname)
		console.log('test_rtsp_connection_push', 'announce', pathname)
	end)

	rtspConnection:on('record', function(pathname)
		console.log('test_rtsp_connection_push', 'record', pathname)
	end)	

	rtspConnection._getMediaSession = function(connection, path)
		print('test_rtsp_connection_push', '_getMediaSession', path)

		return mediaSession
	end

	local request = "OPTIONS / RTSP/1.0\r\nCSeq: 1\r\n\r\n"
	rtspConnection:processRawData(request)

	request = "ANNOUNCE /live.mp4 RTSP/1.0\r\nCSeq: 2\r\nContent-Type: application/sdp\r\n"
	local sdpString = mediaSession:getSdpString()

	request = request .. "Content-Length: " .. (#sdpString) .. "\r\n"
	request = request .. "\r\n" .. sdpString

	rtspConnection:processRawData(request)

	request = "SETUP /live.mp4/track1 RTSP/1.0\r\nCSeq: 3\r\nTransport: RTP/AVP/TCP;interleaved=0-1\r\n\r\n"
	rtspConnection:processRawData(request)

	request = "RECORD /live.mp4 RTSP/1.0\r\nCSeq: 4\r\nSession: 1\r\n\r\n"
	rtspConnection:processRawData(request)

	request = "PAUSE /live.mp4 RTSP/1.0\r\nCSeq: 5\r\nSession: 1\r\n\r\n"
	rtspConnection:processRawData(request)

	request = "TEARDOWN /live.mp4 RTSP/1.0\r\nCSeq: 6\r\nSession: 1\r\n\r\n"
	rtspConnection:processRawData(request)	
end

test_rtsp_connection_server()
test_rtsp_connection_push()

