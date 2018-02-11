local utils   = require('utils')
local timer   = require('timer')
local assert  = require('assert')
local tap     = require('ext/tap')

local packet = require('mqtt/packet')
local Packet = packet.Packet

tap(function(test)


test('test parse message length', function()
	local Packet = Packet
	
	-- message length
	local data = string.char( 0x00, 0x7f, 0x00, 0x00, 0x00 )
	assert.equal(127, packet.parseLength(data, 2))

	local data = string.char( 0x00, 0x80, 0x01, 0x00, 0x00 )
	assert.equal(128, packet.parseLength(data, 2))

	local data = string.char( 0x00, 0x80, 0x80, 0x01, 0x00 )
	assert.equal(16384, packet.parseLength(data, 2))

	local data = string.char( 0x00, 0x80, 0x80, 0x80, 0x01 )
	assert.equal(2097152, packet.parseLength(data, 2))
end)

test('test parse message', function()

	-- PUBACK with message ID
	local message = Packet:new()
	local messageData = string.pack('>I2', 1345)
	local messageType = packet.TYPE_PUBACK << 4
	message:parse(messageType, #messageData, messageData)
	assert.equal(message.messageId, 1345)

	-- CONACK with return code
	local message = Packet:new()
	local messageData = string.pack('>BB', 0, 5)
	local messageType = packet.TYPE_CONACK << 4
	message:parse(messageType, #messageData, messageData)
	assert.equal(message.returnCode, 5)
	assert.equal(message.errorMessage, 'Not authorized')

	-- PUBLISH
	local message = Packet:new()
	local messageData = string.pack('>I2BBBBI2BBBB', 4,  65, 66, 67, 68,  444,  77, 77, 77, 78)
	local messageType = (packet.TYPE_PUBLISH << 4) + (packet.QOS_1 << 1) -- QOS = 1
	message:parse(messageType, #messageData, messageData)
	--console.log(message)
	assert.equal(message.messageId, 444)
	assert.equal(message.qos, 1)
	assert.equal(message.payload, 'MMMN')
	assert.equal(message.topic, 'ABCD')

end)

test('test parseString', function()
	local message = Packet:new()
	message:parseString()
	assert.equal(message:parseString(''), nil)
	assert.equal(message:parseString('', 1), nil)
	assert.equal(message:parseString('12', 1), nil)

	local ret, offset = message:parseString(string.char(0, 4, 66, 67, 68, 69))
	assert.equal(ret, 'BCDE')
	assert.equal(offset, 7)

end)

test('Packet:encodeString', function()
	local message = Packet:new()
	local list = {}

	message:encodeString(list, nil)
	message:encodeString(list, 100)
	message:encodeString(list, "")
	message:encodeString(list, "test")

	assert.equal(#list, 4)
	assert.equal(string.unpack('>I2', list[1]), 3) -- 100
	assert.equal(string.unpack('>I2', list[3]), 4) -- test
	--console.log(list)

	local value, offset = message:parseString(table.concat(list), 1)
	assert.equal(value, '100')
	assert.equal(offset, 6)

	local value, offset = message:parseString(table.concat(list), offset)
	assert.equal(value, 'test')
	assert.equal(offset, 12)
	--console.log(value, offset)

	-- packet.encodeString
	local ret = packet.encodeString('test')
	local value, offset = message:parseString(ret, 1)
	assert.equal(value, 'test')
	assert.equal(offset, 7)
end)

test('Packet:encodeLength', function()
	local message = Packet:new()
	local list = {}	

	message:encodeLength(list, -1)
	assert.equal(#list, 0)

	message:encodeLength(list, 0)
	assert.equal(#list, 1)
	assert.equal(list[1]:byte(1), 0)
	--console.log(list)

	local list = {}	
	message:encodeLength(list, 100)
	assert.equal(#list, 1)
	assert.equal(list[1]:byte(1), 100)

	local list = {}	
	message:encodeLength(list, 0x7f)
	assert.equal(list[1]:byte(1), 0x7f)

	-- 0x80 => 0x01 0x80
	local list = {}	
	message:encodeLength(list, 0x80)
	assert.equal(#list, 2)
	assert.equal(list[1]:byte(1), 0x80)
	assert.equal(list[2]:byte(1), 0x01)
	--console.log(list)
end)

test('Packet:parseHeader', function()
	local message = Packet:new()
	message:parseHeader(0xff)

	--console.log(message)

end)

test('Packet:build and packet.parse TYPE_CONNECT', function()
	local message = Packet:new()
    message.messageType = packet.TYPE_CONNECT
    message.will        = { topic = "test", message = "fun"}
    message.clientId    = 'test'
    message.username    = "admin"
    message.password    = "888888"
    message.keepalive   = 90

    local messageData = message:build()
	print('encoded MQTT message:')
    console.printBuffer(messageData)

	local connect = packet.parse(messageData)
	--console.log(connect)

	assert.equal(connect.messageType, packet.TYPE_CONNECT)
	assert.equal(connect.keepalive, 90)
	assert.equal(connect.clientId, 'test')
	assert.equal(connect.username, 'admin')	
	assert.equal(connect.password, '888888')	

	assert.equal(connect.will.topic, 'test')	
	assert.equal(connect.will.message, 'fun')	
end)

test('Packet:build and packet.parse TYPE_PUBLISH', function()
	local topic = '/test'
	local data  = 'test'

	-- 
	local message = Packet:new()
	message.messageType = packet.TYPE_PUBLISH
	local ret = message:build(topic, data)
	console.printBuffer(ret)

	-- 
	local message2 = packet.parse(ret)
	--console.log(message2)

	assert.equal(message2.topic, 	'/test')
	assert.equal(message2.payload,  'test')
	assert.equal(message2.messageType, packet.TYPE_PUBLISH)
end)

test('Packet:build and packet.parse TYPE_CONACK', function()
	local topic = '/test'
	local data  = 'test'

	-- 
	local message = Packet:new()
	message.messageType = packet.TYPE_CONACK
	local ret = message:build(1)
	console.printBuffer(ret)

	-- 
	local message2 = packet.parse(ret)
	--console.log(message2)

	assert.equal(message2.messageType, packet.TYPE_CONACK)
end)

end)