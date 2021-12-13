local utils   = require('util')
local assert  = require('assert')
local mqtt    = require('mqtt')

local client = nil

-- 测试连接超时
-- 这个脚本主要测试服务器无法方便时，客户端是否会处理超时事件并重连

local callback = function(topic, payload)
	console.log('event message', topic, payload)
	--console.printBuffer(payload)

	if (payload == "exit") then
		client:destroy()
	end
end

local url = 'mqtt://192.168.1.1:4883'

local options = {callback = callback, clientId = "id1234"}
client = mqtt.connect(url, options)
client.debugEnabled   = true
client.connectTimeout = 2000

client:on('connect', function(connack)
	console.log('event - connect', connack)
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
	console.log('event - error', errInfo)
end)

print("start connect")

setTimeout(35000, function ()
  	--console.log("on timeout! ")
  	--client:destroy()
end)
