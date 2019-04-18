local utils 	= require('util')
local url 		= require('url')
local fs 		= require('fs')
local tap 		= require('ext/tap')

local session 	= require('media/session')
local rtp 	    = require('rtsp/rtp')

return tap(function (test)

test('test_rtsp_session', function()
	--console.log(server.MediaSession)

	local mediaSession = session.newMediaSession()
	local rtpSession = rtp.RtpSession:new()

	--console.log(mediaSession)
	--console.log(mediaSession:getSdpString())

	function _onWriteRtpPacket(packet, offset) 
		console.log('_onWriteRtpPacket', #packet)

		local data = rtpSession:decodeHeader(packet, 1)
		console.log(data)

		return true
	end

	mediaSession:readStart(_onWriteRtpPacket)

	mediaSession:writePacket("01234567890", 9006000, 0x01)
	mediaSession:writePacket("01234567890", 9006000, 0x00)
	mediaSession:writePacket("01234567890", 9006000, 0x00)
	mediaSession:writePacket("01234567890", 9006000, 0x02)

	mediaSession:writePacket("01234567890", 9046000, 0x02)

	mediaSession:writePacket("01234567890", 9086000, 0x02)
	mediaSession:readStop()
	
end)

end)