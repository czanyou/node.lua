# TS 传输流

[TOC]

## 类 ts_reader_t

通过 `require('media/reader')` 调用。

用于解析 TS 流.

目前支持 H.264 和 AAC 复合流, 暂时不支持其他格式

### 常量 FLAG_IS_AUDIO

    FLAG_IS_AUDIO = 0x8000

表示音频流标记

### 常量 FLAG_IS_END

    FLAG_IS_END = 0x02

表示帧结束标记

### 常量 FLAG_IS_START

    FLAG_IS_START = 0x04

表示帧开始标记

### 常量 FLAG_IS_SYNC

    FLAG_IS_SYNC = 0x01

表示同步点

### reader.open

    lreader.open(callback)

创建一个 TS 流 Reader.

返回创建的 ts_reader_t 类的实例.

随后通过 read 方法解析 TS 流, 解析后的 ES 流通过 callback 回调给应用程序.

- callback {Function} `- function(sampleData, sampleTime, flags)` 回调函数
  + sampleData {String} 媒体流内容, 可能只是一帧的一个分片
  + sampleTime {Number} 时间戳, 来自 TS 流
  + flags {Number} 标记

这里回调方法中并不会一次返回完整的一帧, 每次只返回部分分片.

FLAG_IS_START 表示这个分片是一帧数据的开始, FLAG_IS_AUDIO 表示这是音频流.

应用程序需要自己实现拼接成完整的视频或音频帧.


### reader:close

    reader:close()

关闭这个 Reader, 并释放相关的资源


### reader:read

    reader:read(packetData, flags)

读取并解析 TS 流

- packetData {String} TS 流数据
- flags {Number} 标记, 暂时没有用到

这个方法可以传入任意长度的 TS 流的数据, 不必是完整的 TS 包.

示例:

```lua
local lreader = require('media/reader')

local reader = lreader.open(function(sampleData, sampleTime, flags)
  if (flags & lreader.FLAG_IS_AUDIO) ~= 0 then
    -- TODO: Audio stream
  else
    -- TODO: Video stream
  end

end)

while (true) do
  local data = read()
  if (not data) then
    break
  end

  reader.read(data)
end

```


## 类 ts_writer_t

通过 `require('media/writer')` 调用。

用于生成 TS 流.

目前只支持 H.264 和 AAC 编码格式

### 常量 FLAG_IS_AUDIO

    FLAG_IS_AUDIO = 0x8000

音频流标记

### 常量 FLAG_IS_END

    FLAG_IS_END = 0x02

表示帧结束标记

### 常量 FLAG_IS_START

    FLAG_IS_START = 0x04

表示帧开始标记

### 常量 FLAG_IS_SYNC

    FLAG_IS_SYNC = 0x01

表示同步点

### writer.open

    lwriter.open(callback)

创建一个 TS 流 Writer.

- callback {Function} `- function(packet, sampleTime, flags)` 当生成新的 TS 包时调用这个方法
  + packet {String} 代表一个完整的 TS 包
  + sampleTime {Number} 时间戳, 来源于调用 write 方法时传入的时间戳
  + flags {Number} 标记
  
标记:

- FLAG_IS_END 表示是这完整的一帧的最后一个分片
- FLAG_IS_SYNC 表示这是一个视频流的同步点
- FLAG_IS_AUDIO 表示这是音频流

返回创建的 ts_writer_t 类的实例.

随后可以调用 write 方法写入要打包的 ES 流, 生成的 TS 流会通过 callback 传递给应用程序.


### writer:close

    writer:close()

关闭这个 Writer, 并释放相关的资源.


### writer:write

    writer:write(sampleData, sampleTime, flags)

写入流, 一次写入完整的一帧.

- sampleData {String} 要写入的数据, 支持 H.264 和 AAC, 只支持以帧的方式写入.
- sampleTime {Number} 要写入的数据的时间戳, 单位为毫秒
- flags {Number} 数据标记, 可以由多个标记组成, 定义如下:

标记:

+ FLAG_IS_SYNC 表示这是一个视频流的同步点, 视频流必须设置, 否则生成的 TS 频流没有同步信息, 导致无法播放.
+ FLAG_IS_AUDIO 表示这是音频流

示例:

```lua
local lwriter = require('media/writer')

local writer = lwriter.open(function(packet, sampleTime, flags)
  --TODO: write(packet)
end)

local flags = lwriter.FLAG_IS_SYNC

local sampleData, sampleTime = getNextSample()
write.write(sampleData, sampleTime, flags)

sampleData, sampleTime = getNextSample()
write.write(sampleData, sampleTime, 0)

```


