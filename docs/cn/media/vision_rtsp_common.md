# 公共模块

## SDP 会话描述协议

会话描述协议（Session Description Protocol，简称SDP）为会话通知、会话邀请和其它形式的多媒体会话初始化等目的提供了多媒体会话描述。

常和会话初始协议（SIP）、实时流协议（RTSP）等一起使用.

示例：

```html
v=0
o=- 535676825 535676825 IN IP4 184.72.239.149
s=BigBuckBunny_115k.mov
c=IN IP4 184.72.239.149
t=0 0
a=sdplang:en
a=range:npt=0- 596.48
a=control:*
m=audio 0 RTP/AVP 96
a=rtpmap:96 mpeg4-generic/12000/2
a=fmtp:96 profile-level-id=1;mode=AAC-hbr;sizelength=13;indexlength=3;indexdeltalength=3;config=1490
a=control:trackID=1
m=video 0 RTP/AVP 97
a=rtpmap:97 H264/90000
a=fmtp:97 packetization-mode=1;profile-level-id=42C01E;sprop-parameter-sets=Z0LAHtkDxWhAAAADAEAAAAwDxYuS,aMuMsg==
a=cliprect:0,0,160,240
a=framesize:97 240-160
a=framerate:24.0
a=control:trackID=239

```

### sdp.decode

    sdp.decode(sdpString)

解析指定的 SDP 字符串

- sdpString {string} SDP 字符串

返回解析后的 SdpSession 对象

### 类 'SdpSession'

#### SdpSession.getMediaCount

    SdpSession:getMediaCount()

返回这个 SDP 会话包含的 media 的数量

#### SdpSession.getMedia

    SdpSession:getMedia(type)

返回指定的类型的 media

-- type {string}，如 'video', 'audio', 等等

### 类 'SdpMedia'

#### SdpMedia:getAttribute

    SdpMedia:getAttribute(key)

返回指定的名称的属性的值

SDP 的属性都是以 "a=" 为前缀

#### SdpMedia:getFramerate

    SdpMedia:getFramerate(payload)

返回 framerate 属性的值

#### SdpMedia:getFramesize

    SdpMedia:getFramesize(payload)

解析并返回 framesize 属性的值

表示图像尺寸，如: framesize:97 240-160

#### SdpMedia:getRtpmap

    SdpMedia:getRtpmap(payload)

解析并返回 rtpmap 属性的值

表示编解码基本信息, 如：`rtpmap:97 H264/90000`，表示编码类型为 H.264, 时间戳频率为 90000

#### SdpMedia:getFmtp

    SdpMedia:getFmtp(payload)

解析并返回 fmtp 属性的值

表示编解码详细信息, 如 H.264 的 profile 级别，SPS，PPS 数据集等

例如：

`fmtp:97 packetization-mode=1;profile-level-id=42C01E;sprop-parameter-sets=Z0LAHtkDxWhAAAADAEAAAAwDxYuS,aMuMsg==`

在播放 H.264 流时，通常要先解析 fmtp 中的 sprop-parameter-sets 才能正常开始解码.

## RTSP 消息

### message.METHODS

常见的 RTSP 方法

- 'ANNOUNCE',
- 'DESCRIBE',
- 'GET_PARAMETER',
- 'OPTIONS',
- 'PAUSE',
- 'PLAY',
- 'RECORD',
- 'REDIRECT',
- 'SET_PARAMETER',
- 'SETUP',
- 'TEARDOWN'

### message.STATUS_CODES

常见的 RTSP 状态码以及其描述字符串.

```lua
message.STATUS_CODES = {
    [100] = 'Continue',
    ...
}
```

### message.parseAuthenticate

    message.parseAuthenticate(value)

- value {string} Authenticate 等消息头的值

返回解析后的对象

比如:

```c
Authorization: Digest realm="4419b727ab09", nonce="66bb9f0bf5ac93a909ac8e88877ae727", stale="FALSE", test=""\r\n
```

### message.newRequest

    message.newRequest(method, path)

返回创建的 RTSP 请求消息

- method {string} 请求方法
- path {string} 请求路径

### message.newResponse

    message.newResponse(statusCode, reason)

返回创建的 RTSP 应答消息

- statusCode {number} 100 ~ 699 应答码
- reason {string} 应答原因短语

### message.newDateHeader

    message.newDateHeader(time)

返回创建的 Date 消息头

- time {number} 时间，如果没有指定则为 os.time().

### 类 message.RtspHeaderMeta

消息头

### 类 message.RtspMessage

#### RtspMessage:checkAuthorization

    RtspMessage:checkAuthorization(request, callback)

检查指定的消息的 Authorization 的消息头

这个方法一般由服务端调用，检查客户端是否有有效的身份认证。

- request {RtspMessage Object} 要检查的消息
- callback {function} `function(username)` 回调函数
  - username {string} 客户端请求的用户名，返回这个用户的密码

下面是通信过程:

```lua

C => S:
DESCRIBE /test.mp4 RTSP/1.0
Seq: 1
Client: RTSP Client

S => C:
RTSP/1.0 401 Unauthorized
Seq: 1
WWW-Authenticate: Digest realm="4419b727ab09"
Server: RTSP Server

C => S:
DESCRIBE /test.mp4 RTSP/1.0
Seq: 2
Authorization: Digest realm="4419b727ab09", nonce="66bb9f0bf5ac93a909ac8e88877ae727", stale="FALSE", test=""
Client: RTSP Client

S => C:
RTSP/1.0 200 OK
Seq: 2
Server: RTSP Server
Content-Length: 100
Content-Type: application/sdp

v=1
...

```

#### RtspMessage:getHeader

    RtspMessage:getHeader(name)

返回指定名称的消息头的值

- name {string} 消息头的名称

#### RtspMessage:removeHeader

    RtspMessage:removeHeader(name)

删除指定名称的消息头的值

- name {string} 消息头的名称

#### RtspMessage:setAuthorization

    RtspMessage:setAuthorization(params, username, password)

设置 Authorization 消息头的值

RTSP 沿用的是 HTTP 的身份认证方法，常见的有 Digest，Basic 认证方式。

这个方法一般由客户端调用，当服务端返回 401 应答时，提供有效的身份认证信息。

- params {object} 请求参数
  - METHOD 认证方法名，源自 Authenticate, 如 'Digest', 'Basic'
  - realm 源自 Authenticate
  - nonce 源自 Authenticate
- username {string} 用户名
- password {string} 密码

#### RtspMessage:setHeader

    RtspMessage:setHeader(name, value)

设置指定名称的消息头的值

- name {string} 消息头的名称
- value {string} 消息头的值

#### RtspMessage:setStatusCode

    RtspMessage:setStatusCode(statusCode, statusText)

设置应答消息的状态码

- statusCode {number} 状态码
- statusText {string} 状态原因短语，如果未指定则使用状态码对应的默认短语

## RTP 会话

### rtp.RTP_MAX_SIZE

rtp.RTP_MAX_SIZE    = 1450

默认最大的 RTP 包的大小

因为 RTP 常使用 UDP 传输，而一个网络中 MTU 的大小不一

### rtp.RTP_PACKET_HEAD

rtp.RTP_PACKET_HEAD = 0x80

### rtp.newSession

    exports.newSession()

返回创建的 RTP 会话

### 类 RtpSession

#### RtpSession:decode

    RtpSession:decode(packet, offset)

解析指定的数据包

- packet {string} 包含 RTP 数据的缓存区
- offset {number} 有效数据的开始位置，如果没有指定则为 1

#### RtpSession:decodeHeader

    RtpSession:decodeHeader(packet, offset)

解析指定的数据包头信息

- packet {string} 包含 RTP 数据的缓存区
- offset {number} 有效数据的开始位置，如果没有指定则为 1

#### RtpSession:encode

    RtpSession:encode(data, timestamp)

把指定的流编码成 RTP 包

- data {string}
- timestamp {number} ，单位为毫秒 (1/1000)

#### RtpSession:encodeHeader

    RtpSession:encodeHeader(timestamp, isMaker)

- timestamp {number} 时间戳，单位为毫秒 (1/1000)
- isMaker {number} 指出是否是一帧的最后一个包

#### RtpSession:encodeTS

    RtpSession:encodeTS(packets, timestamp, isMaker)

把指定的 TS 流编码成 RTP 包

- packets 包含 TS 包的列表
- timestamp，单位为毫秒 (1/1000)
- isMaker 指出是否是一帧的最后一个包

#### RtpSession:getNaluStartLength

    RtpSession:getNaluStartLength(data)

- data {string} Nalu 数据

H.264 NAL 单元前常有 '00 00 01' 或 '00 00 00 01' 和引导码

## RTSP 编解码

用于 RTSP 消息流的编解码

### codec.newCodec

    codec.newCodec()

返回创建的新 RtspCodec 对象

### codec.parseHeaderValue

    codec.parseHeaderValue(line)

解析 RTSP 头的值, 比如

- line {string}

### 类 `RtspCodec`

#### 事件 packet

    function(packet)

当收到了完整的 RTP 数据包

- packet {string} RTP 数据包

#### 事件 response

    function(response)

当收到了完整的的 RTSP 应答消息

- response {RtspMessage Object} 应答消息

#### 事件 request

    function(request)

当收到了完整的的 RTSP 请求消息

- request {RtspMessage Object} 请求消息

#### RtspCodec:decode

    RtspCodec:decode(data)

以流的方式解析 RTSP 消息流，可以在收到任何长度的数据都丢给这个方法处理

- data {string} 要解码的消息流片段

当收到完整的消息时，会以事件的方式通知

#### RtspCodec:encode

    RtspCodec:encode(message)

返回对指定的 RTSP 消息进行编码后的字符串

- message {RtspMessage Object} 要编码的消息对象
