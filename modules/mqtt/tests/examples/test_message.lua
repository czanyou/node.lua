local mqtt   = require('mqtt')
local assert = require('assert')

local TAG = "mqtt"

-- 主要测试了
-- 这个测试需要用到 MQTT 服务器

local url = 'mqtt://127.0.0.1:1883'
url = 'mqtt://iot.wotcloud.cn:1883'

local options = { clientId = 'wotc_34dac1400002_test' }
local client = mqtt.connect(url, options)
client.options.debugEnabled = true
client.options.keepalive = 4

local TOPIC1 = '/test-topic'
local TOPIC2 = '/test-topic/test'
local MESSAGE = string.rep('$', 1024 * math.random(1, 64))

-- connect
client:on('connect', function()
	console.log('@event - connect')

  	client:subscribe(TOPIC1, function(err, ack)
	  	if (err) then
		  	console.log(err)
			return
		end

	  	console.log('subscribe.ack')
	end)
end)

-- message
client:on('message', function (topic, message)
	console.log('@event - message', topic, #message)
 	assert.equal(topic, TOPIC1)

    local request = string.rep('$', 1024 * math.random(1, 64))
    local ret = client:publish(TOPIC1, request)
    console.log('@event - publish', ret and #ret)

  	print(TAG, "message is OK...")
end)

client:on('reconnect', function()
	console.log('@event - reconnect')
end)

client:on('close', function()
	console.log('@event - close')
end)

client:on('offline', function()
    console.log('@event - offline')
    process:exit(-1)
end)

client:on('error', function(errInfo)
	console.log('@event - error', errInfo)
end)

-- 测试 ping 事件
setTimeout(300, function()
    local ret = client:publish(TOPIC1, MESSAGE)
    console.log('@event - publish', ret and #ret)
end)
