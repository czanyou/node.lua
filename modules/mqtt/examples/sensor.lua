local mqtt   = require('mqtt')
local assert = require('assert')

local TAG = "mqtt"

--local client = mqtt.connect('mqtt://test.mosquitto.org')
--local client = mqtt.connect('mqtt://192.168.77.108:1883')

-- 这个客户端先订阅 /test-topic, 然后再向这个主题发消息, 最后收到自己推送的消息后退出进程
-- 主要测试了 connect, subscribe, publish 这几个方法
-- 这个测试需要用到 MQTT 服务器

local url = 'mqtt://127.0.0.1:1883'
local url = 'mqtt://iot.beaconice.cn:1883'

local client = mqtt.connect(url)

local MESSAGES_TOPIC = 'messages/test'
local ACTIONS_TOPIC = 'actions/test'

local MESSAGE = 'Hello mqtt'

client:on('connect', function()
    client:subscribe(ACTIONS_TOPIC)
    client:subscribe(MESSAGES_TOPIC)

  	setInterval(1000, function()
  		client:publish(MESSAGES_TOPIC, MESSAGE)
  	end)
end)

client:on('message', function (topic, message)
 	print(TAG, 'message', topic, message)

end)

client:on('error', function(errInfo)
	print(TAG, 'event', 'error', errInfo)
end)

