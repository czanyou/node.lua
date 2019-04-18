local utils 	= require('util')
local url 		= require('url')
local timer 	= require('timer')
local assert 	= require('assert')
local tap 		= require('ext/tap')

local message 	= require('rtsp/message')

local RtspMessage = message.RtspMessage

message.realm = '4419b727ab09'

return tap(function (test)

test("RtspMessage.header", function ()
	local request = RtspMessage:new()

	-- setHeader
	request:setHeader("Test", nil)
	request:setHeader("Test", "Foo")
	request:setHeader(nil, "Foo")
	request:setHeader("", "Foo")
	request:setHeader("list", {"Foo", "Bar"})

	-- getHeader
	assert.equal(request:getHeader(nil), nil)
	assert.equal(request:getHeader(""), "Foo")
	assert.equal(request:getHeader("test"), "Foo")
	assert.equal(request:getHeader("list"), "Foo")

	-- removeHeader
	request:removeHeader("list")
	assert.equal(request:getHeader("list"), nil)
end)

test("RtspMessage.newDateHeader", function ()
	console.log('Date', message.newDateHeader())
end)

test("RtspMessage.parseAuthenticate", function ()
	local auth = 'Digest realm="4419b727ab09", nonce="66bb9f0bf5ac93a909ac8e88877ae727", stale="FALSE", test=""'
	local params = message.parseAuthenticate(auth)
	--console.log('params', params)
	assert.equal(params.realm, '4419b727ab09')
	assert.equal(params.nonce, '66bb9f0bf5ac93a909ac8e88877ae727')
	assert.equal(params.stale, 'FALSE')
	assert.equal(params.test, '')
	assert.equal(params.METHOD, 'Digest')

	local request = RtspMessage:new()
	request.method = 'DESCRIBE'
	request.uriString = 'rtsp://192.168.1.145:554/MPEG-4/ch2/main/av_stream'
	request:setAuthorization(params, "admin", "12345")

	local value = request:getHeader('Authorization')
	--console.log('Authorization', value)

	params = message.parseAuthenticate(value)
	assert.equal(params.response, '108084646408d21aa255664781c886fc')
end)

test("RtspMessage.checkAuthorization", function()

	local request = RtspMessage:new()
	request.method = 'DESCRIBE'
	request.uriString = 'rtsp://192.168.1.145:554/MPEG-4/ch2/main/av_stream'

	local response = RtspMessage:new()
	response:checkAuthorization(request, function() end)

	-- 
	local value = response:getHeader('WWW-Authenticate')
	local params = message.parseAuthenticate(value)
	assert.equal(params.realm, '4419b727ab09')
	assert.equal(params.nonce, '66bb9f0bf5ac93a909ac8e88877ae727')
	assert.equal(params.stale, 'FALSE')
	assert.equal(params.METHOD, 'Digest')
	--console.log('response', response)

	-- auth
	request:setAuthorization(params, "admin", "12345")
	--local value = request:getHeader('Authorization')
	--console.log('Authorization', value)

	-- no
	response:checkAuthorization(request, function(username) 
		return '123456' 
	end)
	assert.equal(response.statusCode, 401)

	-- yes
	response:checkAuthorization(request, function(username) 
		return '12345' 
	end)
	assert.equal(response.statusCode, 200)

end)

end)