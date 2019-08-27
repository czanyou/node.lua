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

- isStartStreaming 是否开始推流
- videoConfiguration 视频配置信息
- isPublish 是否为推流模式
- lastActiveTime 最后活跃时间
- appName 应用名称，总是为 `live`
- streamName 流名称
- streamId RTMP 流 ID
- urlString URL 字符串
- urlObject URL 对象
- connected 是否已连接
- id ID
- lastError 最后发生的错误
- isNotDrain 发送缓存区没有排干
- videoConfigurationSent 是否已发送
- startTime 开始时间
- socket 相关的 Socket
- windowAckSize
- peerChunkSize
- metadata 收到的元数据
- videoSamples
- audioSamples
- state 当前状态

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

> RTMPClient:connect(urlString)

- urlString 服务器 URL 地址

#### getStateString

返回代表指定的 RTMP 状态的字符串

> RTMPClient:getStateString(state)

- state RTMP 状态

#### sendVideo

发送视频流, 即推流

> RTMPClient:sendVideo(data, timestamp, isSyncPoint)

- data 视频流数据
- timestamp 视频流时间戳
- isSyncPoint 是否是同步点
