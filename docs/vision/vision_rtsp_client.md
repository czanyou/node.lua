# RTSP 客户端

[TOC]

连接 RTSP 服务器并获取媒体流

通过 `require('rtsp/client')` 调用。

## 通信流程 

```seq
# 示意图
客户端->服务端:  OPTIONS 
服务端-->客户端: 200 OK
客户端->服务端:  DESCRIBE 
服务端-->客户端: 200 OK with SDP
客户端->服务端: SETUP video track with Transport
服务端-->客户端: 200 OK
客户端->服务端: SETUP audio track with Transport
服务端-->客户端: 200 OK
客户端->服务端: PLAY
服务端-->客户端: 200 OK
服务端->客户端: TS Stream over RTP/RTSP
客户端->服务端: TEAMDOWN
服务端-->客户端: 200 OK
```

## RTSP 状态

### rtsp.STATE_STOPPED

停止状态, 表示客户端刚刚创建或已经关闭

这个状态表示网络连接是断开的, 不能发送或接收任何消息.


### rtsp.STATE_INIT

初始化状态, 当客户端发送了 DESCRIBE 请求或收到 TEARDOWN 应答之后

在这个状态下客户端可以发送 SETUP 来设置传输方式


### rtsp.STATE_READY

准备就绪状态, 当客户端收到 SETUP/PAUSE 应答之后

在这个状态下客户端可以发送 PLAY 来开始播放

在这个状态下客户端可以发送 TEARDOWN 来关闭连接


### rtsp.STATE_PLAYING

正在播放状态, 当客户端收到 PLAY 应答之后

在这个状态下客户端可以发送 PAUSE 来暂停播放

在这个状态下客户端可以发送 TEARDOWN 来停止播放


### rtsp.STATE_RECORDING

正在录像状态, 当客户端收到 RECORD 应答之后

在这个状态下客户端可以发送 PAUSE 来暂停录像

在这个状态下客户端可以发送 TEARDOWN 来停止录像


## rtsp.openURL

    rtsp.openURL(url)

打开指定的 RTSP URL 地址，并返回相关的 RTSP 客户端对象

这个方法会自动调用 RtspClient:open

- url RTSP URL 地址, 比如 'rtsp://test.com:554/live.mp4'

## 类 `RtspClient`


### 事件 'connect'

当连接到 RTSP 服务器时


### 事件 'close'

当这个 RTSP 关闭时


### 事件 'describe'

当收到 SDP 描述信息时

    function(sdpString)

- sdpString {String} SDP 字符串


### 事件 'error'

当发生连接等错误时

    function(error)

- error {String} 错误信息


### 事件 'response'

当收到应答消息时

    function(request, response)

- request {Object}
- response {Object}

### 事件 'sample'

当收到新的数据包时

    function(sample)

sample: 

```lua
{
  data = {'...','...', ... }, 
  isEnd = true, 
  isFragment = true, 
  isStart = false, 
  isVideo = true,
  marker = true, 
  payload = 97, 
  rtpTime = 1443572477, 
  sampleTime = 16039694, 
  sequence = 152
}
```

- data {Array} 这个 Sample 的有效负载内容
- isEnd {Boolean} 这个 Sample 的分片结束标记，源自 RTP 包
- isFragment {Boolean} 这个 Sample 的分片标记，源自 RTP 包
- isStart {Boolean} 这个 Sample 的分片开始标记，源自 RTP 包
- isVideo {Boolean} 指出这个 Sample 是否属视频流
- marker {Boolean} 这个 Sample 的 marker 标记，表示是否是一帧的最后一个包，源自 RTP 包
- payload {Number} 这个 Sample 的 RTP 负载格式，源自 RTP 包
- rtpTime {Number} 这个 Sample 的 RTP 时间，源自 RTP 包
- sampleTime {Number} 这个 Sample 的时间戳，单位为 1/1000 秒
- sequence {Number} 这个 Sample 的序列号，源自 RTP 包

H.264 NALU 是 H.264 图像帧的基本组成部分，一帧视频由 1 到多个 NALU 组成。

注意只有当 isFragment 为 true 时, isStart 和 isEnd 才有意义，表示这是一个 H.264 NALU 分片。
使用 RTP 传输时，一个 RTP 包通常不会超过 1500, 而一个 NALU 的大小则经常会超过 1500，所以一个
NALU 会被分成多个小于 1500 的分片来传输，isStart 表示这个 NALU 第一个分片，isEnd 表示这个 NALU
的最后一个分片。

一个视频帧由多个 sample 组成，marker 则用来标记一个视频帧是否结束

应用程序首先要将多个分片组成完整的 NALU, 然后再将 1 到多个 NALU 组成完整的一帧，才能用于解码.

```lua
    rtspClient:on('sample', function(sample)
      if (not sample.isVideo) then
        return
      end

      if (not lastSample) then
        lastSample = {}
      end

      local buffer = sample.data[1]
      if (not buffer) then
        return
      end

      local startCode = string.char(0x00, 0x00, 0x00, 0x01)
      
      if (not sample.isFragment) or (sample.isStart) then
        local naluType = buffer:byte(1) & 0x1f
        --print('naluType', naluType)
        if (naluType ~= 1) then
          console.log('sample: ', naluType, sample.sampleTime, sample.sequence)
        end

        table.insert(lastSample, startCode)
      end

      for _, item in ipairs(sample.data) do
        table.insert(lastSample, item)
      end

      if (sample.marker) then
        local sampleData = table.concat(lastSample)
        lastSample.sampleTime   = sample.sampleTime
        lastSample.isVideo    = sample.isVideo

        -- TODO: lastSample

        lastSample = nil
      end
    end)
```

### 事件 'state'

    function(state)

当连接状态发生改变时

- state {String} 连接状态

### 事件 'ts'

    function(rtpInfo, packet, offset)

处理收到的 TS 流数据包

当客户端收到的是 TS 流, 它不会解析流的内容, 而是直接将数据包转交给上层处理.

- rtpInfo {Object} RTP 包头信息, 一般可以忽略，因为 TS 流本身包含了足够多的信息。
- packet {String} 包含 TS 流数据包的缓存区对象
- offset {Number} 有效数据偏移位置

packet 中包含了多个 TS 包，每个包的长度固定为 188, 开始位置为 offset。

示例：

```lua

  local TS_PACKET_SIZE = 188

  rtspClient:on('ts', function(rtpInfo, data, offset)
    local leftover = #data - offset + 1
    while (leftover >= TS_PACKET_SIZE) do

      local packet = data:sub(offset, offset + TS_PACKET_SIZE - 1)
      --print(leftover, #packet)
      ...

      offset   = offset   + TS_PACKET_SIZE
      leftover = leftover - TS_PACKET_SIZE
    end

  end)

```


### RtspClient.rtspState

这个客户端当前连接状态


### RtspClient.isMpegTSMode

指出这个客户端接收的是否是 TS 流


### RtspClient.mediaTracks

当前打开的 URL 包含的媒体轨道信息数组, 如视频流, 音频流

如下例所示, 它详细描述了每个媒体轨道的信息:

```lua
{
  { 
    attributes = { 
      control = 'trackID=1', 
      fmtp = '96 profile-level-id=1;mode=AAC-hbr;sizelength=13;indexlength=3;indexdeltalength=3;config=1490', 
      rtpmap = '96 mpeg4-generic/12000/2'
    }, 
    control = 'trackID=1', 
    mode = 'RTP/AVP', 
    payload = 96, 
    port = 0, 
    type = 'audio'
  }, { 
    attributes = { 
      cliprect = '0,0,160,240', 
      control = 'trackID=2', 
      fmtp = '97 packetization-mode=1;profile-level-id=42C01E;sprop-parameter-sets=Z0LAHtkDxWhAAAADAEAAAAwDxYuS,aMuMsg==', 
      framerate = '24.0', 
      framesize = '97 240-160', 
      rtpmap = '97 H264/90000'
    }, 
    control = 'trackID=2', 
    mode = 'RTP/AVP', 
    payload = 97, 
    port = 0, 
    type = 'video'
  } 
}
```

### RtspClient:close

    RtspClient:close()

关闭这个 RTSP 客户端


### RtspClient:open

    RtspClient:open(url)

打开指定的 RTSP URL 地址

- url RTSP URL 地址, 比如 'rtsp://test.com:554/live.mp4'
