local push    = require('rtsp/push')
local util    = require('util')

local mediaSession = {}

function mediaSession:getSdpString()
	local sb = util.StringBuffer:new()
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

function mediaSession:readStart(sendPacket, ...)
    console.log('readStart', sendPacket, ...)

    local message = string.rep('n', 1500)
    setInterval(100, function()
        sendPacket(message)
    end)
end

function mediaSession:readStop(...)
	console.log('readStop', ...)
end

local function start(port, address)
	local url = 'rtsp://' .. address .. ':' .. port .. '/live.mp4'
    local rtspPusher = push.openURL(url)

	rtspPusher.username = 'admin'
    rtspPusher.password = '12345'
    rtspPusher.mediaSession = mediaSession

    console.log('open', url)

	rtspPusher:on('state', function(state)
		print('state', state, rtspPusher:getRtspStateString(state))

		if (state == push.STATE_READY) then
			console.log('RtspClient', rtspPusher.mediaTracks)
		end
    end)

    rtspPusher:on('close', function(state)
        console.log('close', state)
    end)

    rtspPusher:on('error', function(err)
        console.log('error', err)
    end)

    rtspPusher:on('request', function(request)
        -- console.log('request', request)
    end)

    rtspPusher:on('response', function(request, response)
        console.log('response', request.uriString, response.statusCode)
    end)
end

local address = '192.168.1.135'
address = nil
start(10554, address or '127.0.0.1')

