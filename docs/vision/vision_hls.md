# HLS (HTTP Live Streaming)

[TOC]

实现 HTTP 直播流协议

通过 `require('hls')` 调用。

## 类 PlayList

### 事件 item

### 事件 remove

播放列表, 当前只支持 m3u8 播放列表文件

### playlist:addItem

    playlist:addItem(path, duration)

添加一个分片

- duration {Number}
- path {String}

### playList:get

    playList:get(key)

返回指定名称的属性的值

- key {String} 属性名

### playList:getMediaSequence

返回第一个分片的序列号

相当于 `playList:get('EXT-X-MEDIA-SEQUENCE')`

### playList:getMaxDuration

返回当前列表中最长的分片的长度

### playList:parse

    playList:parse(text)

解析指定的列表

- text {String} m3u8 列表文件内容

### playList:removeItem

    playList:removeItem(index)

从列表头部删除一个分片

- index {Number} 如果没有指定则删除第一个项目

### playList:set

    playList:set(key, value)

设置指定名称的属性的值

- key {String} 属性名
- value {String} 属性值

### playList:setEndList

    playList:setEndList(isEndList)

### playList:setMediaSequence

    playList:setMediaSequence(sequence)

相当于 `playList:set('EXT-X-MEDIA-SEQUENCE', sequence)`

第一个分片的序号

### playList:setTargetDuration

    playList:setTargetDuration(duration)

相当于 `playList:set('EXT-X-TARGETDURATION', sequence)`

### playList:toString()

    playList:toString()


## reader.new_ts_reader

    reader.new_ts_reader()

## 类 Reader

TS 流解析器

### 事件 end

当流已经结束

### 事件 error

当发生错误

### 事件 packet

当解析出一帧数据

### 事件 start

当开始解析流

### reader:close

    reader:close()

关闭这个解析器

### reader:processPacket

    reader:processPacket(packet)

- packet {String} 只接受 188 字节长的 TS 流数据包

### reader:start

    reader:start()

开始解析

## segmenter.newSegmenter(options)

- options {Object} 初始化选项, 详情请参考 `Segmenter:new(options)`

## 类 Segmenter

HLS 分片工具
HLS 需要将 TS 流分成很多个很小的 TS 文件, 每个文件在 3 秒左右

### Segmenter:new(options)

- options {Object} 初始化选项
    + uid {String} 流的名称, 没有指定则默认为 'test'
    + basePath {String} 分片文件保存路径, 没是指定则默认为 '/tmp/live'
    + baseUrl {String} 分片文件访问路径, 没有指定则默认为 '/live'

这个 Segmenter 会将数据流保存为多个小的 TS 流分片文件, 并保存在本地文件系统.
需要另个启动一个 WEB 服务器才能使客户端通过 HLS 访问被分片的流.
相关的 WEB 服务器必须有一个指向分片文件保存的虚拟路径

比如 (创建一支流, uid 为 'test'):

- 分片文件保存目录为 `/tmp/live/test`
- m3u8 文件保存目录为 `/tmp/live/test/live.m3u8`
- 分片文件则保存为 `/tmp/live/test/segmenterX.ts`, 其中 X 为 1 到 9
- 通过 HTTP 访问的完整 URL 为 `http://localhost:80/live/test/live.m3u8`

### segmenter:close()

关闭这个分片器

### segmenter:getPlayList

    segmenter:getPlayList(path)

返回相关的 m3u8 文件内容 

### segmenter:push

    segmenter:push(sampleData, sampleTime, isSyncPoint)

处理一帧数据, 注意目前只支持 H.264 数据流

- sampleData {String} 要处理的媒体数据, 比如一个 H.264 NALU
- sampleTime {Number} 这一帧数据的采集时间, 单位为 1/1000000 秒
- isSyncPoint {Boolean} 指出当前是否是一个同步点, 视频流通常以 I 帧开始为同步点

## writer.new_ts_writer

    writer.new_ts_writer()

## writer.TS_PACKET_SIZE

    TS_PACKET_SIZE = 188

TS 流数据包的大小, 一般总是为 188 个字节

## writer.FLAG_IS_SYNC

    FLAG_IS_SYNC = 0x01

指出当前位置是一个同步点, 即一个关键帧的开始位置

## writer.FLAG_IS_END

    FLAG_IS_END		= 0x02

指出当前包是一个完整帧的最后一个包

## 类 Writer

TS 流生成器

### writer:close

关闭这个 Writer, 不再继续写数据

### writer:start

    writer:start(callback)

开始, 必须在 write 等方法之前调用

- callback {Function} -function(packet, sampleTime, flags) 当生成新的 TS 数据包时调用这个方法 
  * packet {String} 长度为 188 个字节的 TS 数据包
  * sampleTime {Number} 时间戳
  * flags {Number} 标记, 如 0x01 表示是一个同步点, 0x02 表示这是一帧的最后一个数据包.

### writer:write

    writer:write(data, sampleTime, isEnd)

写入一帧媒体数据, 目前只支持 H.264 数据流
这里可以写入一个 H.264 NALU 包.

- data {String} 数据帧内容, 必须是完整的一帧数据, 并包含 '00 00 00 01' 的前导码
- sampleTime {Number} 采集这一帧数据的时间戳
- isEnd {Boolean} 指出这个数据包是否是这帧数据的最后一个分片, 如果没有指定则默认为 true.

### writer:writeSyncInfo

    writer:writeSyncInfo(sampleTime)

尽快生成 PAT, PMT 等关键数据包.
TS 流解析器需要先解析 PAT, PMT 包的信息才开始解析媒体流
在 TS 文件的头部就必须有这两个包, 然后在流的中间也需要定时插入这两个包.
一般在文件的开始位置必须有 PAT, PMT 数据包, 其次可以在每个关键帧前再插入 PAT, PMT 数据包

- sampleTime {Number} 媒体流当前位置时间戳
