# RTMP Client

RTMP 客户端模块

可以通过 `require('rtmp/client')` 调用这个模块

## client

### 状态

- client.STATE_STOPPED = 0; 停止状态
- client.STATE_INIT = 1; 已建立了 Socket 连接
- client.STATE_HANDSHAKE = 2; 完成握手
- client.STATE_CONNECTED = 5; connect 命令执行成功
- client.STATE_CREATE_STREAM = 6; createStream 命令执行成功
- client.STATE_PUBLISHING = 8; publish 命令执行成功
- client.STATE_PLAYING = 9; play 命令执行成功

### RTMPClient 类

#### 属性

- appName `string` 应用名称，总是为 `live`
- audioSamples `integer`
- connected `boolean` 是否已连接
- id `string` ID
- isNotDrain `boolean` 发送缓存区没有排干
- isPublish `boolean` 是否为推流模式
- isStartStreaming `boolean` 是否开始推流
- lastActiveTime `integer` 最后活跃时间
- lastError `string` 最后发生的错误
- metadata `table` 收到的元数据
- peerChunkSize `integer`
- socket `Socket` 相关的 Socket
- startTime `integer` 开始时间
- state `integer` 当前状态
- streamId `string` RTMP 流 ID
- streamName `string` 流名称
- urlObject `URL` URL 对象
- urlString `string` URL 字符串
- videoParameterSets `string` 视频配置信息
- isVideoConfigurationSent `boolean` 是否已发送
- videoSamples `integer`
- windowAckSize `integer`

#### 事件

- close `function()` 当客户端被关闭
- error `function(error)` 当发生错误
  - error 错误信息
- connect `function()` 当连接到服务器
- state `function(state) `状态发生变化
  - state 新的状态
- startStreaming `function()` 开始推送流
- command `function(header, body)` 收到命令消息
  - header 消息头
  - body 消息体
- metadata `function(header, body)` 收到元数据信息
  - header 消息头
  - body 消息体
- video `function(header, body, raw)` 当收到视频帧
  - header 消息头
  - body 消息体
  - raw 原始数据

#### new

创建一个新的 RTMPClient 类实例

> RTMPClient:new(options)

options 选项:

- timeout 连接超时，默认为 5 秒

#### close

关闭客户端

> RTMPClient:close(error)

- error 关闭客户端的错误原因 (如果存在的话)

#### connect

开始连接到指定的服务器

- 创建 Socket 并建立 TCP 连接
- 握手
- 创建 RTMP 连接
- 创建 RTMP 流
- 开始推流或者拉流
- 发送/接收媒体元数据
- 发送/接收视频关键帧
- 继续发送/接收视频流

> RTMPClient:connect(urlString)

- urlString 服务器 URL 地址

#### getStateString

返回代表指定的 RTMP 状态的字符串

> RTMPClient:getStateString(state)

- state RTMP 状态

#### sendCreateStream

> RTMPClient:sendCreateStream()

发送创建 RTMP 流请求, 在 RTMP 连接建立后以及 publish 或 play 前调用 (STATE_CONNECTED)

#### sendPublish

> RTMPClient:sendPublish()

发送推流请求，在创建 RTMP 流后调用 (STATE_CREATE_STREAM)

#### sendPlay

> RTMPClient:sendPlay()

发送拉流请求，在创建 RTMP 流后调用 (STATE_CREATE_STREAM)

#### sendMetadataMessage

> RTMPClient:sendMetadataMessage()

发送 metadata 消息

这个消息主要用描述音视频编码类型，宽高度等信息

#### sendVideo

发送视频流, 即推流

> RTMPClient:sendVideo(data, timestamp, isSyncPoint)

- data `string` 视频流数据
- timestamp `integer` 视频流时间戳
- isSyncPoint `boolean` 是否是同步点
