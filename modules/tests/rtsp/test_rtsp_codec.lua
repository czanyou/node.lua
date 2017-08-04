local utils 	= require('utils')
local timer 	= require('timer')
local codec 	= require('rtsp/codec')
local core  	= require('core')
local assert 	= require('assert')
local tap 		= require('ext/tap')


return tap(function (test)

test("test codec.decodeNext", function ()
	local test_message = [[
PLAY / RTSP/1.0
Date: 2016

]]

	local rtspCodec = codec.newCodec()

	local request = rtspCodec:decodeNext(test_message)
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

test("test codec.decode", function ()
	local test_message = [[
PLAY / RTSP/1.0
CSeq: 1
Date: 2016

PLAY / RTSP/1.0
CSeq: 2
Date: 2016

]]

	local rtspCodec = codec.newCodec()
	--console.log(rtspCodec)
	rtspCodec:on('request', function(request)
		console.log('codec.decodeNext', 'request', request)
	end)

	rtspCodec:on('response', function(response)
		console.log('codec.decodeNext', 'response', response)
	end)

	rtspCodec:on('packet', function(packet)
		console.log('codec.decodeNext', 'packet', packet)
	end)

	-- 测试 RTSP 流解析
	rtspCodec:decode(test_message)
	rtspCodec:decode(string.pack('>BBI2', 0x24, 0, 0))
	rtspCodec:decode(string.pack('>BBI2I4', 0x24, 0, 4, 0))
	rtspCodec:decode("RTSP/1.0 200 OK\r\nCSeq: 2\r\n\r\n")
	rtspCodec:decode(string.pack('>BBB', 0x24, 0, 0))
end)

end)