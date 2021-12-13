local utils 	= require('util')
local assert 	= require('assert')
local tap 		= require('util/tap')

local sdp   	= require('rtsp/sdp')

describe("test sdp decode 1", function()
	local sdpString = [[v=0
o=- 1453271342214497 1 IN IP4 10.10.42.66
s=MPEG Transport Stream, streamed by the LIVE555 Media Server
i=hd.ts
t=0 0
a=tool:LIVE555 Streaming Media v2015.07.31
a=type:broadcast
a=control:*
a=range:npt=0-
a=x-qt-text-nam:MPEG Transport Stream, streamed by the LIVE555 Media Server
a=x-qt-text-inf:hd.ts
m=video 0 RTP/AVP 33
c=IN IP4 0.0.0.0
b=AS:5000
a=control:track1
]]

	local session = sdp.decode(sdpString)

	-- version & time
	assert.equal(session.v, '0')
	assert.equal(session.t, '0 0')

	-- attributes
	local attributes = session.attributes
	assert.equal(attributes["control"], '*')
	assert.equal(attributes["range"], 'npt=0-')

	-- media tracks
	local medias = session.medias
	assert.equal(#medias, 1)

	-- video track
	local media = medias[1]
	assert.equal(media.type	,  'video')
	assert.equal(media.payload, 33)
	assert.equal(media.port , 	0)
	assert.equal(media.mode, 	'RTP/AVP')

	-- video track attributes
	attributes = media.attributes
	assert.equal(attributes["control"], 'track1')

	console.log(media)
end)

describe("test sdp decode 2", function()

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
a=fmtp:97 packetization-mode=1;profile-level-id=42C01E; sprop-parameter-sets= Z0LAHtkDxWhAAAADAEAAAAwDxYuS,aMuMsg==
a=cliprect:0,0,160,240
a=framesize:97 240-160
a=framerate:24.0
a=control:trackID=2
]]

	local session = sdp.decode(sdpString)

	-- version & time
	assert.equal(session.v, '0')
	assert.equal(session.t, '0 0')

	-- attributes
	local attributes = session.attributes
	assert.equal(attributes["control"], '*')
	assert.equal(attributes["range"], 'npt=0- 596.48')

	-- media tracks
	local medias = session.medias
	assert.equal(#medias, 2)

	-- audio track
	local audio = session:getMedia('audio')
	local audioRtpMap = audio:getRtpmap(96)
	console.log(audioRtpMap)

	assert.equal(audioRtpMap.payload, 96)
	assert.equal(audioRtpMap.codec, 'mpeg4-generic')
	assert.equal(audioRtpMap.frequency, 12000)

	local audioFmtp = audio:getFmtp(96)
	console.log(audioFmtp)

	assert.equal(audioFmtp['mode'], 'AAC-hbr')
	assert.equal(audioFmtp['profile-level-id'], '1')

	assert.equal(audio:getAttribute('control', 'trackID'), '1')

	-- video track
	local video = session:getMedia('video')
	assert.equal(video:getAttribute('cliprect'), '0,0,160,240')

	local videoFmtp = video:getFmtp(97)
	assert.equal(videoFmtp['packetization-mode'], '1')
	assert.equal(videoFmtp['profile-level-id'], '42C01E')

	-- parameter-sets
	local value = videoFmtp['sprop-parameter-sets']
	local tokens = value:split(',')
	local sqs = utils.base64Decode(tokens[1])
	local pps = utils.base64Decode(tokens[2])

	assert.equal(utils.hexEncode(sqs), '6742c01ed903c56840000003004000000c03c58b92')
	assert.equal(utils.hexEncode(pps), '68cb8cb2')

	-- rtpmap
	local videoRtpMap = video:getRtpmap(97)
	assert.equal(videoRtpMap.payload, 97)
	assert.equal(videoRtpMap.codec, 'H264')
	assert.equal(videoRtpMap.frequency, 90000)

	console.log('rtpmap', videoRtpMap)

	-- frame rate
	assert.equal(video:getFramerate(), 24)

	-- frame size
	local frameSize = video:getFramesize()
	assert.equal(frameSize.width, 240)
	assert.equal(frameSize.height, 160)

	assert.equal(video:getAttribute('control', 'trackID'), '2')

end)
