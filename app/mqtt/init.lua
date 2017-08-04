local app   = require('app')
local mqtt  = require('mqtt')
local rpc   = require('ext/rpc')
local utils = require('utils')

local IOT_MQTT_URL  = 'mqtt://iot.sae-sz.com:1883'
local IPC_PORT      = 'rpc-mqtt'
local TAG           = 'mqtt'

function rpc_result(err, result)
    if (err) then
        console.log(err)
    elseif (result) then
        console.log(result)
    end
end

-------------------------------------------------------------------------------
-- MQTT 消息路由应用
-- ======
-- 这个应用创建一个 MQTT 客户端和 MQTT 服务器通信, 即当前设备都通过当前应用来进行 MQTT
-- 通信, 一个设备只需维护一个 MQTT 连接
-- 其他 APP 通过 IPC 和当前应用通信, 由当前应用来转发 MQTT 消息

-- 参数:
-- ======
-- IPC_PORT:        39901
-- IOT_MQTT_URL:    'mqtt://iot.sae-sz.com:1883'

-------------------------------------------------------------------------------
-- client

local client = {}

client.mqttUrl          = IOT_MQTT_URL
client.subscribes       = {}
client.topics           = {}
client.publishList      = {}
client.deviceId         = nil

function client.newSubscribeId()
    client._subscribeIndex = (client._subscribeIndex or 0) + 1
    return os.time() .. "-" .. client._subscribeIndex
end

function client.onMessage(topic, payload)
    console.log(TAG, 'message', topic, payload)

    local subscribe = client.topics[topic]
    if (subscribe) then
        rpc.call(subscribe.url, 'notify', {topic, payload})
    end
end

function client.onConnect(connack)
    local mqttClient = client.mqttClient
    console.log(TAG, 'event - online', mqttClient.state.address)

    -- [[
    local topic = '/device/' .. tostring(client.deviceId)
    mqttClient:subscribe(topic, function(err) 
        console.log('subscribed', topic, err)
    end)
    --]]
end 

function client.onTimer()
    local mqttClient = client.mqttClient
    if (not mqttClient.connected) then
        return
    end

    for topic, subscribe in pairs(client.topics) do
        --local topic = subscribe.topic
        mqttClient:subscribe(topic, function(err)
            if (not err) then
                subscribe.timestamp = process.now()
                console.log('subscribed', topic, err)
            end
        end)
    end

    local topic = '/device/' .. client.deviceId
    mqttClient:subscribe(topic, function(err) 
        console.log('subscribed', topic, err)
    end)
end

function client.publish(topic, data, qos, callback)
    local mqttClient = client.mqttClient
    local options = { qos = tonumber(qos) or 0 }
    mqttClient:publish(topic, data, options, function(err)
        if (callback) then
            callback(err)
        end
    end)
end

function client.start()
    local options = { 
        callback = client.onMessage, 
        clientId = client.clientId 
    }

	local mqttClient = mqtt.connect(client.mqttUrl, options)
    client.mqttClient = mqttClient
	mqttClient.debugEnabled = true

    mqttClient:on('offline', function()
        console.log(TAG, 'event - offline')
    end)
    
   	mqttClient:on('connect', client.onConnect)
	mqttClient:on('error', function(errInfo)
		console.log(TAG, 'event - error', errInfo)
	end)

    local interval = 1000 * 60 * 1
    client.keepTimer = setInterval(interval, client.onTimer)
end

function client.status()
    local options = {}
    for k, v in pairs(client.mqttClient.options) do
        options[k] = tostring(v)
    end

    local subscribes = {}
    for k, v in pairs(client.topics) do
        table.insert(subscribes, v)
    end

    return {
        options = options,
        subscribes = subscribes,
        state = client.mqttClient.state
    }
end

function client.subscribe(topic, sid, url)
    sid = sid or client.newSubscribeId()

    -- 清除过时的 subscribe 会话
    local subscribe = client.topics[topic]
    if (subscribe and subscribe.sid ~= sid) then
        client.subscribes[sid] = nil
        client.topics[topic]   = nil
    end

    for id, item in pairs(client.subscribes) do
        if (item.topic == topic) and (sid ~= id) then
            client.subscribes[id] = nil
        end
    end

    -- 
    local subscribe = client.subscribes[sid]
    if (subscribe) then
        return
    end

    -- 创建新的 subscribe 会话
    subscribe = {
        sid = sid, topic = topic, url = url
    }

    client.subscribes[sid] = subscribe
    client.topics[topic]   = subscribe

    local mqttClient = client.mqttClient
    mqttClient:subscribe(topic, function(err)
        if (not err) then
            subscribe.timestamp = process.now()
        end
    end)
end

function client.unsubscribe(topic, sid)
    local subscribe = client.topics[topic]
    if (not subscribe) and (sid) then
        subscribe = client.subscribes[sid]
    end

    if (subscribe) then
        client.subscribes[sid or subscribe.sid] = nil
        client.topics[topic or subscribe.topic] = nil
    end

    local mqttClient = client.mqttClient
    mqttClient:unsubscribe(topic, function(err)

    end)
end

-------------------------------------------------------------------------------
-- exports

local exports = {}

function exports.conf()

end

function exports.help()
    app.usage(utils.dirname())
end

function exports.publish(self, topic, data, qos)
    if (type(self) == 'table') then
        console.log('publish', topic, data, qos)
        client.publish(topic, data, qos, rpc_result)

    else
        local usage = '\nlpm mqtt publish <topic> <data> [qos]\n'
        -- publish(topic, data, qos)
        qos = data; data = topic; topic = self; self = nil; 
        if (not topic) then
            print(usage, '\ntopic expected!\n')
            return

        elseif (not data) then
            print(usage, '\ndata expected!\n')
            return           
        end

        local args = { topic, data, qos }
        rpc.call(IPC_PORT, 'publish', args, rpc_result)
    end
end

function exports.start(url, uid)
    client.deviceId = uid or app.get('device.deviceId') or 'test'
    client.mqttUrl  = url or app.get('mqtt.url') or IOT_MQTT_URL

    print("start: uid=" .. client.deviceId .. ', url=' .. client.mqttUrl)
    client.start()

    local rpc = require('ext/rpc')
    local server = rpc.server(IPC_PORT, exports)
    exports._rpcServer = server

    return server
end

function exports.stop()
    os.execute('lpm kill mqtt')
end

function exports.status(self)
    if (type(self) == 'table') then
        if (client) then
            return client.status()
        end

    else
        rpc.call(IPC_PORT, 'status', {}, function(err, result)
            if (type(result) == 'table') then
                local now = process.now()
                local state = result.state or {}
                state.lastActivityIn  = (now - (state.lastActivityIn  or 0)) // 1000
                state.lastActivityOut = (now - (state.lastActivityOut or 0)) // 1000
                state.lastConnectTime = (now - (state.lastConnectTime or 0)) // 1000
            
                result.now = process.now()
            end

            console.log('status', err, result)
        end)
    end
end

function exports.subscribe(self, topic, sid, url)
    if (type(self) == 'table') then
        if (sid and #sid <= 0) then
            sid = nil
        end

        url = math.floor(url)

        console.log('subscribe', topic, sid, url)
        client.subscribe(topic, sid, url, function()
            
        end)

    else
        local usage = '\nusage: lpm mqtt subscribe <topic> <sid> <url>'
        -- subscribe(topic, sid, url)
        url = sid; sid = topic; topic = self; self = nil;
        if (not topic) then
            print(usage, '\ntopic expected!\n')
            return

        elseif (not url) then
            print(usage, '\nurl expected!\n')
            return
        end

        local rpc = require('ext/rpc')
        rpc.call(IPC_PORT, 'subscribe', {topic, sid, url}, rpc_result)
    end
end

function exports.unsubscribe(self, topic, sid)
    if (type(self) == 'table') then
        console.log('unsubscribe', topic, sid)
        client.unsubscribe(topic, sid, function()
        
        end)

    else
        -- unsubscribe(topic, sid)
        sid = topic; topic = self; self = nil;
        local rpc = require('ext/rpc')
        rpc.call(IPC_PORT, 'unsubscribe', {topic, sid}, rpc_result)
    end
end

app(exports)
