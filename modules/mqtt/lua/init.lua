--[[

Copyright 2016 The Node.lua Authors. All Rights Reserved.

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

local Client = mqtt.MQTTSocket:extend()
exports.Client = Client

--[[
-- Transmit MQTT MQTTSocket request a connection to an MQTT broker (server)
-- return: nil or error message
--]]
function Client:connect()
    if (self.socketConnected) then
        self:_onDebug("Already connected")
        return

    elseif (self.connected) then
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
    return self:_onStartConnect()
end

-- 销毁这个客户端
-- @param {number} force
-- @param {function} callback
function Client:destroy(force, callback)
    return self:close(force, callback)
end

-- Transmit MQTT Publish message
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- MQTT 3.1 Specification: Section 3.3: Publish message
--
-- @param {string} topic 要发布的主题
-- @param {string} data 要发布的数据
-- @param {object} options 发布选项
-- - {number} qos
-- - {boolean} retain
-- @param {function} callback fired on suback
function Client:publish(topic, data, options, callback)
    if not self:_checkConnected('publish', callback) then
        return
    end

    -- publish(topic, data, callback)
    if (type(options) == 'function') then
        callback = options
        options  = nil
    end

    if (options == nil) then
        options = { qos = 0, retain = false }
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
            callback  = callback
        })

        message.qos = options.qos
        return self:_sendMQTTPacket(message, nil, topic, data)

    else
        return self:_sendMQTTPacket(message, callback, topic, data)
    end
end

-- Transmit MQTT Subscribe message
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- MQTT 3.1 Specification: Section 3.8: Subscribe to named topics
--
-- @param {string[]} topics table of strings
-- @param {object} options is the options to subscribe with, including:
--    * `qos` qos subscription level, default 0
-- @param {function} callback fired on suback
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
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

-- Transmit MQTT Unsubscribe message
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- MQTT 3.1 Specification: Section 3.10: Unsubscribe from named topics
--
-- @param {string[]} topics table of strings
-- @param {function} callback fired on unsuback
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

--[[
-- Connects to the broker specified by the given url and options and returns
-- a Client.
@param {string} urlString
@param {object} options
- {function} `callback`:  function, Invoked when subscribed topic messages received
- {boolean} `clean`: `true`, set to false to receive QoS 1 and 2 messages while offline
- {string} `clientId`:  `'mqttjs_' + Math.random().toString(16).substr(2, 8)`
- {number} `connectTimeout`: `15 * 1000` milliseconds, time to wait before a CONNACK is received
- {string} `hostname`:  string, Host name or address of the MQTT broker
- {object} `incomingStore`: a [Store](#store) for the incoming packets
- {number} `keepalive`: `10` seconds, set to `0` to disable
- {object} `outgoingStore`: a [Store](#store) for the outgoing packets
- {string} `password`: the password required by your broker, if any
- {number} `port`: integer, Port number of the MQTT broker (default: 1883)
- {string} `protocol`: 'mqtt'
- {number} `reconnectPeriod`: `60 * 1000` milliseconds, interval between two reconnections
- {string} `username`: the username required by your broker, if any
@returns MQTTClient
--]]
function exports.connect(urlString, options)
    if (type(urlString) == 'string') then
        if (type(options) ~= 'table') then
            options = {}
        end

        local urlObject  = url.parse(urlString) or {}
        options.protocol = urlObject.protocol or 'mqtt'
        options.hostname = urlObject.hostname or '127.0.0.1'
        options.port     = tonumber(urlObject.port)

    -- connect(options)
    elseif (type(urlString) == 'table') then
        options = urlString
    end

    if (type(options) ~= 'table') then
        options = {}
    end

    local client = Client:new(options)
    if (urlString) then
        client:connect()
    end

    return client
end

return exports
