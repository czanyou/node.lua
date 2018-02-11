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
local core  = require('core')
local url   = require('url')
local utils = require('utils')

-------------------------------------------------------------------------------
--

local exports = {}

exports.PROTOCOL    = "MQTT"
exports.VERSION     = 0x04

-- [[
exports.PROTOCOL    = "MQIsdp"
exports.VERSION     = 0x03
--]]

exports.QOS_0       = 0
exports.QOS_1       = 1
exports.QOS_2       = 2

-- Header
exports.CMD_MASK    = 0xF0
exports.CMD_SHIFT   = 4
exports.DUP_MASK    = 0x08
exports.QOS_MASK    = 0x06
exports.QOS_SHIFT   = 1
exports.RETAIN_MASK = 0x01

-- Length 
exports.LENGTH_MASK     = 0x7F
exports.LENGTH_FIN_MASK = 0x80

-- Connect
exports.USERNAME_MASK       = 0x80
exports.PASSWORD_MASK       = 0x40
exports.WILL_RETAIN_MASK    = 0x20
exports.WILL_QOS_MASK       = 0x18
exports.WILL_QOS_SHIFT      = 3
exports.WILL_FLAG_MASK      = 0x04
exports.CLEAN_SESSION_MASK  = 0x02

-- Connack

exports.SESSIONPRESENT_MASK = 0x01

-- CONACK acknowledge connection errors

exports.CONACK_CODES = {                -- CONACK return code used as the index
    "Unacceptable protocol version",    -- 1
    "Identifer rejected",               -- 2
    "Server unavailable",               -- 3
    "Bad user name or password",        -- 4
    "Not authorized",                   -- 5
    "Invalid will topic"                -- Proposed
}

exports.MAX_PAYLOAD_LENGTH  = 268435455 -- bytes

-- Command code => mnemonic 
-- Fixed header, Message type
-- 消息类型(4-7)，使用 4 位二进制表示，可代表 16 种消息类型：

exports.TYPE_RESERVED    = 0x00     -- Reserved
exports.TYPE_CONNECT     = 0x01     -- Client request to connect to Server
exports.TYPE_CONACK      = 0x02     -- Connect Acknowledgment
exports.TYPE_PUBLISH     = 0x03     -- Publish message
exports.TYPE_PUBACK      = 0x04     -- Publish Acknowledgment
exports.TYPE_PUBREC      = 0x05     -- Publish Received (assured delivery part 1)
exports.TYPE_PUBREL      = 0x06     -- Publish Release (assured delivery part 2)
exports.TYPE_PUBCOMP     = 0x07     -- Publish Complete (assured delivery part 3)
exports.TYPE_SUBSCRIBE   = 0x08     -- Client Subscribe request
exports.TYPE_SUBACK      = 0x09     -- Subscribe Acknowledgment
exports.TYPE_UNSUBSCRIBE = 0x0a     -- Client Unsubscribe request
exports.TYPE_UNSUBACK    = 0x0b     -- Unsubscribe Acknowledgment
exports.TYPE_PINGREQ     = 0x0c     -- PING Request
exports.TYPE_PINGRESP    = 0x0d     -- PING Response
exports.TYPE_DISCONNECT  = 0x0e     -- Client is Disconnecting
exports.TYPE_RESERVED    = 0x0f     -- Reserved

-------------------------------------------------------------------------------

-- Encode a message string using UTF-8 (for variable header)
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- MQTT 3.1 Specification: Section 2.5: MQTT and UTF-8
--
-- | Bit        |
-- | - - - - - -| - - - - - - - - - - - - -                            
-- | byte  1    | String length MSB
-- | byte  2    | String length LSB
-- | bytes 3... | String encoded as UTF-8, if length > 0.
-- 
function exports.encodeString(text)
    if (not text) then
        return
    end

    text = tostring(text) or ''
    if (#text <= 0) then
        return
    end

    local header = string.pack('>I2', #text)
    return header .. text
end

-- 解析 MQTT 消息包
-- @param buffer 
-- @param index 
-- @param callback 
-- @return message, offset
function exports.parse(buffer, index, callback)
    local offset = index or 1
    local messageHeader = buffer:byte(offset)

    offset = offset + 1
    local remainingLength, offset = exports.parseLength(buffer, offset)
    if (not remainingLength) then
        return nil, offset
    end

    local messageData = buffer:sub(offset, offset + remainingLength - 1)
    --print('parse', offset, remainingLength, #messageData)

    if (remainingLength <= #messageData) then
        local mqttMessage = exports.Packet:new()
        if (callback) then
            mqttMessage:on('error', callback)
        end
        
        mqttMessage.length = remainingLength
        mqttMessage:parse(messageHeader, remainingLength, messageData)
        return mqttMessage, offset + remainingLength
        
    else
        return nil, index or 1
    end
end

function exports.parseLength(buffer, index)
    local multiplier = 1
    local messageLength = 0
    local offset = index or 1

    -- parse messageLength
    repeat
        local digit = string.byte(buffer, offset)
        messageLength = messageLength + ((digit & 0x7f) * multiplier)
        multiplier = multiplier * 128
        offset = offset + 1
    until (digit < 0x80)                              -- check continuation bit   

    return messageLength, offset
end

-------------------------------------------------------------------------------
-- Packet

local Packet = core.Emitter:extend()
exports.Packet = Packet

function Packet:initialize(messageType, payload) 
    self.cmd            = nil
    self.dup            = false
    self.length         = -1
    self.payload        = payload
    self.qos            = 0
    self.retain         = false
    self.topic          = nil

    self.keepalive      = 60
    self.messageId      = nil
    self.messageType    = messageType or nil
end

function Packet:build(...)
    local message = {}

    -- build payload
    if (self.messageType == exports.TYPE_CONNECT) then
        self:buildConnect(...)

    elseif (self.messageType == exports.TYPE_CONACK) then
        self:buildConnectACK(...)        

    elseif (self.messageType == exports.TYPE_PUBLISH) then
        self:buildPublish(...)

    elseif (self.messageType == exports.TYPE_SUBSCRIBE) then
        self:buildSubscribe(...)
        
    elseif (self.messageType == exports.TYPE_UNSUBSCRIBE) then
        self:buildUnsubscribe(...)      
    end

    -- header
    local header = self.messageType << 4
    if (self.qos and self.qos > 0) then
        header = header | self.qos << 1
    end

    -- message type byte
    table.insert(message, string.char(header))

    local payload = self.payload

    -- remainingLength byte
    if (payload == nil) then
        table.insert(message, string.char(0))  -- Zero length, no payload

    else
        if (#payload > exports.MAX_PAYLOAD_LENGTH) then
            return nil, ("_sendMessage: Payload length = " .. #payload ..
            " exceeds maximum of " .. exports.MAX_PAYLOAD_LENGTH)
        end

        self:encodeLength(message, #payload)
        table.insert(message, payload)
    end

    return table.concat(message)
end

function Packet:buildConnectACK(returnCode)
    --self.returnCode = returnCode
    self.payload = string.char(0, returnCode or 0)
end

function Packet:buildConnect()
    -- Construct CONNECT variable header fields (bytes 1 through 9)

    -- Protocol name & protocol version
    local payload = {}

    self:encodeString(payload, exports.PROTOCOL)
    table.insert(payload, string.char(exports.VERSION))

    -- Connect flags (byte 10)
    -- ~~~~~~~~~~~~~
    -- bit    7: Username flag =  0  -- recommended no more than 12 characters
    -- bit    6: Password flag =  0  -- ditto
    -- bit    5: Will retain   =  0
    -- bits 4,3: Will QOS      = 00
    -- bit    2: Will flag     =  0
    -- bit    1: Clean session =  1
    -- bit    0: Unused        =  0

    local flags = 0x02 -- Clean session, no last will
    local will = self.will
    if (will) then
        flags = ((will.retain or 0) << 5)
        flags = flags + ((will.qos or 0) << 3) + 0x06
    end

    if (self.username) then
        flags = flags | 0x80
    end

    if (self.password) then
        flags = flags | 0x40
    end

    table.insert(payload, string.char(flags))

    -- Keep alive timer (bytes 11 LSB and 12 MSB, unit is seconds)
    table.insert(payload, string.pack('>I2', self.keepalive))

    -- Message Payload:
    -- ================

    -- Client identifier
    if (self.clientId) then
        self:encodeString(payload, self.clientId)
    end

    -- Last will and testament
    if (will and will.topic) then
        self:encodeString(payload, will.topic)
        self:encodeString(payload, will.message or '')
    end

    if (self.username) then
        self:encodeString(payload, self.username)
    end

    if (self.password) then
        self:encodeString(payload, self.password)
    end

    self.payload = table.concat(payload)
end

function Packet:buildPublish(topic, data)
    local payload = {}

    self:encodeString(payload, topic)

    if (self.messageId) then
        table.insert(payload, string.pack('>I2', self.messageId))
    end

    if (data) then
        table.insert(payload, data)
    end
    
    self.payload = table.concat(payload)
end

function Packet:buildSubscribe(topics)
    local payload = {}
    table.insert(payload, string.pack('>I2', self.messageId))

    for index, topic in ipairs(topics) do
        if (type(topic) == 'table') then
            topic = topic.topic
        end

        if (topic) then
            self:encodeString(payload, topic)
            table.insert(payload, string.char(0))  -- QOS level 0
        end
    end

    self.payload = table.concat(payload)
end

function Packet:buildUnsubscribe(topics)
    local payload = {}
    table.insert(payload, string.pack('>I2', self.messageId))

    for index, topic in ipairs(topics) do
        self:encodeString(payload, topic)
    end

    self.payload = table.concat(payload)
end

function Packet:encodeLength(message, remainingLength)
    if (remainingLength < 0) then
        return false, 'invalid remaining length'
    end

    -- Encode "remaining length" (MQTT v3.1 specification pages 6 and 7)
    repeat
        local digit = remainingLength & 0x7f
        remainingLength = remainingLength >> 7
        if (remainingLength > 0) then 
            digit = digit | 0x80
        end -- continuation bit

        table.insert(message, string.char(digit))
    until remainingLength == 0
end

function Packet:encodeString(list, text)
    if (not text) then
        return
    end

    text = tostring(text) or ''
    if (#text <= 0) then
        return
    end
    
    table.insert(list, string.pack('>I2', #text))
    table.insert(list, text)
end

function Packet:parse(messageHeader, messageLength, messageData)
    self.length  = messageLength
    self:parseHeader(messageHeader)

    local messageType = self.messageType

    if (messageType == exports.TYPE_CONNECT)         then
        return self:parseConnect(messageData)

    elseif (messageType == exports.TYPE_CONACK)      then
        return self:parseConnectACK(messageData)

    elseif (messageType == exports.TYPE_PUBLISH)     then
        return self:parsePublish(messageData)

    elseif (messageType == exports.TYPE_PUBACK)      then
        return self:parsePublishACK(messageData)

    elseif (messageType == exports.TYPE_PUBREC)      then
        return self:parsePublishACK(messageData)

    elseif (messageType == exports.TYPE_PUBREL)      then
        return self:parsePublishACK(messageData)               

    elseif (messageType == exports.TYPE_PUBCOMP)     then
        return self:parsePublishACK(messageData)

    elseif (messageType == exports.TYPE_SUBSCRIBE)   then
        return self:parseSubscribe(messageData)

    elseif (messageType == exports.TYPE_SUBACK)      then
        return self:parseSubscribeACK(messageData)

    elseif (messageType == exports.TYPE_UNSUBSCRIBE) then
        return self:parseUnsubscribe(messageData)

    elseif (messageType == exports.TYPE_UNSUBACK)    then
        return self:parseUnsubscribeACK(messageData)

    elseif (messageType == exports.TYPE_PINGRESP)    then
    elseif (messageType == exports.TYPE_PINGREQ)     then
    elseif (messageType == exports.TYPE_DISCONNECT)  then
        -- empty packet
    else
        self:emit('error', 'not supported message')
    end
end

function Packet:parseConnect(messageData)
    local index = 1
    self.protocol, index = self:parseString(messageData, index)
    self.version = messageData:byte(index)
    index = index + 1

    local flags  = messageData:byte(index)
    self.flags = flags
    index = index + 1

    self.keepalive = string.unpack('>I2', messageData, index)
    index = index + 2

    self.clientId, index = self:parseString(messageData, index)

    if (flags & exports.WILL_FLAG_MASK) ~= 0 then
        self.will = {}
        self.will.topic, index = self:parseString(messageData, index)
        self.will.message, index  = self:parseString(messageData, index)
    end

    if (flags & exports.USERNAME_MASK) ~= 0 then
        self.username, index = self:parseString(messageData, index)
    end
    
    if (flags & exports.PASSWORD_MASK) ~= 0 then
        self.password, index = self:parseString(messageData, index)
    end      
end

function Packet:parseConnectACK(messageData)
    if (#messageData < 2) then
        self:emit('error', "Invalid remaining length")
        return
    end

    -- byte 1 Reserved values.
    -- byte 2 Connect Return Code
    self.sessionPresent = not not (messageData:byte(1) & exports.SESSIONPRESENT_MASK)
    self.returnCode = messageData:byte(2)
    if (self.returnCode ~= 0) then
        local errorMessage = exports.CONACK_CODES[self.returnCode]
        self.errorMessage = errorMessage or "Unknown return code"
    end

    return 0
end

function Packet:parseHeader(messageHeader)
    self.messageType = (messageHeader & exports.CMD_MASK) >> exports.CMD_SHIFT
    self.qos         = (messageHeader & exports.QOS_MASK) >> exports.QOS_SHIFT
    self.dup         = (messageHeader & exports.DUP_MASK) ~= 0
    self.retain      = (messageHeader & exports.RETAIN_MASK) ~= 0
end

function Packet:parseMessageId(messageData, index)
     index = index or 1
   
    if (not messageData) then 
        return nil, index
    end

     if (#messageData <= index) then
        self:emit('error', "cannot parse message id")
        return nil, index
    end
       
    self.messageId  = string.unpack(">I2", messageData, index)
    return 0, index + 2
end

function Packet:parsePublish(messageData)
    if (#messageData < 3) then
        self:emit('error', "Invalid remaining length")
        return
    end

    -- topic name
    local index  = 1
    self.topic, index = self:parseString(messageData, index)
    if (not self.topic) then
        self:emit('error', 'cannot parse topic')
        return
    end

    -- Handle optional Message Identifier, for QOS levels 1 and 2
    if (self.qos) and (self.qos > 0) then
        self:parseMessageId(messageData, index)

        index = index + 2
    end

    self.payload = messageData:sub(index, #messageData)
    return 0
end

function Packet:parsePublishACK(messageData)
    self:parseMessageId(messageData)
    return 0
end

function Packet:parseString(messageData, index)
    if (not messageData) then
        return
    end

    local offset = index or 1
    if (offset > #messageData) then
        return nil
    end

    local length = string.unpack('>I2', messageData, offset)
    offset  = offset + 2
    if (offset + length - 1 > #messageData) then
        return nil
    end

    local value  = string.sub(messageData, offset, offset + length - 1)
    offset  = offset + length

    return value, offset
end

function Packet:parseSubscribe(messageData)
    if (not self:parseMessageId(messageData)) then 
        return nil
    end

    local index  = 3
    local topics = {}

    while (true) do
        local topic = nil
        topic, index = self:parseString(messageData, index)
        if (not topic) or (topic == '') then 
            break
        end

        local qos = string.unpack(">B", messageData, index)
        index = index + 1

        table.insert(topics, { topic = topic, qos = qos } )
    end

    self.topics = topics
end

function Packet:parseSubscribeACK(messageData)
    self:parseMessageId(messageData)
    return 0
end

function Packet:parseUnsubscribe(messageData)
    if (not self:parseMessageId(messageData)) then 
        return nil
    end

    local index  = 3
    local topics = {}

    while (true) do
        local topic = nil
        topic, index = self:parseString(messageData, index)
        if (not topic) or (topic == '') then 
            break
        end

        table.insert(topics, topic)
    end

    self.topics = topics
end

function Packet:parseUnsubscribeACK(messageData)
    self:parseMessageId(messageData)
    return 0
end

return exports
