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
local core  = require('core')
local uv    = require('luv')

local packet = require('mqtt/packet')
local Packet = packet.Packet

local exports = {}

exports.DEFAULT_PORT        = 1883
exports.KEEP_ALIVE_TIME     = 60     -- seconds (maximum is 65535)
exports.MAX_RECONNECT_INTERVAL = 60 * 1000

-------------------------------------------------------------------------------
-- MQTTSocket

---@class MQTTSocket
local MQTTSocket = core.Emitter:extend()
exports.MQTTSocket = MQTTSocket

--[[

Create an MQTT client instance

`MQTTSocket` automatically handles the following:

* Regular server pings
* QoS flow
* Automatic reconnections
* Start publishing before being connected

@param {object} options
- {string} clientId
- {number} connectTimeout
- {number} keepalive
- {number} port
- {number} reconnectPeriod
- {function} callback
- {string} hostname
- {string} username
- {string} password
- {number} will

--]]
function MQTTSocket:initialize(options)
    options = options or {}

    self._outgoingStore     = {}        -- 用来存储需要 ACK 确认的请求消息
    self.clientSocket       = nil       -- 相关的 TCP Socket
    self.connectAckTimer    = nil       -- 等待 Connect ACK 超时定时器
    self.connected          = false     -- 当收到了 connect ACK 消息, 表示 MQTT 已连接
    self.debugEnabled       = false     -- 指出是否显示调试信息
    self.destroyed          = false     -- 指出这个客户端是否已经被关闭了, 将不再重连等
    self.keepAliveTimer     = nil       -- Keep Alive 保活 Timer
    self.options            = options
    self.state              = {}        -- MQTT 客户端状态
    self.reconnecting       = false
    self.server             = nil

    -- options
    local clientId = ("lnode_" .. tostring(process.pid))
    options.clientId        = options.clientId  or clientId
    options.connectTimeout  = options.connectTimeout or (30 * 1000) -- 30 * 1000 milliseconds, time to wait before a CONNACK is received
    options.keepalive       = options.keepalive or exports.KEEP_ALIVE_TIME -- 60 seconds, set to 0 to disable
    options.reconnectPeriod = options.reconnectPeriod or 1000 -- 1000 milliseconds, interval between two reconnections. Disable auto reconnect by setting to 0.

    -- state
    local state             = self.state
    state.lastActivityIn    = 0         -- 最后收到消息的时间
    state.lastActivityOut   = 0         -- 最后发出消息的时间
    state.lastActivityPing  = 0         -- 最后收到 ping 应答时间
    state.lastConnectTime   = 0         -- 最后一次发起连接的时间
    state.nextMessageId     = 0         -- 下一个消息 ID
    state.reconnectCount    = 0         -- 当前重连次数
    state.reconnecting      = false     -- 正在重连中
    state.reconnectInterval = options.reconnectPeriod -- 当前重连间隔
    state.socketConnected   = false     -- 仅当已建立 TCP 连接

    -- console.log('options', options)
end

--[[
Close the client, accepts the following options:

* `force`: passing it to true will close the client right away, without
  waiting for the in-flight messages to be acked. This parameter is
  optional.
* `callback`: will be called when the client is closed. This parameter is
  optional.
-- ]]
function MQTTSocket:close(force, callback)
    -- close(callback)
    if (type(force) == 'funciton') then
        callback = force
        force = nil
    end

    if (self.destroyed) then
        if (callback) then
            callback()
        end

        return 0
    end

    if (self.connected) then
        self:_sendDisconnect()
    end

    self:_onDisconnect()

    if (self.keepAliveTimer) then
        clearInterval(self.keepAliveTimer)
        self.keepAliveTimer = nil
    end

    -- reset
    self.options.callback = nil
    self.state.reconnectInterval = 1000
    self.destroyed = true -- Avoid recursion when _sendMessage() fails

    if (callback) then
        callback()
    end

    return 1
end

-- 显示错误消息, 但不会关闭当前连接
--
function MQTTSocket:emitError(errInfo)
    self:_onDebug(errInfo)

    self:emit('error', errInfo)
end

-- Parse MQTT message
-- ~~~~~~~~~~~~~~~~~~
-- MQTT 3.1 Specification: Section 2.1: Fixed header
--
-- Structure of an MQTT Control Packet:
-- byte  1:   Message type and flags (DUP, QOS level, and Retain) fields
-- bytes 2-5: Remaining length field (between one and four bytes long)
-- bytes m- : Optional variable header and payload
--
-- Figure 2.2 - Fixed header format
--
-- | Bit        |  7  |  6  |  5  |  4  |  3  |  2  |  1  |  0  |
-- | - - - - -  | - - - - - - - - - - - | - - | - - - - - | - - |
-- | byte 1     |  Control Packet type  | DUP |    Qos    | RET |
-- | byte 2…    |  Remaining Length                             |

-- The message type/flags and remaining length are already parsed and
-- removed from the message by the time this function is invoked.
-- Leaving just the optional variable header and payload.
-- @param {MQTTPacket} message -- 要处理的 MQTT 消息
function MQTTSocket:handleMessage(message)
    local messageType = message.messageType
    self.state.lastActivityIn = process.now()

    -- TODO: packet.TYPE table should include "parser handler" function.
    --       This would nicely collapse the if .. then .. elseif .. end.

    if (messageType == packet.TYPE_CONACK) then
        self:_handleConnectACK(message)

    elseif (messageType == packet.TYPE_PUBLISH) then
        self:_handlePublish(message)

     elseif (messageType == packet.TYPE_PUBACK) then
        self:_handlePublishACK(message)

    elseif (messageType == packet.TYPE_SUBACK) then
        self:_handleSubscribeACK(message)

    elseif (messageType == packet.TYPE_UNSUBACK) then
        self:_handleUnsubscribeACK(message)

    elseif (messageType == packet.TYPE_PINGREQ) then
        self:_sendPingResponse()

    elseif (messageType == packet.TYPE_PINGRESP) then
        self:_handlePingResponse(message)

    else
        local errorMessage = "handleMessage: Unknown message type: " .. tostring(messageType)
        self:_onDebug(errorMessage)
    end
end

-- 存储/读取指定 ID 的消息
-- @param {string} messageId
-- @param {MQTTPacket} message
-- @returns {MQTTPacket} message
function MQTTSocket:outgoingStore(messageId, message)
    if (not messageId) then
        return
    end

    if (message) then
        message.timestamp = process.now()
        self._outgoingStore[messageId] = message

    else
        return self._outgoingStore[messageId]
    end
end

-- 弹出指定的 ID 的消息
-- - 当收到指定的请求 (publish, subscribe, unsubscribe) 的 ACK 消息时，调用这个方法
-- @param {string} messageId ACK 消息 ID
-- @returns {MQTTPacket} request 返回相关的请求消息
function MQTTSocket:popOutgoingMessage(messageId)
    if (not messageId) then
        return
    end

    local request = self._outgoingStore[messageId]
    if (request) then
        self._outgoingStore[messageId] = nil
    end

    return request
end

-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
-- MQTT Private Methods

-- 检查是否已连接
-- @param {string} name
function MQTTSocket:_checkConnected(name, callback)
    if (self.state.socketConnected == false) then
        local errInfo = "" .. name .. ": Not connected"
        self:emitError(errInfo)

        if (callback) then
            callback(nil, errInfo)
        end

        return false
    end

    return true
end

-- 处理定时器事件, 在定时器事件中可以处理心跳, 重连等工作
-- 每隔 1 秒调用一次，直到停止连接
function MQTTSocket:_checkKeepAlive()
    if (self.destroyed) then
        return
    end

    local now = process.now()
    local options = self.options

    if (self.connected) then
        -- 定时发生 ping 消息，并检查会话是否超时
        local lastActivity  = self.state.lastActivityIn
        local span          = math.abs(now - lastActivity)
        local keepalive     = options.keepalive * 1000
        --console.log('connected', span)

        if (span > keepalive * 2) then
            self:_onErrorEvent("session timeout")

        elseif (span > keepalive) then
            self:_sendPingRequest()
        end

    elseif (not self.connectAckTimer) then
        -- 如果不在连接中，则定时发起重连
        -- reconnect
        local state = self.state
        local span  = math.abs(now - state.lastConnectTime)

        if (span > state.reconnectInterval) then
            state.reconnectInterval = math.min(state.reconnectInterval * 2, exports.MAX_RECONNECT_INTERVAL)
            self:_onReconnect()

            local host = self.server and self.server.host
            console.info('mqtt.reconnect', host, span, state.reconnectCount, state.reconnectInterval)
        end
    end
end

-- 开始连接
function MQTTSocket:_onConnect()
    -- #1. create socket
    if (self.clientSocket) then
        uv.close(self.clientSocket)
        self.clientSocket = nil
    end

    self.clientSocket = uv.new_tcp()
    if (self.clientSocket == nil) then
        self:_onErrorEvent("connect: Couldn't open MQTT broker connection")
        return
    end

    -- #2. set connect timeout
    if (self.connectAckTimer) then
        clearTimeout(self.connectAckTimer)
        self.connectAckTimer = nil
    end

    local options = self.options
    -- console.log('options', options)

    local connectTimeout = options.connectTimeout
    self.connectAckTimer = setTimeout(connectTimeout, function()
        self:_onErrorEvent("connect timeout!")
    end)

    -- #3. connect
    self.state.lastConnectTime = process.now()
    local _onConnectCallback = function(err)
        if (err) then
            self:_onErrorEvent('connect failed: ' .. err)
        else
            self:_onSocketConnected()
        end
    end

    -- #4. query dns
    local servers = options.servers
    local nextServerId = (servers.serverId or 0) + 1
    if (nextServerId > #servers) then
        nextServerId = 1
    end

    servers.serverId = nextServerId
    local server = servers[nextServerId]
    self.server = server
    -- console.log('servers', servers)

    local host  = server.host
    local port  = server.port or exports.DEFAULT_PORT
    local params   = { socktype = "stream", family = "inet" }
    uv.getaddrinfo(host, port, params, function(err, res)
        if err then
            self:_onErrorEvent('query dns failed: ' .. tostring(err))

        elseif (not self.clientSocket) then
            self:_onErrorEvent('query dns failed: invalid socket')

        elseif (not res) or (not res[1]) then
            self:_onErrorEvent('query dns failed: invalid response')

        else
            local dest = res[1]
            self.state.address = { dest.addr, dest.port }
            self.clientSocket:connect(dest.addr, dest.port, _onConnectCallback)
        end
    end)

    return 0
end

function MQTTSocket:_onConnected(message)
    local state = self.state
    state.reconnectCount = 0
    state.reconnectInterval = self.options.reconnectPeriod or 1000
    self:emit('connect', message)

    console.log('mqtt.connect', self.server and self.server.host)
end

-- 显示调试信息
--
function MQTTSocket:_onDebug(info)
    if (self.debugEnabled) then
        print(info)
    end
end

-- 停止连接
-- - 发生严重错误等时候会调用
-- @param {string} info 关闭事件消息
function MQTTSocket:_onDisconnect(info)
    -- close MQTT connection
    if (self.connected) then
        self.connected = false
        self:emit('close', info)
        self:emit('offline')
    end

    -- cancel connect timer
    if (self.connectAckTimer) then
        clearTimeout(self.connectAckTimer)
        self.connectAckTimer = nil
    end

    -- close TCP connection
    if (self.clientSocket) then
        uv.close(self.clientSocket)
        self.clientSocket = nil
    end

    -- reset
    self.state.socketConnected = false
    self._outgoingStore = {}
end

-- 显示严重错误消息, 且关闭当前连接
-- @param {string} errInfo
function MQTTSocket:_onErrorEvent(errInfo)
    self:emit('error', errInfo)

    self:_onDisconnect()
end

-- 重连, 会生产 'reconnect' 事件
-- - 由 KeepAlive 定时器调用
function MQTTSocket:_onReconnect()
    local state = self.state
    state.reconnecting = true
    state.reconnectCount = (state.reconnectCount or 0) + 1

    self:emit('reconnect', state.reconnectCount)

    self:_onDisconnect()
    self:_onConnect()
end

-- 当成功建立 Socket 连接
function MQTTSocket:_onSocketConnected()
    local now = process.now();
    local state = self.state
    local options = self.options
    local span  = math.abs(now - state.lastConnectTime)

    -- 必须大于最大重连间隔才重置重连间隔，避免反复连接和断开的 bug
    state.socketConnected = true
    state.lastActivityOut = process.now()
    if (span > exports.MAX_RECONNECT_INTERVAL) then
        state.reconnectInterval = options.reconnectPeriod
    end

    self.clientSocket:read_start(function(err, chunk)
        -- console.log('read_start', chunk and #chunk)
        if (err) then
            self:_onErrorEvent('read_start: read failed: ' .. tostring(err))

        elseif (not chunk) then
            --print('read_start: empty chunk')
            self:_onErrorEvent('read_start: read end!')

        else
            self:_handleMessageData(chunk)
        end
    end)

    self:_sendConnect()
end

-- Handle received messages and maintain keep-alive PING messages
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--[[
This function must be invoked periodically (more often than the
exports.KEEP_ALIVE_TIME) which maintains the connection and
services the incoming subscribed topic messages.

Handle messages with backpressure support, one at a time.
Override at will, but __always call `callback`__, or the client
will hang.
@param {string} buffer 收到的数据
]]
function MQTTSocket:_handleMessageData(buffer)
    -- Check for available client socket data
    -- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    if (buffer == nil or #buffer <= 0) then
        return
    end

    if (self.lastBuffer) then
        buffer = self.lastBuffer .. buffer
        self.lastBuffer = nil
    end

    local emitError = function(error)
        self:emit('error', error)
    end

    -- 检查连接状态
    self:_checkConnected('_handleMessageData')

    -- Parse individual messages (each must be at least 2 bytes long)
    -- Decode "remaining length" (MQTT v3.1 specification pages 6 and 7)
    local index = 1
    local mqttMessage = nil

    -- 解析并处理消息
    while (index < #buffer) do
        mqttMessage, index = packet.parse(buffer, index, emitError)
        if (not mqttMessage) then
            self.lastBuffer = buffer -- 缓存剩余的数据
            break
        end

        self:handleMessage(mqttMessage)
    end
end

-- Parse MQTT CONACK message
-- ~~~~~~~~~~~~~~~~~~~~~~~~~
-- MQTT 3.1 Specification: Section 3.2: CONACK Acknowledge connection
--
-- byte 1: Reserved value
-- byte 2: Connect return code, see MQTT.CONACK.errorMessage[]
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
function MQTTSocket:_handleConnectACK(message)
    -- cancel connect timer
    if (self.connectAckTimer) then
        clearTimeout(self.connectAckTimer)
        self.connectAckTimer = nil
    end

    -- 连接被服务器拒绝
    if (message.returnCode ~= 0) then
        self:_onErrorEvent("Connection refused: " .. tostring(message.errorMessage))
        return
    end

    self.state.reconnecting = false
    if (not self.connected) then
        self.connected = true

        self:_onConnected(message)
    end
end

-- Parse MQTT PINGRESP message
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- MQTT 3.1 Specification: Section 3.13: PING response
-- messageFlags,  -- byte
-- remainingLength,    -- integer
-- message             -- string
function MQTTSocket:_handlePingResponse(message)
    self.state.lastActivityPing = process.now()
end

-- Parse MQTT PUBLISH message
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~
-- MQTT 3.1 Specification: Section 3.3: Publish message
--
-- Variable header ..
-- bytes 1- : Topic name and optional Message Identifier (if QOS > 0)
-- bytes m- : Payload

function MQTTSocket:_handlePublish(message)
    local callback = self.options.callback
    if (callback) then
        callback(message.topic, message.payload)
    end

    self:emit('message', message.topic, message.payload)
end

function MQTTSocket:_handlePublishACK(message)
    local messageId  = message.messageId
    if (not messageId) then
        self:emitError("invalid messsage ID: ")
        return
    end

    local request = self:popOutgoingMessage(messageId)
    if (request == nil) then
        self:emitError("No outgoing publish message: " .. tostring(messageId))
        return
    end

    if (request.callback) then
        request.callback()
    end
end

function MQTTSocket:_handlePublishRel(message)
    -- TODO: qos 2
end

function MQTTSocket:_handlePublishRec(message)
    -- TODO: qos 2
end

-- Parse MQTT SUBACK message
-- ~~~~~~~~~~~~~~~~~~~~~~~~~
-- MQTT 3.1 Specification: Section 3.9: SUBACK Subscription acknowledgement
--
-- bytes 1,2: Message Identifier
-- bytes 3- : List of granted QOS for each subscribed topic

function MQTTSocket:_handleSubscribeACK(message)
    local messageId  = message.messageId
    local request = self:popOutgoingMessage(messageId)
    if (request == nil) then
        self:emitError("No outgoing subscribe message: ", messageId)
        return
    end

    local callback = request.callback
    if (not callback) then
        return
    end

    if (request.message ~= "subscribe") then
        callback("Outstanding message wasn't SUBSCRIBE")
        return
    end

    local topicCount = #(request.topics)
    if (topicCount ~= message.length - 2) then
        callback("Didn't received expected number of topics: " .. topicCount)
        return
    end

    callback(nil, message)
end

-- Parse MQTT UNSUBACK message
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- MQTT 3.1 Specification: Section 3.11: UNSUBACK Unsubscription acknowledgement
--
-- bytes 1,2: Message Identifier
--
function MQTTSocket:_handleUnsubscribeACK(message)
    local messageId = message.messageId or ''

    local request = self:popOutgoingMessage(messageId)
    if (request == nil) then
        self:emitError("No outgoing unsubscribe message: " .. messageId)
        return
    end

    local callback = request.callback
    if (not callback) then
        return
    end

    if (request.message ~= "unsubscribe") then
        callback("Outstanding message wasn't UNSUBSCRIBE")
        return
    end

    callback()
end

function MQTTSocket:_nextMessageId()
    local state = self.state
    state.nextMessageId = state.nextMessageId + 1
    if (state.nextMessageId > 0xffff) then
        state.nextMessageId = 1 -- Ensure 16 bit unsigned int
    end
    return state.nextMessageId
end

-- Transmit MQTT connect message
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

function MQTTSocket:_sendConnect()
    local options = self.options

    local message = Packet:new()
    message.messageType = packet.TYPE_CONNECT
    message.will        = options.will
    message.clientId    = options.clientId
    message.keepalive   = options.keepalive
    message.username    = options.username
    message.password    = options.password

    return self:_sendMQTTPacket(message)
end

-- Transmit MQTT Disconnect message
-- ~~~~~~~~~~~~~~~~~~~~~~~~
-- MQTT 3.1 Specification: Section 3.14: Disconnect notification
--
-- bytes 1,2: Fixed message header, see MQTTSocket:_sendMessage()
function MQTTSocket:_sendDisconnect()
    if (self.connected) then
        self:_sendMessage(packet.TYPE_DISCONNECT)
    end
end

-- Transmit MQTT Ping request message
-- ~~~~~~~~~~~~~~~~~~~~~~~~
-- MQTT 3.1 Specification: Section 3.13: PING request
function MQTTSocket:_sendPingRequest()
    self:_checkConnected('_sendPingRequest')

    if (self.connected) then
        return self:_sendMessage(packet.TYPE_PINGREQ)
    end
end

-- Transmit MQTT Ping response message
-- ~~~~~~~~~~~~~~~~~~~~~~~~
-- MQTT 3.1 Specification: Section 3.13: PING response
function MQTTSocket:_sendPingResponse()
    self:_checkConnected('_sendPingResponse')

    return self:_sendMessage(packet.TYPE_PINGRESP)
end

-- Transmit an MQTT message
-- ~~~~~~~~~~~~~~~~~~~~~~~~
-- MQTT 3.1 Specification: Section 2.1: Fixed header
--
-- byte  1:   Message type and flags (DUP, QOS level, and Retain) fields
-- bytes 2-5: Remaining length field (between one and four bytes long)
-- bytes m- : Optional variable header and payload
-- @param {number} messageType  -- enumeration
-- @param {string} payload      -- string
-- @returns nil or error message
function MQTTSocket:_sendMessage(messageType, payload, callback)
    local message = Packet:new(messageType, payload)
    return self:_sendMQTTPacket(message, callback)
end

-- 发送 MQTT 消息包
-- @param {MQTTPacket} message
-- @param {function} callback
function MQTTSocket:_sendMQTTPacket(message, callback, ...)
    if (callback) then
        setImmediate(callback)
    end

    local messageData = message:build(...)
    if (not messageData) then
        self:_onDebug('invalid message: ', message)
        return nil, 'Invalid message data'
    end

    --console.printBuffer(messageData)
    if (not self.clientSocket) then
        return messageData, 'Invalid MQTT client socket'
    end

    -- write
    local status = self.clientSocket:write(messageData)
    if (status == nil) then
        self:_onErrorEvent("_sendMQTTPacket: write failed")
        return nil, 'write MQTT packet failed'
    end

    --console.log('_sendMQTTPacket', messageData)
    self.state.lastActivityOut = process.now()
    return messageData
end

return exports

--]]
