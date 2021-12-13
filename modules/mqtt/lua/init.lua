--[[

Copyright 2016-2020 The Node.lua Authors. All Rights Reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS-IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

--]]
local url   = require('url')

local mqtt   = require('mqtt/mqtt')
local packet = require('mqtt/packet')

local Packet = packet.Packet

-------------------------------------------------------------------------------
-- exports

local exports = {}

exports.DEFAULT_PORT    = 1883
exports.KEEP_ALIVE_TIME = 60     -- seconds (maximum is 65535)

-------------------------------------------------------------------------------
-- Client

---@class MQTTClient
---@field connected boolean set to true if the client is connected. false otherwise.
---@field reconnecting boolean set to true if the client is trying to reconnect to the server. false otherwise.
-- Client automatically handles the following:
-- - Regular server pings
-- - QoS flow
-- - Automatic reconnections
-- - Start publishing before being connected
local Client = mqtt.MQTTSocket:extend()
exports.Client = Client

function Client:connect()
    if (self.connected) then
        self:_onDebug("Already connected")
        return

    elseif (self.connectAckTimer) then
        self:_onDebug("Already connecting...")
        return
    end

    if (not self.keepAliveTimer) then
        self.keepAliveTimer = setInterval(1000, function()
            self._checkKeepAlive(self)
        end)
    end

    self.destroyed = false
    return self:_onConnect()
end

-- 销毁这个客户端
-- @param {number} force
-- @param {function} callback
function Client:destroy(force, callback)
    return self:close(force, callback)
end

-- 发布消息 `data` 到指定的主题 `topic`
--
---@param topic string 要发布的主题
---@param data string 要发布的数据
---@param options table 发布选项
-- - qos integer default 0, QoS 服务质量级别
-- - retain boolean retain flag, default false
-- - dup boolean default false, 是否将消息标记为是重发的数据
---@param callback function(err) 当发送成功或失败时被调用
---@return table
---@return string error
function Client:publish(topic, data, options, callback)
    -- publish(topic, data, callback)
    if (type(options) == 'function') then
        callback = options
        options  = nil
    end

    -- console.log('publish', options)
    if (not self.connected) then
        if (callback) then callback() end
        return
    end

    if (options == nil) then
        options = { qos = 0, retain = false, dup = false }
    end

    -- bytes 1,2: Fixed message header, see MQTTSocket:_sendMessage()
    -- Variable header ..
    -- bytes 3- : Topic name and optional Message Identifier (if QOS > 0)
    -- bytes m- : Payload

    local message = Packet:new(packet.TYPE_PUBLISH)

    if (options.qos) and (options.qos > 0) then
        -- 当 (QoS > 0) 时，必须等待 ACK 消息
        local messageId = self:_nextMessageId()
        message.messageId = messageId

        self:outgoingStore(messageId, {
            message   = "publish",
            topic     = topic,
            messageId = messageId,
            dup       = options.dup,
            qos       = options.qos,
            retain    = options.retain,
            payload   = data,
            callback  = callback
        })

        message.qos = options.qos
        return self:_sendMQTTPacket(message, nil, topic, data)

    else
        return self:_sendMQTTPacket(message, callback, topic, data)
    end
end

-- Subscribe to a topic or topics
---@param topics string|string[]|table topic or an array of topics to subscribe to
---@param options table is the options to subscribe with, including:
--    * `qos` qos subscription level, default 0
---@param callback function(err, granted) fired on suback
function Client:subscribe(topics, options, callback)
    self:_checkConnected('subscribe')

    -- subscribe(topics, callback)
    if (type(options) == 'function') then
        callback = options
        options  = nil
    end

    if (type(topics) == 'string') then
        topics = { topics }
    end

    -- bytes 1,2: Fixed message header, see _sendMessage
    -- Variable header ..
    -- bytes 3,4: Message Identifier
    -- bytes 5- : List of topic names and their QOS level
    --
    local messageId = self:_nextMessageId()

    self:outgoingStore(messageId, {
        message   = "subscribe",
        messageId = messageId,
        topics    = topics,
        callback  = callback
    })

    local message = Packet:new(packet.TYPE_SUBSCRIBE)
    message.messageId = messageId

    return self:_sendMQTTPacket(message, nil, topics)
end

-- Unsubscribe from a topic or topics
---@param topics string|string[] topic or an array of topics to unsubscribe from
---@param options table options of unsubscribe
---@param callback function(err) fired on unsuback. An error occurs if client is disconnecting.
function Client:unsubscribe(topics, options, callback)
    self:_checkConnected('unsubscribe')

    -- unsubscribe(topics, callback)
    if (type(options) == 'function') then
        callback = options
        options  = nil
    end

    if (type(topics) == 'string') then
        topics = { topics }
    end

    -- bytes 1,2: Fixed message header, see MQTTSocket:_sendMessage()
    -- Variable header ..
    -- bytes 3,4: Message Identifier
    -- bytes 5- : List of topic names
    --
    local messageId = self:_nextMessageId()
    self:outgoingStore(messageId, {
        message   = "unsubscribe",
        messageId = messageId,
        topics    = topics,
        callback  = callback
    })

    local message = Packet:new(packet.TYPE_UNSUBSCRIBE)
    message.messageId = messageId

    return self:_sendMQTTPacket(message, nil, topics)
end

-------------------------------------------------------------------------------
-- exports

-- Connects to the broker specified by the given url and options and returns
-- a Client.
---@param urlString string
---@param options table
-- - callback function:  function, Invoked when subscribed topic messages received
-- - clean boolean: `true`, set to false to receive QoS 1 and 2 messages while offline
-- - clientId string: `'mqttjs_' + Math.random().toString(16).substr(2, 8)`
-- - connectTimeout integer: `30 * 1000` milliseconds, time to wait before a CONNACK is received
-- - hostname string: Host name or address of the MQTT broker
-- - incomingStore table: a [Store](#store) for the incoming packets
-- - keepalive integer: `60` seconds, set to `0` to disable
-- - outgoingStore table: a [Store](#store) for the outgoing packets
-- - password string: the password required by your broker, if any
-- - protocol string: 'mqtt'
-- - reconnectPeriod integer: 1000 milliseconds, interval between two reconnections
-- - servers url[]: servers
-- - username string: the username required by your broker, if any
-- @returns MQTTClient
function exports.connect(urlString, options)
    if (type(urlString) == 'string') then
        if (type(options) ~= 'table') then
            options = {}
        end

        local urlObject  = url.parse(urlString) or {}
        options.servers = { urlObject }

    -- connect(options)
    elseif (type(urlString) == 'table') then
        options = urlString
        urlString = nil
    end

    if (type(options) ~= 'table') then
        options = {}
    end

    local client = Client:new(options)
    client:connect()

    return client
end

return exports
