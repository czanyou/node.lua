local mqtt   = require('mqtt')
local assert = require('assert')

local TAG = "mqtt"

-- 主要测试了 ping 这几个方法
-- 这个测试需要用到 MQTT 服务器

local url = 'mqtt://127.0.0.1:1883'
local url = 'mqtt://iot.wotcloud.cn:1883'

local options = { clientId = 'wotc_34dac1400002_test' }
local client = mqtt.connect(url, options)
client.options.debugEnabled = true
client.options.keepalive = 4

local TOPIC = '/test-topic'
local MESSAGE = 'Hello mqtt'

-- connect
client:on('connect', function()
	console.log('@event - connect')

  	client:subscribe(TOPIC, function(err, ack)
	  	if (err) then
		  	console.log(err)
			return
		end

	  	console.log('subscribe.ack')
	end)
end)

-- message
client:on('message', function (topic, message)
	console.log('@event - message', topic, message)
 	assert.equal(topic, TOPIC)
 	assert.equal(message, MESSAGE)
  	client:close()

  	print(TAG, "message is OK, auto exit...")
end)

client:on('reconnect', function()
	console.log('@event - reconnect')
end)

client:on('close', function()
	console.log('@event - close')
end)

client:on('offline', function()
	console.log('@event - offline')
end)

client:on('error', function(errInfo)
	console.log('@event - error', errInfo)
end)

-- 测试 ping 事件
setInterval(3000, function()
	--console.log('state = ', client.state)
	local now = process.now()

	local state = client.state
	local lastActivityPing 	= state.lastActivityPing or 0
	local lastActivityIn 	= state.lastActivityIn or 0

	if (client.connected) then
		local intervalIn = now - lastActivityIn
		local intervalPing = now - lastActivityPing

		console.log('intervalIn, intervalPing', intervalIn, intervalPing)
	end
end)
