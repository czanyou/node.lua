local codec 	= require('rtsp/codec')

local function test()
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

test_message = [[
DESCRIBE rtsp://foo/twister RTSP/1.0
CSeq: 1

RTSP/1.0 200 OK
CSeq: 1
Content-Type: application/sdp

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
    console.time('test')

	local rtspCodec = codec.newCodec()
	rtspCodec:on('request', function(request)
		--console.log('request', request)
	end)

	rtspCodec:on('response', function(response)
		--console.log('response', response)
	end)

	rtspCodec:on('packet', function(packet)
		--console.log('packet', packet)
    end)

    local startCode = 0x24
    local channel = 0
    local length = 0
    local packet1 = string.pack('>BBI2', startCode, channel, length)

    length = 1500
    local packet2 = string.pack('>BBI2', startCode, channel, length * 2)
    local packet3 = string.rep('n', length)
    local packet4 = string.rep('n', length)

    local message2 = "OPTIONS rtsp://foo/twister RTSP/1.0\r\nCSeq: 8\r\n\r\n"
    local message3 = "RTSP/1.0 200 OK\r\nCSeq: 8\r\n\r\n"
    local packet5 = string.pack('>BBI2', startCode, channel, 0)

    -- 1: 3000: 1500ms
    -- 2: 3000: 900ms
    -- 3: 10000: 3000ms
    for i = 1, 10000 do
        -- 测试 RTSP 流解析
        rtspCodec:decode(test_message)
        rtspCodec:decode(packet1)
        rtspCodec:decode(packet2)
        rtspCodec:decode(packet3)
        rtspCodec:decode(packet4)
        rtspCodec:decode(message2)
        rtspCodec:decode(message3)
        rtspCodec:decode(packet5)
    end

    console.timeEnd('test')
    console.log('count', rtspCodec.count)
end

test()

