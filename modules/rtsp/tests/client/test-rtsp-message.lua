local utils 	= require('util')
local assert 	= require('assert')
local tap 		= require('util/tap')

local message 	= require('rtsp/message')

local RtspMessage = message.RtspMessage

message.realm = '4419b727ab09'

describe("RtspMessage.header", function ()
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

describe("RtspMessage.newDateHeader", function ()
	console.log('Date', message.newDateHeader())
end)

describe("RtspMessage.parseAuthenticate", function ()
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

describe("RtspMessage.parseAuthenticate - Hikvision", function ()
	-- parseAuthenticate
	-- Authorization: Digest username="admin", realm="IP Camera(74220)", nonce="2a34bf00c96a7644665cb8afc10d0ca4", uri="rtsp://192.168.1.64:554/live.mp4", response="0d3b03a58fbe0205c0986880c30b3faf"\r\n
	local auth = 'Digest realm="IP Camera(74220)", nonce="ee805e9fa5eb5041a7ed57880834e653", stale="FALSE"'
	local params = message.parseAuthenticate(auth)
	--console.log('params', params)
	assert.equal(params.realm, 'IP Camera(74220)')
	assert.equal(params.nonce, 'ee805e9fa5eb5041a7ed57880834e653')
	assert.equal(params.stale, 'FALSE')
	assert.equal(params.METHOD, 'Digest')

	-- setAuthorization
	local request = RtspMessage:new()
	request.method = 'DESCRIBE'
	request.uriString = 'rtsp://192.168.1.64/live.mp4'
	request:setAuthorization(params, "admin", "admin123456")

	-- parseAuthenticate
	local value = request:getHeader('Authorization')
	params = message.parseAuthenticate(value)

	assert.equal(params.response, '62c99511d94419751cf29de2e9f66ac6')
end)


describe("RtspMessage.checkAuthorization", function()

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
