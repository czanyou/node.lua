local codec 	= require('rtsp/codec')
local assert 	= require('assert')
local tap 		= require('util/tap')

describe("test codec.decodeNext", function ()
	local test_message = [[
PLAY / RTSP/1.0
Date: 2016

]]

	local rtspCodec = codec.newCodec()

	local request = rtspCodec:_decodeNext(test_message)
	console.log(request)

	assert(request ~= nil)
	assert(request.method == 'PLAY')
	assert(request.path == '/')
	assert(request.version == 1.0)
	assert.equal(request:getHeader("Date"), '2016')
	
	local output = rtspCodec:encode(request)
	assert.equal(output, 'PLAY / RTSP/1.0\r\nDate: 2016\r\n\r\n')
	--console.log(output)
end)

describe("test codec.decode", function ()
	local test_message = [[
DESCRIBE rtsp://foo/twister RTSP/1.0
CSeq: 1

RTSP/1.0 200 OK
CSeq: 1
Content-Type: application/sdp
Content-Length: 246

v=0
o=- 2890844256 2890842807 IN IP4 172.16.2.93
s=RTSP Session
i=An Example of RTSP Session Usage
a=control:rtsp://foo/twister
t=0 0
m=audio 0 RTP/AVP 0
a=control:rtsp://foo/twister/audio
m=video 0 RTP/AVP 26
a=control:rtsp://foo/twister/video

SETUP rtsp://foo/twister/audio RTSP/1.0
CSeq: 2
Transport: RTP/AVP;unicast;client_port=8000-8001

RTSP/1.0 200 OK
CSeq: 2
Transport: RTP/AVP;unicast;client_port=8000-8001;server_port=9000-9001
Session: 12345678

SETUP rtsp://foo/twister/video RTSP/1.0
CSeq: 3
Transport: RTP/AVP;unicast;client_port=8002-8003
Session: 12345678

RTSP/1.0 200 OK
CSeq: 3
Transport: RTP/AVP;unicast;client_port=8002-8003;server_port=9004-9005
Session: 12345678

PLAY rtsp://foo/twister RTSP/1.0
CSeq: 4
Range: npt=0-
Session: 12345678

RTSP/1.0 200 OK
CSeq: 4
Session: 12345678
RTP-Info: url=rtsp://foo/twister/video;seq=9810092;rtptime=3450012

PAUSE rtsp://foo/twister/video RTSP/1.0
CSeq: 5
Session: 12345678

RTSP/1.0 460 Only aggregate operation allowed
CSeq: 5

PAUSE rtsp://foo/twister RTSP/1.0
CSeq: 6
Session: 12345678

RTSP/1.0 200 OK
CSeq: 6
Session: 12345678

SETUP rtsp://foo/twister RTSP/1.0
CSeq: 7
Transport: RTP/AVP;unicast;client_port=10000

RTSP/1.0 459 Aggregate operation not allowed
CSeq: 7

]]

	local rtspCodec = codec.newCodec()
	--console.log(rtspCodec)
	rtspCodec:on('request', function(request)
		console.log('codec.decode', 'request', request)
	end)

	rtspCodec:on('response', function(response)
		console.log('codec.decode', 'response', response)
	end)

	rtspCodec:on('packet', function(packet)
		console.log('codec.decode', 'packet', packet)
	end)

	-- 测试 RTSP 流解析
	rtspCodec:decode(test_message)
	rtspCodec:decode(string.pack('>BBI2', 0x24, 0, 0))
	rtspCodec:decode(string.pack('>BBI2I4', 0x24, 0, 4, 0))
	rtspCodec:decode("RTSP/1.0 200 OK\r\nCSeq: 2\r\n\r\n")
	rtspCodec:decode(string.pack('>BBI2', 0x24, 0, 0))
end)
