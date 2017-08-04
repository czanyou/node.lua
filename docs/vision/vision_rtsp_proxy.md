# RTSP 代理服务器

[TOC]

RTSP 代理用于接收设备端 RTSP 流推送，并维护相关的媒体流会话。

通过 `require('rtsp/proxy')` 调用。

## proxy.startServer

    startServer(port, options)

开始在指定的端口侦听并接受设备连接

## 类 `ProxySession`

### session:close

    close()

关闭这个会话

## 类 `RtspProxy`

### 事件 'close'

服务器被关闭

### 事件 'error'

发送错误

### 事件 'session'

创建的新的会话

### proxy:close

    close()

关闭这个代理服务器

### proxy:newMediaSession

    newMediaSession(pathname)

- pathname

创建一个指定路径的媒体会话，如果没有设备推送这个路径的流，则返回 nil

### proxy:start

    start(port)

- port

开始在指定的端口侦听并接受设备连接
