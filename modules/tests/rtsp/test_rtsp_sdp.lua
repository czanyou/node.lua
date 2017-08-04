
local utils 	= require('utils')
local assert 	= require('assert')
local tap 		= require('ext/tap')

local sdp   	= require('rtsp/sdp')

local sdpString = 'v=0\r\no=- 1453271342214497 1 IN IP4 10.10.42.66\r\ns=MPEG Transport Stream, streamed by the LIVE555 Media Server\r\ni=hd.ts\r\nt=0 0\r\na=tool:LIVE555 Streaming Media v2015.07.31\r\na=type:broadcast\r\na=control:*\r\na=range:npt=0-\r\na=x-qt-text-nam:MPEG Transport Stream, streamed by the LIVE555 Media Server\r\na=x-qt-text-inf:hd.ts\r\nm=video 0 RTP/AVP 33\r\nc=IN IP4 0.0.0.0\r\nb=AS:5000\r\na=control:track1\r\n'

return tap(function (test)

test("test sdp decode", function()
	local session = sdp.decode(sdpString)

	assert.equal(session.v, '0')
	assert.equal(session.t, '0 0')

	local attributes = session.attributes
	assert.equal(attributes["control"], '*')
	assert.equal(attributes["range"], 'npt=0-')

	local medias = session.medias

	assert.equal(#medias, 1)

	local media = medias[1]
	assert.equal(media.type	,  'video')
	assert.equal(media.payload, 33)
	assert.equal(media.port , 	0)
	assert.equal(media.mode, 	'RTP/AVP')

	local attributes = media.attributes
	assert.equal(attributes["control"], 'track1')
end)

test("test sdp decode 2", function()

local sdpString = [[
v=0
o=- 535676825 535676825 IN IP4 184.72.239.149
s=BigBuckBunny_115k.mov
c=IN IP4 184.72.239.149
t=0 0
a=sdplang:en
a=range:npt=0- 596.48
a=control:*
m=audio 0 RTP/AVP 96
a=rtpmap:96 mpeg4-generic/12000/2
a=fmtp:96 profile-level-id=1;mode=AAC-hbr;sizelength=13;indexlength=3;indexdeltalength=3;config=1490
a=control:trackID=1
m=video 0 RTP/AVP 97
a=rtpmap:97 H264/90000
a=fmtp:97 packetization-mode=1;profile-level-id=42C01E;sprop-parameter-sets=Z0LAHtkDxWhAAAADAEAAAAwDxYuS,aMuMsg==
a=cliprect:0,0,160,240
a=framesize:97 240-160
a=framerate:24.0
a=control:trackID=2
]]

	local session = sdp.decode(sdpString)
	--console.log(session)

	assert.equal(session.v, '0')
	assert.equal(session.t, '0 0')

	local attributes = session.attributes
	assert.equal(attributes["control"], '*')
	assert.equal(attributes["range"], 'npt=0- 596.48')

	local medias = session.medias

	assert.equal(#medias, 2)

	local video = session:getMedia('video')
	console.log(video:getAttribute('fmtp'))


	local fmtp = video:getFmtp(96)
	--console.log(fmtp['sprop-parameter-sets'])

	local value = fmtp['sprop-parameter-sets']
	local tokens = value:split(',')
	console.log(tokens)

	local sqs = utils.base64Decode(tokens[1])
	local pps = utils.base64Decode(tokens[2])
	console.printBuffer(sqs)
	console.printBuffer(pps)


	local rtpmap = video:getRtpmap(96)

	rtpmap.framerate = video:getFramerate()
	rtpmap.framesize = video:getFramesize()


	console.log(rtpmap)

end)

end)
