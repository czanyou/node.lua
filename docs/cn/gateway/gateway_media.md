# 多媒体

## 概述

视频直播和回放

### 摄像机

- 主、次音视频流
- 实时播放
- 云台控制
- 预置位控制

### 录像机

- 多通道
- 录像时间段列表
- 录像文件列表
- 录像回放
  - 快放
  - 慢放

## media

### 属性

- reloadTimer
- statusimer

### createThing

> media.createThing(options)

创建一个流媒体设备事物

### getStatus

> media.getStatus()

返回所有流媒体设备的状态

### start

> media.start()

启动所有流媒体设备

### stop

> media.stop()

停止所有流媒体设备

## Device

用来获取多媒体设备的信息或操作设备

这个模块会创建一个定时器，定时查询设备的状态，用来检测设备是否存在，以及读取基本的信息状态和信息

### 类 MediaThing

#### 属性

- deviceInformation `table` 设备信息
- errorCode `integer` 最后错误码
- getStatus `function` 当前状态
- lastError `string` 最后错误
- options `table` 选项
- profiles `table` 这个设备的所有视频通道属性
- readInfoTimer `Timer` 用来定时查询设备信息的定时器
- relaySession `RelaySession` 相关的转发会话
- secret `string` 注册密钥

#### config

读写配置参数

- read
- write

#### device

读取流媒体设备信息

- read

#### play

请求播放，支持实时预览和录像回放

注意: 同时只能存在一个会话

#### preset

预置位

- goto
- remove
- set

#### ptz

云台

- start
- stop

#### segment

录像时间段查询

- find/read

查询录像时间段

#### stop

停止播放

## RTMP

主要实现 RTMP 推流客户端功能

### 类 RtmpRelaySession

维持一个 RTMP 推流会话，接收收到音视频流，并将其推送到 RTMP 服务器

#### 属性

- `rtmpClient` `{RtmpClient}` 相关的 RTMP 客户端
- `rtmpMediaInfo` `{object}` 音视频媒体元数据信息
- `rtmpTimeout` `{integer}` 会话超时时间，单位为秒，默认为 30 秒, 超时后重新创建连接
- `rtmpUrl` `{url}` RTMP 服务器推流地址
- `videoParameterSets` `{string}` H.264 参数集等视频配置参数

#### sendAudioSample

> session:sendAudioSample(sampleData, sampleTime)

可选，发送音频数据

- sampleData `string` 帧内容
- sampleTime `integer` 时间戳, 单位为毫秒

#### sendVideoSample

> session:sendVideoSample(sampleData, sampleTime, isSyncPoint)

必需，发送视频数据

- sampleData `string` 帧内容, 包含了完整的一个 NALU 数据包
- sampleTime `integer` 时间戳, 单位为毫秒
- isSyncPoint `boolean` 是否是关键帧

#### setMediaInfo

> session:setMediaInfo(mediaInfo)

可选，设置媒体信息

- mediaInfo `RtmpMediaInfo`

#### setVideoParameterSets

> session:setVideoParameterSets(videoParameterSets)

必需，设置视频参数集

- videoParameterSets `table` 包含了 pps, sps 等 NALU 内容

#### stopSession

> session:stopSession(error)

停止这个会话，立即停止推流

- error `string`

注意：这只是临时关闭推流，到下一个定时器会重新创建连接，直到完全删除当前会话。

### 类 RtmpMediaInfo

#### 属性

- copyright `string` 版权信息
- width `integer` 视频宽度
- height `integer` 视频高度
- framerate `integer` 视频帧率
- videocodecid `integer` 视频编码 ID
- audiosamplerate `integer` 音频采样率
- audiocodecid `integer` 音频编码 ID

### rtmp.open

> rtmp.open(rtmpUrl, options)

打开并播放指定 URL 地址的音视频流

- rtmpUrl `string` RTMP 流地址
- options `table`
- return `RtmpClient` 返回创建的客户端

主要用于测试

### rtmp.publish

> rtmp.publish(did, rtmpUrl)

创建一个 RTMP 会话，用来向指定的 URL 地址推送音视频流

- did `string` 要推送的的视频设备的 ID
- rtmpUrl `string` 要推送的 RTMP 地址
- return `RtmpRelaySession` 返回创建的会话

## RTSP

主要实现 RTSP 拉流功能

### 类 RtspRelaySession

维持一个 RTSP 会话，不断地拉取音视频流并交给 RTMP 会话处理

#### 属性

- did `string` 相关的设备 ID
- lastActiveTime `number` 最后一次收到视频流的时间，用来判断是否超时
- options `RtspRelayOptions` 相关的 RTSP 选项
- rtspUrl `string` 相关的 RTSP 流地址
- rtspTimeout `integer` RTSP 会话超时时间，单位为秒，默认为 10 秒
- relaySession `RtmpRelaySession` 所属的 Relay 会话
- videoParameterSets `table` 最后收到的 pps, sps NALU 数据

#### setScale

> session:setScale(scale)

改变回放速度，只有当回放录像文件时有效

- scale `number` 1 表示 1x 倍速，即正常速度

#### stopSession

> session:stopSession()

停止这个会话，并立即停止拉流

### 类 RtspRelayOptions

- did `string` 视频设备 ID
- password `string` 访问密码
- url `string` 访问 URL 地址
- username `string` 访问用户名
- replay `boolean` 是否为回放模式
- channel `integer` 通道号，从 0 开始
- stream `integer` 码流类型, 0 表示主码流
- startTime `string` 开始时间, 如 `20200715112233`, 仅回放时有效
- endTime `string` 结束时间, 如 `20200715235959`, 仅回放时有效

### open

> rtsp.open(options)

创建一个新的 RTSP 会话

- options RTSP 选项

## Relay

### relay.maxSessionCount

- maxSessionCount `integer` 这个设备同时转发视频最大路数，默认为 4 路

### 类 RelaySession

#### 属性

- created `integer` 这个会话的创建时间
- lastError `string` 这个会话最后发生的错误
- lastPlayTime `integer` 这个会话最后一次调用 play() 的时间
- rtmpPlayers `integer` 当前 RTMP 服务器客户端数量
- rtmpSession `RtmpRelaySession` 相关的 RTMP 会话
- rtmpTimeout `integer` RTMP 会话超时时间, 单位为秒，默认为 60 秒
- rtmpUrl `string` 相关的 RTMP 推流地址
- rtspOptions `RtspRelayOptions` 相关的 RTSP 选项
- rtspSession `RtspRelaySession` 相关的 RTSP 会话
- sendBytes `integer` 已发送的字节数
- timeoutTimer Timer 会话超时定时器，会话超过 1 个小时将强制关闭会话

#### close

> RelaySession:close()

关闭这个会话

#### createRtmpSession

> RelaySession:createRtmpSession(options)

创建相关的 RTMP 推流会话

#### createRtspSession

> RelaySession:createRtspSession(options)

创建相关的 RTSSP 拉流会话

#### play

> RelaySession:play()

播放，可以重复调用，如果相关的 RTMP/RTSP 会话没有创建则会立即创建

当有新的播放客户端请求时会定期调用这个方法

#### setScale

> RelaySession:setScale(scale)

改变回放速度，只有当回放录像文件时有效

- scale `number` 1 表示 1x 倍速，即正常速度

#### stop

> RelaySession:stop()

立即停止推流和拉流

当没有播放客户端时或转发会话超时的时候会调用这个方法

### getRelaySession

> relay.getRelaySession(webThing, create)

- webThing `ExposedThing`
- create `boolean` 如果不存在的话，是否创建一个新的会话

### onPlay

> relay.onPlay(webThing, params)

- webThing `ExposedThing`
  - id
  - onvifClient
  - options
  - profiles
  - relaySession
- params

当指定的视频设备收到 play 操作请求

### onStop

> relay.onStop(webThing, error)

- webThing `ExposedThing`
  - id
  - relaySession
- error string


当指定的视频设备收到 stop 操作请求

## NVR

用来访问 NVR 设备信息

### 类 NVRSession

#### getDeviceInformation

> NVRSession:getDeviceInformation()

读取设备信息

#### getPreviewURL

> NVRSession:getPreviewURL()

返回视频实时预览 URL 地址

#### getReplayURL

> NVRSession:getReplayURL()

返回视频录像回放预览 URL 地址

#### getSegments

> NVRSession:getSegments()

读取录像片段信息

### createClient

> nvr.createClient(options)

创建一个 NVR 客户端

- options `ThingOptions`

