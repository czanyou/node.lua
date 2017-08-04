local utils = require('utils')
local mqtt  = require('mqtt')

local TAG = 'MQTT'

local MQTT_URL 			= 'mqtt://127.0.0.1:1883'
local MQTT_CLIENT_ID 	= "id1234"
local MQTT_EXIT			= 'exit'
local MQTT_TOPIC		= '/sensor'

-- 模拟一个 MQTT 客户端

local function main()
	local client = nil

	local callback = function(topic, payload)
		console.log(TAG, 'message', topic, payload)
		--console.printBuffer(payload)

		if (payload == MQTT_EXIT) then
			client:destroy()
		end
	end

	local options = { callback = callback, clientId = MQTT_CLIENT_ID }
	client = mqtt.connect(MQTT_URL, options)
	client.debugEnabled = true
	
	--console.log(client)

	client:on('connect', function(connack)
		console.log(TAG, 'event', 'connect')

		client:subscribe({ MQTT_TOPIC }, function(...)
			console.log('subscribe', ...)
		end)
	end)

	client:on('reconnect', function()
		console.log(TAG, 'event', 'reconnect')
	end)

	client:on('close', function()
		console.log(TAG, 'event', 'close')
	end)

	client:on('offline', function()
		console.log(TAG, 'event', 'offline')
	end)

	client:on('error', function(errInfo)
		console.log(TAG, 'event', 'error', errInfo)
	end)

	-- 推送测试消息
	setTimeout(100, function ()
		local PUB_TOPIC = '/data'
	  	print(TAG, "publish", PUB_TOPIC, 'test', 'qos=1')

	  	for i = 1, 10 do
	  	
		  	client:publish(PUB_TOPIC, 'test', { qos = 1 }, function(publish)
		  		console.log(TAG, 'publish', 'ACK', PUB_TOPIC, 'test', publish.messageId)
		  	end)

	    end
	end)

	-- 推送退出消息
	setTimeout(5000, function ()
	  	print(TAG, "publish", MQTT_TOPIC, MQTT_EXIT)
	  	
	  	client:publish(MQTT_TOPIC, MQTT_EXIT, function(err)
	  		--console.log(TAG, 'publish', 'exit')
	  	end)
	end)
end

main()
