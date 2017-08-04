# RTSP 会话

[TOC]

## RTSP 连接

### 类 RtspConnection

代表一个 RTSP 服务端连接，和 RTSP 客户端是一对一的关系.

这个连接既可以发送客户端请求的媒体流，也可以接收客户端推送的媒体流


#### 属性 RtspConnection.isStreaming

{Boolean} 指出是否正在发送媒体流


#### 属性 RtspConnection.rtspState

{String} 这个连接当前 RTSP 状态


#### 属性 RtspConnection.sessionId

{String} 这个连接相关的 RTSP 会话的 ID


#### RtspConnection:close

    RtspConnection:close(errInfo)

关闭这个连接

- errInfo {String} 如果是因为发生错误而关闭连接


#### RtspConnection:getSdpString

    RtspConnection:getSdpString(urlString)

返回 RTSP 服务器指定的路径的媒体流的 SDP 描述信息，如果不存在则返回 nil

- urlString {String} RTSP 服务器上可供播放的媒体流的路径


#### RtspConnection:processMessage

    RtspConnection:processMessage(message)

处理收到的客户端发来的 RTSP 消息。

不同于 HTTP，RTSP 服务即可以接收请求消息，也可以主动发送请求消息给客户端，所以也会收到客户端的请求或应答消息。

- message {RtspMessage Object} 收到的由客户端发来的 RTSP 消息 


#### RtspConnection:sendResponse

    RtspConnection:sendResponse(response)

发送应答消息给客户端

同 HTTP 一样，RTSP 也采用一问一答的通信方式，所以对于每一个客户端请求都会回复一个应答消息 。

- response {RtspMessage Object} 要发送给客户端的应答

#### RtspConnection:start

    RtspConnection:start()

开始这个连接，即开始侦听客户端发来的数据


#### RtspConnection:startStreaming

    RtspConnection:startStreaming()

开始发送这个连接绑定的媒体流

必须在已经创建了相关的媒体会话之后才能调用这个方法.


#### RtspConnection:stopStreaming

    RtspConnection:stopStreaming()

停止正在发送的媒体流, 但不会关闭网络连接. 相当于暂停功能。

