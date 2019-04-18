# RTSP 推送服务

RTSP 推送服务用于将设备采集的音视频流，主动推送到媒体服务器。

通过 `require('rtsp/push')` 调用。

## 通信流程

```seq
# 示意图
设备->代理:  OPTIONS
代理-->设备: 200 OK
设备->代理:  ANNOUNCE with SDP
代理-->设备: 200 OK
设备->代理: SETUP with Transport
代理-->设备: 200 OK
设备->代理: RECORD
代理-->设备: 200 OK
设备->代理: TS Stream
设备->代理: TEAMDOWN
代理-->设备: 200 OK
```

## 方法

### push.openURL

    openURL(url, mediaSession)

创建一个新的到指定 URL 地址的 Pusher

- url 包含代理服务器的地址，端口，以及发布到代理服务器的流的名称
- mediaSession 要推送的媒体流会话

## 类 `RtspPusher`

### 事件 'close'

连接被关闭

### 事件 'connect'

连接被建立

### 事件 'error'

发生了错误

### pusher:close()

    close()

关闭这个 RtspPusher, 断开和服务器的连接并释放相关的资源

### pusher:open

    open(urlString, mediaSession)

连接到代理服务器

- url 包含代理服务器的地址，端口，以及发布到代理服务器的流的名称
- mediaSession 要推送的媒体流会话
