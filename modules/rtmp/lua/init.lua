local util = require('util')

local exports = {}

-- H.264 video NALU types
local NALU_TYPE_I   	= 5
local NALU_TYPE_SPS 	= 7
local NALU_TYPE_PPS 	= 8
local NALU_TYPE_P   	= 1

local RTMP_CHUNK_TYPE_0 = 0; -- 11-bytes: timestamp(3) + length(3) + stream type(1) + stream id(4)
local RTMP_CHUNK_TYPE_1 = 1; -- 7-bytes: delta(3) + length(3) + stream type(1)
local RTMP_CHUNK_TYPE_2 = 2; -- 3-bytes: delta(3)
local RTMP_CHUNK_TYPE_3 = 3; -- 0-byte

-- ----------------------------------------------------------------------------
-- AMF0

local amf0 = {}
exports.amf0 = amf0

amf0.null = {}

setmetatable(amf0.null, {
    __tostring = function() return 'null' end
})

function amf0.parseValue(data, pos)
    local index = pos or 1
    local typeId = data:byte(index)
    --console.log('typeId', typeId, index)
    if (typeId == nil) then
        return nil, nil
    end

    if (typeId == 0x00) then
        -- number
        local value = string.unpack('>d', data, index + 1);
        --console.log('value', value)
        index = index + 1 + 8

        return value, index

    elseif (typeId == 0x01) then
        -- boolean
        local value = data:byte(index + 1) ~= 0x00
        --console.log('value', value)
        index = index + 2

        return value, index

    elseif (typeId == 0x02) then
        -- string
        local length = string.unpack('>I2', data, index + 1);
        local value = data:sub(index + 1 + 2, index + 2 + length)
        --console.log('length', length, value)

        index = index + 1 + 2 + length
        return value, index

    elseif (typeId == 0x05) then
        -- null
        index = index + 1
        return amf0.null, index

    elseif (typeId == 0x03) then
        -- object
        --console.log('object')
        local object = {}

        index = index + 1

        while (true) do
            local length = string.unpack('>I2', data, index);
            if (length == 0) then
                index = index + 3
                break
            end

            index = index + 2
            local key = data:sub(index, index + length - 1)
            --console.log('key', length, key)

            index = index + length

            local typeId = data:byte(index)
            --console.log('typeId', typeId)

            local value = nil
            value, index = amf0.parseValue(data, index);
            --console.log('value', index, value)

            object[key] = value
        end

        return object, index

    else
        index = index + 1

        return amf0.null, index
    end
end

function amf0.parseArray(data, pos, limit) 
    local index = pos or 1
    local value = nil;
    local result = {}

    --console.log('parseArray', #data, limit)

    while (true) do
        if (limit) and (index >= limit) then
            break
        end

        value, index = amf0.parseValue(data, index)
        --console.log('parseArray', value, index)
        if (value == nil and index == nil) then
            break
        end

        result[#result + 1] = value
    end

    return result, index
end

function amf0.encodeArray(array)
    local data = {}

    for index, item in ipairs(array) do
        --console.log('encodeArray', index, type(item), item)

        local typeName = type(item)
        if (item == amf0.null) then
            -- null
            data[#data + 1] = string.pack('>B', 0x05)

        elseif (typeName == 'nil') then
            -- null
            data[#data + 1] = string.pack('>B', 0x05)

        elseif (typeName == 'string') then
            -- string
            -- TODO: item must less than 65535
            data[#data + 1] = string.pack('>BI2', 0x02, #item)
            data[#data + 1] = item
            
        elseif (typeName == 'number') then
            -- number
            -- TODO: item must less than 0xffffffff
            data[#data + 1] = string.pack('>Bd', 0x00, item)
        
        elseif (typeName == 'boolean') then
            -- boolean
            local value = 0
            if (item) then
                value = 1
            end
            data[#data + 1] = string.pack('>BB', 0x01, value)

        elseif (typeName == 'table') then
            -- start of object
            data[#data + 1] = string.pack('>B', 0x03)

            for key, value in pairs(item) do
                -- key
                -- TODO: key length must less then 65535
                data[#data + 1] = string.pack('>I2', #key)
                data[#data + 1] = key
                --console.printBuffer(data[#data])

                -- value
                local typeValue = type(value)
                if (value == amf0.null) then
                    -- null
                    data[#data + 1] = string.pack('>B', 0x05)

                elseif (typeValue == 'nil') then
                    -- null
                    data[#data + 1] = string.pack('>B', 0x05)
                 
                elseif (typeValue == 'string') then
                    -- string
                    -- TODO: valuelength must less then 65535
                    data[#data + 1] = string.pack('>BI2', 0x02, #value)
                    data[#data + 1] = value

                elseif (typeValue == 'number') then
                    -- number
                    -- TODO: value must less than 0xffffffff
                    data[#data + 1] = string.pack('>Bd', 0x00, value)

                elseif (typeValue == 'boolean') then
                    -- boolean
                    local bool = 0
                    if (value) then
                        bool = 1
                    end
                    data[#data + 1] = string.pack('>BB', 0x01, bool)
                end
            end

            -- end of object
            data[#data + 1] = string.pack('>BBB', 0x00, 0x00, 0x09)
        end
    end

    return table.concat(data)
end

-- ----------------------------------------------------------------------------
-- FLV

local flv = {}
exports.flv = flv

function flv.parseFileHeader(data, index)
    index = index + 9
    return index, 0
end

function flv.parseTagHeader(data, index)
    local preTagSize, tagType, tagSize, timestamp, timestampEx, streamId 
        = string.unpack(">I4BI3I3BI3", data, index)
    local tag = {
        preTagSize = preTagSize,
        tagType = tagType,
        tagSize = tagSize,
        timestamp = timestamp,
        streamId = streamId
    }

    index = index + 15
    return index, tag
end

function flv.encodeFileHeader()
    local flags = 0x05
    local headerSize = 9
    return string.pack(">BBBBBI4", 0x46, 0x4c, 0x56, 0x01, flags, headerSize)
end

function flv.encodeTagHeader(tagType, tagSize, preTagSize, tagTime)
    local timestamp = tagTime or 0x00 -- 毫秒
    local timestampEx = 0x00
    local streamId = 0x00

    return string.pack(">I4BI3I3BI3", preTagSize, tagType, tagSize, timestamp, timestampEx, streamId)
end

function flv.encodeVideoConfiguration(sps, pps)
    -- Header
    local frameType = 0x01 << 4 -- key frame
    frameType = frameType + 0x07
    local avcPacketType = 0x00 -- sps/pps
    local avcTimestamp = 0x00
    local videoHeader = string.pack('>BBI3', frameType, avcPacketType, avcTimestamp)

    -- SPS
    local cfgVersion = 0x01;
    local avcProfile = sps:byte(2);
    local profileCompatibility = sps:byte(3);
    local avcLevel = sps:byte(4);
    local lengthSizeMinusOne = 0xFC | 0x03;
    local numOfSPS = 0xE0 | 0x01;
    local spsLength = #sps;
    local spsHeader = string.pack('>BBBBBBI2', cfgVersion, avcProfile, profileCompatibility, avcLevel, 
    lengthSizeMinusOne, numOfSPS, spsLength);

    -- PPS
    local numOfPPS = 0x01;
    local ppsLength = #pps;
    local ppsHeader = string.pack('>BI2', numOfPPS, ppsLength)

    -- output
    local videoData = table.concat({ videoHeader, spsHeader, sps, ppsHeader, pps })
    return videoData
end

function flv.decodeVideoTag(data)
    local index = 1

    ---- header
    -- frameType & codecType
    local value = data:byte(index)
    local frameType = (value >> 4)
    local codecType = (value & 0x0F)
    if (codecType ~= 7) then -- AVC (0x07)
        return
    end
    index = index + 1

    -- packetType & timestamp
    local packetType, timestamp = string.unpack('>BI3', data, index)
    index = index + 4

    if (packetType == 0x00) then -- AVCSequence Header
        local result = flv.decodeConfiguration(data, index) or {}
        result.frameType = frameType
        result.codecType = codecType
        result.packetType = packetType
        return result

    else
        local naluLength = string.unpack('>I4', data, index)
        index = index + 4
        return {
            frameType = frameType, 
            codecType = codecType, 
            naluLength = naluLength, 
            packetType = packetType,
            timestamp = timestamp,
            index = index
        }
    end
end

function flv.decodeAudioTag(data)

end

function flv.decodeMetadataTag(data)
    local meta = amf0.parseArray(data)
    return meta
end

function flv.decodeConfiguration(data, index)
    -- SPS
    local cfgVersion, avcProfile, profileCompatibility, avcLevel, lengthSizeMinusOne, numOfSPS, spsLength 
            = string.unpack('>BBBBBBI2', data, index)

    lengthSizeMinusOne = lengthSizeMinusOne & 0x03
    numOfSPS = numOfSPS & 0x1f

    index = index + 8
    local sps = data:sub(index, index + spsLength - 1)

    -- PPS
    index = index + spsLength
    local numOfPPS, ppsLength = string.unpack('>BI2', data, index)
    index = index + 3
    local pps = data:sub(index, index + ppsLength - 1)

    -- output
    local result = {
        avcProfile = avcProfile, profileCompatibility = profileCompatibility, avcLevel = avcLevel,
        pps = pps, sps = sps
    }

    return result;
end

function flv.encodeAvcHeader(naluType, naluData, timestamp)
    local frameType = 0x02 -- non key frame
    if (naluType == NALU_TYPE_I) then
        frameType = 0x01 -- key frame
    end

    frameType = frameType << 4
    frameType = frameType + 0x07 -- AVC

    local avcPacketType = 0x01 -- nalu
    local avcTimestamp = 0
    local naluSize = #naluData
    local videoHeader = string.pack('>BBI3I4', frameType, avcPacketType, avcTimestamp, naluSize)
    return videoHeader
end

-- ----------------------------------------------------------------------------
-- Chunk Message Encode

local MESSAGE = {}
exports.MESSAGE = MESSAGE

MESSAGE.SET_CHUNK_SIZE                  = 0x01
MESSAGE.ABORT_MESSAGE                   = 0x02
MESSAGE.ACKNOWLEDGEMENT                 = 0x03
MESSAGE.USER_CONTROL_MESSAGE            = 0x04
MESSAGE.WINDOW_ACKNOWLEDGEMENT_SIZE     = 0x05
MESSAGE.SET_PEER_BANDWIDTH              = 0x06
MESSAGE.AUDIO_MESSAGE                   = 0x08
MESSAGE.VIDEO_MESSAGE                   = 0x09
MESSAGE.DATA_MESSAGE                    = 0x12
MESSAGE.COMMAND_MESSAGE                 = 0x14

function exports.encodeBasicHeader(options)
    local chunkStreamId = options.chunkStreamId or 0x05
    local fmt = options.fmt or RTMP_CHUNK_TYPE_0
    local basicHeader = (fmt << 6) | chunkStreamId

    return  string.pack('>B', basicHeader)
end

-- Encode Chunk Header
-- @param bodySize {Number} message body length
-- @param options {Object} options
-- - fmt {Number}
-- - chunkStreamId {Number}
-- - timestamp {Number}
-- - messageStreamId {Number}
-- - messageType {Number}
-- @return {Buffer} Chunk header data
function exports.encodeChunkHeader(bodySize, options)
    options = options or {}

    -- basic header
    local chunkStreamId = options.chunkStreamId or 0x00
    local fmt = options.fmt or RTMP_CHUNK_TYPE_0
    local basicHeader = (fmt << 6) | chunkStreamId

    -- message header
    local timestamp         = options.timestamp or 0x00
    local messageLength     = bodySize or 0x00
    local messageType       = options.messageType or 0x00
    local messageStreamId   = options.messageStreamId or 0x00

    -- encode
    local header = nil
    if (fmt == RTMP_CHUNK_TYPE_0) then
        header = string.pack('>BI3I3B<I4', basicHeader, timestamp, messageLength, messageType, messageStreamId)

    elseif (fmt == RTMP_CHUNK_TYPE_1) then
        header = string.pack('>BI3I3B', basicHeader, timestamp, messageLength, messageType)

    elseif (fmt == RTMP_CHUNK_TYPE_2) then
        header = string.pack('>BI3', basicHeader, timestamp)

    elseif (fmt == RTMP_CHUNK_TYPE_3) then
        header = string.pack('>B', basicHeader)
    end

    return header;
end

-- Encode Control Message
-- @param messageType {Number} message type
-- @param value {Number} value
-- @param options {Object} options
-- - fmt {Number}
-- - chunkStreamId {Number}
-- - timestamp {Number}
-- - messageStreamId {Number}
-- @return {Buffer} message data
function exports.encodeControlMessage(messageType, value, options)
    local body = nil

    if (messageType == MESSAGE.SET_CHUNK_SIZE) then -- Set Chunk Size
        body = string.pack('>I4', value)

    elseif (messageType == MESSAGE.ABORT_MESSAGE) then -- Abort Message
        body = string.pack('>I4', value)

    elseif (messageType == MESSAGE.ACKNOWLEDGEMENT) then -- Acknowledgement 
        body = string.pack('>I4', value)

    elseif (messageType == MESSAGE.WINDOW_ACKNOWLEDGEMENT_SIZE) then -- Window Acknowledgement Size
        body = string.pack('>I4', value)

    elseif (messageType == MESSAGE.SET_PEER_BANDWIDTH) then -- Set Peer Bandwidth
        body = string.pack('>I4B', value, 0x02)
    end

    if (not body) then
        return
    end

    options = options or {}
    options.fmt = RTMP_CHUNK_TYPE_0

    if (not options.chunkStreamId) then
        options.chunkStreamId = 0x04
    end

    options.messageType = messageType

    local header = exports.encodeChunkHeader(#body, options)
    return exports.encodeChunkMessage(body, options)
end

-- Encode Command Message
-- @param data {Array} Command message array
-- @param options {Object} Options
-- - fmt {Number}
-- - chunkStreamId {Number}
-- - timestamp {Number}
-- - messageStreamId {Number}
-- @return {Buffer} message data
function exports.encodeCommandMessage(data, options)
    options = options or {}

    if (not options.fmt) then
        options.fmt = RTMP_CHUNK_TYPE_1
    end

    if (not options.chunkStreamId) then
        options.chunkStreamId = 0x03
    end

    options.messageType = MESSAGE.COMMAND_MESSAGE

    local body = amf0.encodeArray(data)
    return exports.encodeChunkMessage(body, options)
end

-- Encode Data Message
-- @param data {Array} Data message array
-- @param options {Object} Options
-- - fmt {Number}
-- - chunkStreamId {Number}
-- - timestamp {Number}
-- - messageStreamId {Number}
-- @return {Buffer} message data
function exports.encodeDataMessage(data, options)
    options = options or {}
    if (not options.fmt) then
        options.fmt = RTMP_CHUNK_TYPE_0
    end

    if (not options.chunkStreamId) then
        options.chunkStreamId = 0x04
    end

    options.messageType = MESSAGE.DATA_MESSAGE

    local body = amf0.encodeArray(data)
    return exports.encodeChunkMessage(body, options)
end

-- Encode Video Message
-- @param data {Array} Video sample data
-- @param options {Object} Options
-- - fmt {Number}
-- - chunkStreamId {Number}
-- - timestamp {Number}
-- - messageStreamId {Number}
-- @return {Buffer} message data
function exports.encodeVideoMessage(sampleData, options)
    options = options or {}
    if (not options.fmt) then
        options.fmt = RTMP_CHUNK_TYPE_0
    end

    if (not options.chunkStreamId) then
        options.chunkStreamId = 0x04
    end

    options.messageType = MESSAGE.VIDEO_MESSAGE
    return exports.encodeChunkMessage(sampleData, options)
end

-- Encode Audio Message
-- @param data {Array} Audio sample data
-- @param options {Object} Options
-- - fmt {Number}
-- - chunkStreamId {Number}
-- - timestamp {Number}
-- - messageStreamId {Number}
-- @return {Buffer} message data
function exports.encodeAudioMessage(sampleData, options)
    options = options or {}
    if (not options.fmt) then
        options.fmt = RTMP_CHUNK_TYPE_0
    end

    if (not options.chunkStreamId) then
        options.chunkStreamId = 0x04
    end

    options.messageType = MESSAGE.AUDIO_MESSAGE
    return exports.encodeChunkMessage(sampleData, options)
end

-- Encode Chunk Message
-- @param messageBody {Array} Message data
-- @param options {Object} Options
-- - fmt {Number}
-- - chunkStreamId {Number}
-- - timestamp {Number}
-- - messageStreamId {Number}
-- - messageType {Number}
-- @return {Buffer} chunks data
function exports.encodeChunkMessage(messageBody, options)
    local header = exports.encodeChunkHeader(#messageBody, options)

    local chunkSize = options.chunkSize or 60000
    local payloadSize = #messageBody
    local payloadOffset = 1

    local list = {}
    list[#list + 1] = header

    options.fmt = RTMP_CHUNK_TYPE_3
    while (payloadSize > 0) do
        if (payloadSize > chunkSize) then
            list[#list + 1] = messageBody:sub(payloadOffset, payloadOffset + chunkSize - 1)
            payloadSize = payloadSize - chunkSize
            payloadOffset = payloadOffset + chunkSize

            list[#list + 1] = exports.encodeBasicHeader(options)

        else
            list[#list + 1] = messageBody:sub(payloadOffset, payloadOffset + payloadSize - 1)
            payloadSize = payloadSize - chunkSize
            payloadOffset = payloadOffset + chunkSize
        end
    end

    local message = table.concat(list)
    return message
end

-- ----------------------------------------------------------------------------
-- Chunk Message Decode

-- Parse Chunk Header
-- @param data {Array} Chunk data
-- @param pos {Number} Chunk data offset
-- @return {Object} chunk header info
function exports.parseChunkHeader(data, pos)
    local index = pos or 1
    -- basic header
    local basicHeader = data:byte(index + 0);
    local fmt = basicHeader >> 6
    local chunkStreamId = basicHeader & 0x3F;

    -- message header
    local timestamp, messageLength, messageType, messageStreamId;
    local headerSize = 1

    messageLength = exports.messageLength
    messageType = exports.messageType

    if (fmt == RTMP_CHUNK_TYPE_0) then
        headerSize = 12
        local limit = index + headerSize
        if #data < (limit - 1) then
            return
        end

        timestamp, messageLength, messageType, messageStreamId = string.unpack('>I3I3B<I4', data, index + 1);

    elseif (fmt == RTMP_CHUNK_TYPE_1) then
        headerSize = 8
        local limit = index + headerSize
        if #data < (limit - 1) then
            return
        end

        timestamp, messageLength, messageType = string.unpack('>I3I3B', data, index + 1);

    elseif (fmt == RTMP_CHUNK_TYPE_2) then
        headerSize = 4
        local limit = index + headerSize
        if #data < (limit - 1) then
            return
        end

        timestamp = string.unpack('>I3', data, index + 1);
    end

    local header = {
        fmt = fmt,
        chunkStreamId = chunkStreamId,
        timestamp = timestamp,
        headerSize = headerSize,
        messageLength = messageLength,
        messageType = messageType,
        messageStreamId = messageStreamId
    }

    exports.messageLength = messageLength
    exports.messageType = messageType

    return header
end

-- Parse Chunk Body
-- @param data {Array} Chunk data
-- @param pos {Number} Chunk data offset
-- @param header {Object} chunk header info
-- @return {Object} message body info
function exports.parseChunkBody(data, pos, header)
    local index = pos or 1

    local body = nil
    local type = nil
    local raw = nil
    local messageType = header.messageType
    local headerSize = header.headerSize

    local limit = index + headerSize + header.messageLength
    if #data < (limit - 1) then
        return
    end

    raw = data:sub(index + headerSize, limit - 1)

    if (messageType == 0x01) then
        type = 'Set Chunk Size'
        body = string.unpack('>I4', data, index + headerSize)

    elseif (messageType == 0x02) then
        type = 'Abort Message'
        body = string.unpack('>I4', data, index + headerSize)

    elseif (messageType == 0x03) then
        type = 'Acknowledgement '
        body = string.unpack('>I4', data, index + headerSize)

    elseif (messageType == 0x04) then
        type = 'User Control Message'
        local eventType, eventData = string.unpack('>I2I4', data, index + headerSize)
        body = {
            eventType = eventType,
            eventData = eventData
        }

    elseif (messageType == 0x05) then
        type = 'Window ACK Size'
        body = string.unpack('>I4', data, index + headerSize)

    elseif (messageType == 0x06) then
        type = 'Set Peer Bandwidth'
        -- TODO: error
        local windowSize, limitType = string.unpack('>I4I2', data, index + headerSize)
        body = { windowSize, limitType }

    elseif (messageType == 0x07) then

    elseif (messageType == 0x08) then
        type = 'Audio Message'

    elseif (messageType == 0x09) then
        type = 'Video Message'

    elseif (messageType == 0x0F) then
        type = 'AMF0 Data Message'
        body = amf0.parseArray(data, index + headerSize, limit)

    elseif (messageType == 0x12) then
        type = 'AMF0 Data Message'
        body = amf0.parseArray(data, index + headerSize, limit)

    elseif (messageType == 0x11) then
        type = 'AMF0 Command Message'
        body = amf0.parseArray(data, index + headerSize, limit)

    elseif (messageType == 0x14) then
        type = 'AMF0 Command Message'
        body = amf0.parseArray(data, index + headerSize, limit)    
    end

    header.type = type

    return body, raw
end

-- Parse Chunk
-- @param data {Array} Chunk data
-- @param pos {Number} Chunk data offset
-- @return {Object} chunk header info
-- @return {Object} message body info
function exports.parseChunk(data, pos)
    local header = exports.parseChunkHeader(data, pos)
    if (not header) then
        return
    end

    -- console.log(header)

    local index = pos or 1
    local headerSize = header.headerSize or 0
    local messageLength = header.messageLength or 0

    local limit = index + headerSize + messageLength
    if #data < (limit - 1) then
        return
    end

    -- console.log(#data, limit)

    local body, raw = exports.parseChunkBody(data, pos, header);
    return header, body, raw
end

return exports
