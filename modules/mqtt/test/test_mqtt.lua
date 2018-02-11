local utils   = require('utils')
local timer   = require('timer')
local assert  = require('assert')
local tap     = require('ext/tap')

local mqtt    = require('mqtt')
local packet  = require('mqtt/packet')

local Packet = packet.Packet

tap(function(test)

test('test_mqtt_publish', function()
	function onMessage(topic, payload)
		print('message', topic)
		--console.printBuffer(payload)
	end

	local client = mqtt.connect()

	-- publish
	client.debugEnabled = true
	client.connectReady = true
	client.connected 	= true
	client.callback 	= onMessage

	-- test_short_message
	local topic = 'test_short_message'
	local payload = "1234"
	local mqttMessage = client:publish(topic, payload)
	if (not mqttMessage) then
		console.log(client)
		return
	end

	local publish = packet.parse(mqttMessage)
	assert.equal(0, publish.qos)
	assert.equal(topic, publish.topic)
	assert.equal(payload, publish.payload)

	-- 
	local topic = 'test_long_message'
	local payload = string.rep('T', 255)
	local mqttMessage = client:publish(topic, payload, { qos = 1 })
	local publish = packet.parse(mqttMessage)

	assert.equal(1, publish.qos)
	assert.equal(topic, publish.topic)
	assert.equal(payload, publish.payload)
end)

test('test_mqtt_subscribe', function()
	local client = mqtt.connect()

	-- publish
	client.debugEnabled = true
	client.connectReady = true
	client.connected 	= true

	-- subscribe
	function onSubscribeACK(message)
		console.log('onSubscribeACK', message.messageId)
	end

	client.connected = true
	local mqttMessage = client:subscribe({'topic/a', 'topic/b'}, onSubscribeACK)
	local subscribe = packet.parse(mqttMessage)
	console.log(subscribe)

	--console.printBuffer(subscribe)
	--console.log(client.outgoingStore)

	local message = Packet:new()
	message.messageType 	= packet.TYPE_SUBSCRIBE
	message.messageId 		= client.messageId
	message.messageLength 	= 4
	client:_handleSubscribeACK(message)

	-- unsubscribe
	function onUnsubscribeACK()
		console.log('onUnsubscribeACK')
	end

	client.connected = true
	local mqttMessage = client:unsubscribe({'topic/a', 'topic/b'}, onUnsubscribeACK)
	local unsubscribe = packet.parse(mqttMessage)
	console.log(unsubscribe)	
	--console.printBuffer(unsubscribe)	

	local message = Packet:new()
	message.messageType 	= packet.TYPE_UNSUBSCRIBE
	message.messageId 		= client.messageId
	message.messageLength 	= 2	
	client:_handleUnsubscribeACK(message)
end)


test('test_mqtt_publish_qos1', function()
	function onMessage(topic, payload)
		print('message', topic)
	end

	local client = mqtt.connect()

	-- publish
	client.debugEnabled = true
	client.connectReady = true
	client.connected 	= true
	client.callback 	= onMessage

	client:publish('/test', '1234', {}, function(result)
		console.log('callback qos 0', result)
	end)

	--console.log(client.outgoingStore)
	client:publish('/test', '1234', { qos = 1 }, function(result)
		console.log('callback qos 1', result)
	end)

	--console.log(client.outgoingStore)
	--client:close()

	local message = Packet:new()
	message.messageType = packet.TYPE_PUBACK
	message.messageId  = 1
	client:handleMessage(message)

	--console.log(client.outgoingStore)
end)


end)
