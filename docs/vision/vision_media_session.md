# 媒体流会话

[TOC]

## 媒体流会话

通过 `require('media/session')` 引入这个模块.

媒体流会话是数据源和网络连接之间的关联，它能接收并缓存数据源产生的数据流，并将数据流发送到网络层。

RTSP/HTTP 连接可以调用 getSdpString 取得这个会话的媒体信息

然后 RTSP/HTTP 连接可以调用 readStart 方法告知会话可以往网络层发送媒体数据，因为网络发送速度可能慢于数据流的速度，RTSP 连接可以随时调用 readStop 方法暂停发送，防止网络层的数据缓存区过满.


#### session.newMediaSession

    session.newMediaSession(options)

返回创建的媒体会话


#### session.startCameraSession

    session.startCameraSession(name)

创建一个媒体会话, 并绑定到指定名称的摄像机

- name {String} 摄像机名称, `mock:<filename>` 表示由文件模拟的摄像机, `camera:<id>` 表示指定 ID 的摄像机

返回创建的媒体会话


### 类 MediaSession

#### MediaSession:close

    MediaSession:close()

关闭这个会话


#### MediaSession:flushBuffer

    MediaSession:flushBuffer()

推送缓存池中的数据，将会话发送队列中的数据推送到网络层。
这个方法会尽量地推送发送队列中的数据直到网络层缓存区也满了为止。

- 返回成功发送的媒体帧数量，0 表示未发送任何数据


#### MediaSession:getSdpString

    MediaSession:getSdpString()

返回这个会话相关的 SDP 字符串, 当用 RTSP 传输时可以用到


#### MediaSession:onSendSample

    MediaSession:onSendSample(sample)

编码指定的媒体帧, 默认的编码规则并 TS 流打包成 RTP 包.

这个方法只能在这个类内部被调用, 应用程序一般不可以直接调用这个方法

应用程序可以通过重载这个方法来改变编码规则

- sample {Object} 数据帧


#### MediaSession:onSendPacket

    MediaSession:onSendPacket(packet)

调用发送回调函数, 当应用程序重载 onSendSample 方法时, 需调用这个方法来发送编码后的数据.

调用这个方法后, 通过 readStart 设置的回调函数会被调用.

#### MediaSession:readStart

    MediaSession:readStart(callback)

开始发送数据流到网络层, 由 RTSP 连接调用，同时提供一个回调函数用来接收要发送的 RTP 包
- callback {Function} - function(packet) 用于发送数据流的回调函数
  + packet 要发送的数据包, 由 onSendPacket 方法提供


#### MediaSession:readStop

    MediaSession:readStop()

暂停发送数据流到网络层, 一般在网络连接发送队列已满时调用. 这时需要等待 'drain' 事件在网络连接发送队列被排空时, 再调用 readStart 继续发送媒体流.

在调用 readStop 暂停时, 并不会暂停视频源继续产生新的数据, 这时 MediaSession 会采取丢帧策略, 丢掉未及时发送的帧.


#### MediaSession:writePacket

    MediaSession:writePacket(packageData, sampleTime, flags)

write a TS packet

注意不要和 writeSample 同时使用.

- packageData {String} 媒体数据，暂时只接受 188 字节长的 TS 包
- sampleTime {Number} 媒体时间戳, 单位为 1 / 1,000,000 秒
- flags {Number} 媒体数据标记, 具体定义有为:
  +  0x01: 同步点(关键帧)
  +  0x02: 帧结束标记
  +  0x8000: 这是一个音频帧

#### MediaSession:writeSample

    MediaSession:writeSample(sample)

write a sample，媒体数据先放到会话的内部发送队列中。
因为数据源产生数据流的速度和网络发送数据的速度不一定匹配，这个会话通过
内部发送队列来调节两个流的关系（可能会延时发送或丢掉部分帧）。

注意不要和 writePacket 同时使用.

这个方法实际会在内部将 sample 转换成 TS 流, 再调用 writePacket 写入转换后的 TS 流.

- sample {Object}
  + syncPoint {Boolean} 是否是同步点
  + sampleData {String} 包含完整的一帧媒体数据
  + sampleTime {Number} 单位为 1 / 1,000,000 秒
  + isAudio {Number} 表示这是一个音频帧

## 示例

```lua
local session = require('media/session')

local mediaSession = session.startCameraSession('camera:1')

function onConnectionSend(connection, packet)
  local ret = connection.send(packet)
  if (not ret) then
    mediaSession.readStop()
  end
end

function onConnectionOpen(connection)
  mediaSession.readStart(function(packet)
    onConnectionSend(connection, packet)
  end)

end

function onConnectionDrain(connection)
  mediaSession.readStart(function(packet)
    onConnectionSend(connection, packet)
  end)
end

function onMediaStream(sample)
  mediaSession.writeSample(sample)
end


```
  
