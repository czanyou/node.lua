# RTSP 服务器

[TOC]

一个简单 RTSP 服务器

通过 `require('rtsp/server')` 调用。

## server.startServer

    startServer(port, callback)

创建并启动一个 RTSP 服务

- port 要侦听的端口, 默认为 554
- callback(connection, pathname) 返回函数，返回 'pathname' 相关的 `MediaSession`

```lua

local rtspServer = server.startServer(554, function(connection, pathname)
    return mediaSession 
end)

```

## 类 `RtspServer`

### 事件 'connection'

当创建了新的连接

### 事件 'close'

服务被关闭

### 事件 'error'

发生错误

### RtspServer:close()

关闭这个服务

### RtspServer:start(port, callback)

    start(port, callback)

创建并启动一个 RTSP 服务

- port 要侦听的端口, 默认为 554
- callback(connection, pathname) 返回函数，返回 'pathname' 相关的 `MediaSession`
