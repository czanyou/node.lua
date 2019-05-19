local utils = require('util')
local url 	= require('url')
local fs 	= require('fs')
local path 	= require('path')
local core 	= require('core')

local client = require('rtsp/client')
local RtspClient = client.RtspClient

local rtspClient = nil

local TAG 	= 'test_rtsp_client'
local color = console.color

-------------------------------------------------------------------------------
-- MockClientSocket

local MockClientSocket = core.Emitter:extend()

-- 模拟一个 RTSP 服务端 SDP 串
function MockClientSocket:getSdpString()
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

-- 模拟一个 RTSP 服务端
function MockClientSocket:handleRequest(data)
	if (data:startsWith("OPTIONS")) then
		local message = "RTSP/1.0 200 OK\r\nCSeq: 1\r\n\r\n"
		self:writeResponse(message)

	elseif (data:startsWith("DESCRIBE")) then
		local message = "RTSP/1.0 200 OK\r\nCSeq: 2\r\nContent-Type: application/sdp\r\n"
		local sdpString = self:getSdpString()

		message = message .. "Content-Length: " .. (#sdpString) .. "\r\n"
		message = message .. "\r\n" .. sdpString
		self:writeResponse(message)

	elseif (data:startsWith("SETUP")) then
		local message = "RTSP/1.0 200 OK\r\nCSeq: 3\r\n\r\n"
		self:writeResponse(message)

	elseif (data:startsWith("PLAY")) then
		local message = "RTSP/1.0 200 OK\r\nCSeq: 4\r\n\r\n"
		self:writeResponse(message)

	elseif (data:startsWith("PAUSE")) then
		local message = "RTSP/1.0 200 OK\r\nCSeq: 5\r\n\r\n"
		self:writeResponse(message)

	elseif (data:startsWith("TEARDOWN")) then
		local message = "RTSP/1.0 200 OK\r\nCSeq: 6\r\n\r\n"
		self:writeResponse(message)		
	end
end

function MockClientSocket:writeResponse(data) 
	--console.log('MockClientSocket', 'writeResponse', data)
	rtspClient:handleData(data)	
end

function MockClientSocket:write(data) 
	setImmediate(function()
		print(color('boolean') .. data, color())
		self:handleRequest(data)
	end)
end

function MockClientSocket:destroy()
	console.log('MockClientSocket', 'destroy')
end

-------------------------------------------------------------------------------
-- test_rtsp_client

function test_rtsp_client()
	rtspClient = RtspClient:new()

	rtspClient:on('close', function(err)
		print(TAG, 'close', err)
	end)

	rtspClient:on('error', function(err)
		print(TAG, 'error', err)
	end)

	local lastState = 0

	local timeoutTimer = setTimeout(1000, function ()
	  	console.log(TAG, "Client timeout! ")
	  	rtspClient:close()
	end)

	rtspClient:on('state', function(state)
		print(TAG, color('function') .. 'state = ' .. state, color())

		if (state == client.STATE_PLAYING) then
			rtspClient:sendPAUSE()
			--rtspClient:sendTEARDOWN()

		elseif (state == client.STATE_READY) then
			if (lastState == client.STATE_PLAYING) then
				rtspClient:sendTEARDOWN()

			else
				print(TAG, 'mediaTracks: \n======')
				console.log(rtspClient.mediaTracks)
				print("")
			end

		elseif (state == client.STATE_INIT) then	
			if (lastState > client.STATE_INIT) then
				clearTimeout(timeoutTimer)
				rtspClient:close()
			end
		end

		lastState = state
	end)

	local url = "rtsp://127.0.0.1/hd.ts"
	--local url = "rtsp://192.168.31.64/live.mp4"

	rtspClient.sdpString 	= ""
	rtspClient.urlString 	= url
	rtspClient.clientSocket = MockClientSocket:new()

	rtspClient:sendOPTIONS()
end

test_rtsp_client()

