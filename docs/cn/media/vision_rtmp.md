# RTMP

RTMP 实时消息协议

通过 `require('rtmp')` 调用。

## amf0

### amf0.null

代表 `null`数据类型

### amf0.parseValue

解析 amf0 格式的值

> amf0.parseValue(data, pos)

- data {Buffer} 要解析的 `amf0` 数据
- pos {integer} 可选，有效数据开始位置，默认为 1

返回:

- value {any} 数值
- offset {integer} 下一个 `amf0` 数据开始位置

### amf0.parseArray

解析 amf0 格式的数组

> amf0.parseArray(data, pos, limit)

- data {Buffer} 要解析的 `amf0` 数据
- pos {integer} 可选，有效数据开始位置，默认为 1
- limit {integer} 可选，有效数据结束限制位置

返回:

- result {table} 数组
- index {integer} 剩余的数据开始位置

### amf0.encodeArray

将一个 Lua 数据编码成相应的 amf0 数据格式

> amf0.encodeArray(array)

- array {array} 要编码的 Lua 数组

支持的数据类型:

- amf0.null 
- nil
- string
- number
- boolean
- table

## flv

### flv.encodeFileHeader

flv.encodeFileHeader()

- 返回 {string} header

### flv.encodeAvcHeader

flv.encodeAvcHeader(naluType, naluData, timestamp)

- naluType {integer} 视频 NALU 类型
- data {string} 视频 NALU 数据
- timestamp {integer} 视频时间戳
- 返回 {string} header

### flv.encodeTagHeader

flv.encodeTagHeader(tagType, tagSize, preTagSize, timestamp)

- tagType {integer} tag 类型
- tagSize {integer} tag 大小
- preTagSize {integer} 前一个 tag 的大小
- timestamp {integer} -- 毫秒
- 返回 {string} header

### flv.encodeVideoConfiguration

flv.encodeVideoConfiguration(sps, pps)

### flv.parseAudioTag

flv.parseAudioTag(data, offset)

- data {string} 音频 tag 数据
- offset {integer} 音频 tag 数据偏移地址
- 返回 {table} tag

### flv.parseFileHeader

flv.parseFileHeader(data, offset)

- data {string}
- offset {integer}
- 返回 {integer} offset

### flv.parseMetadataTag

flv.parseMetadataTag(data, offset)

- data {string} 元数据 tag 数据
- offset {integer} 元数据 tag 数据偏移地址
- 返回 {table} tag

### flv.parseTagHeader

flv.parseTagHeader(data, index)

- data {string}
- offset {integer}
- 返回 {integer} offset
- 返回 {table} tag

### flv.parseVideoConfiguration

flv.parseVideoConfiguration(data, offset)

- data {string} 视频参数集数据 tag 数据
- offset {integer} 视频参数集数据 tag 数据偏移地址
- 返回 {table} tag

### flv.parseVideoTag

flv.parseVideoTag(data, offset)

- data {string} 视频 tag 数据
- offset {integer} 视频 tag 数据偏移地址
- 返回 {table} tag

### 示例

读

```lua
local filepath = '/tmp/test.flv'
local fileData = fs.readFileSync(filepath)
local index = 1
index = rtmp.flv.parseFileHeader(fileData, index)
while (true) do
    if (index > #fileData - 8) then
        break
    end
    
    index, tag = flv.parseTagHeader(fileData, index)
    local tagData = fileData:sub(index, index + tag.tagSize - 1);
    if (not tagData) then
        break
    end
    
    if (tag.tagType == 0x09) then
        local result = flv.parseVideoTag(tagData)
        
    elseif (tag.tagType == 0x08) then
        local result = flv.parseAudioTag(tagData)
        
    elseif (tag.tagType == 0x12) then
        local result = flv.parseMetadataTag(tagData)
    end
    
    index = index + tag.tagSize
end
```

写

```lua
local filePath = '/tmp/test.flv'

local stream = fs.createWriteStream(filePath)

local fileHeader = flv.encodeFileHeader()
stream:write(fileHeader)

local lastTagSize = 0

if (metadata) then
    local tagSize = #metadata

    -- metadata tag
    local header = flv.encodeTagHeader(0x12, tagSize, lastTagSize)
    stream:write(header)
    stream:write(metadata)
    lastTagSize = tagSize
end

if (video) then
    local tagSize = #video

    -- video tag
    local header = flv.encodeTagHeader(0x09, tagSize, lastTagSize, tagTime)
    stream:write(header)
    stream:write(video)
    lastTagSize = tagSize
end

stream:finish()
```

## rtmp

### MESSAGE 消息类型

- MESSAGE.SET_CHUNK_SIZE                  = 0x01 
- MESSAGE.ABORT_MESSAGE                   = 0x02
- MESSAGE.ACKNOWLEDGEMENT                 = 0x03
- MESSAGE.USER_CONTROL_MESSAGE            = 0x04
- MESSAGE.WINDOW_ACKNOWLEDGEMENT_SIZE     = 0x05
- MESSAGE.SET_PEER_BANDWIDTH              = 0x06
- MESSAGE.AUDIO_MESSAGE                   = 0x08
- MESSAGE.VIDEO_MESSAGE                   = 0x09
- MESSAGE.DATA_MESSAGE                    = 0x12
- MESSAGE.COMMAND_MESSAGE                 = 0x14

## queue

### 常量定义

- queue.MAX_QUEUE_SIZE  = MAX_QUEUE_SIZE
- queue.FLAG_IS_SYNC    = FLAG_IS_SYNC
- queue.FLAG_IS_END     = FLAG_IS_END

### queue.newMediaQueue

> queue.newMediaQueue(...)

### MediaQueue 类

#### MediaQueue:initialize

> MediaQueue:initialize(maxSize)

- maxSize

#### MediaQueue:onSyncPoint

> MediaQueue:onSyncPoint()

#### MediaQueue:pop

> MediaQueue:pop()

#### MediaQueue:push

> MediaQueue:push(sampleData, sampleTime, flags)

- sampleData
- sampleTime
- flags

