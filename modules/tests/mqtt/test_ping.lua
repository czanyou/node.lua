local mqtt   = require('mqtt')
local assert = require('assert')

local TAG = "mqtt"

-- 这个客户端先订阅 /test-topic, 然后再向这个主题发消息, 最后收到自己推送的消息后退出进程
-- 主要测试了 connect, subscribe, publish 这几个方法
-- 这个测试需要用到 MQTT 服务器

local url = 'mqtt://127.0.0.1:1883'
local client = mqtt.connect(url)
client.options.debugEnabled = true
client.options.keepalive = 4

local TOPIC = '/test-topic'
local MESSAGE = 'Hello mqtt'

client:on('connect', function()
	print(TAG, 'event - connect')

  	client:subscribe(TOPIC, function(err, ack)
	  	if (err) then 
		  	console.log(err)
			return
		end

	  	console.log('ack', ack)
	end)
end)

client:on('message', function (topic, message)
 	print(TAG, 'message', topic, message)
 	assert.equal(topic, TOPIC)
 	assert.equal(message, MESSAGE)
  	client:close()

  	print(TAG, "message is OK, auto exit...")
end)

client:on('reconnect', function()
	console.log('event - reconnect')
end)

client:on('close', function()
	console.log('event - close')
end)

client:on('offline', function()
	console.log('event - offline')
end)

client:on('error', function(errInfo)
	print(TAG, 'event - error', errInfo)
end)

setInterval(3000, function()
	--console.log('state = ', client.state)
	local now = process.now()
	local lastActivityPing 	= client.state.lastActivityPing or 0
	local lastActivityIn 	= client.state.lastActivityIn or 0

	if (client.connected) then
		local intervalIn = now - lastActivityIn
		local intervalPing = now - lastActivityPing

		console.log(intervalIn, intervalPing)
	end
end)

