# RTSP/RTP 媒体传输和控制协议

- 作者: 成真
- 联系方式: anyou@msn.com
- 更新日期: 2010 年 7 月 13 日

## 目录

[TOC]

## 更新历史

## 1 前言

本文档主要描述了 Vision7 Vision 系统中前端视频服务器(DVR, 网络摄像机), 
中心转发服务器以及客户端之间的多媒体通信以及控制协议.

本协议主要基于标准的 IETE 的 RTSP/RTP 以及相关协议, 
并针对具体应用定义了部分扩展.

本协议只是当前实现的总结和整理, 具体的协议细节以实际实现为准 

## 2 定义

- RTSP
    实现流协议

- SDP
    会话描述协议

- RTP
    实时传输协议

- H.264
    H.264 视频编码标准

## 3 RTSP 命令

### 3.1 Request 语法

语法:

RTSP 的语法和 HTTP 的语法基本相同, 具体如下。

```
COMMAND rtsp_URL RTSP/1.0&lt;CRLF&gt;
Headerfield1: val1&lt;CRLF&gt;
Headerfield2: val2&lt;CRLF&gt;
...
&lt;CRLF&gt;
[Body]
```

RTSP 消息行之间用回车换行 (CRLF) 分隔. 一个空行表示消息头部分的结束。

#### 3.1.1 RTSP 方法

COMMAND 表示 RTSP 命令名称, 是 DESCRIBE, SETUP, OPTIONS, PLAY, PAUSE, TEARDOWN 或 SET_PARAMETER 等的任意一个.

#### 3.1.2 RTSP URL

完整语法如下:

```
rtsp_URL  =   ( "rtsp:" | "rtspu:" )
                 "//" host [ ":" port ] [ abs_path ]
   host   =   (A legal Internet host domain name of IP address
                 (in dotted decimal form), as defined by Section 2.1
                of RFC 1123 \cite{rfc1123})
   port   =   *DIGIT
```

如: rtsp://&lt;servername&gt;/live.mp4[?&lt;param&gt;=&lt;value&gt;[&&lt;param&gt;=&lt;value&gt;...]]
&lt;servername&gt; 表示产品的主机名称或者 IP 地址.

#### 3.1.3 RTSP 版本

格式和 HTTP 协议类似, 且 RTSP 版本总是为 "RTSP/1.0"

#### 3.1.4 RTSP 头字段

下面是所有命令都接受的头字段类型，一些命令接受或者必须用到一些附加的特别的头字段。

| 头字段         | 描述                                | 
| ---            | ---                                 |
| Authorization  | 客户端的认证信息.                   | 
| CSeq           | 请求序列号.                         | 
| Session        | 会话 ID (返回自服务端的 SETUP 应答).| 
| Content-Length | 内容的长度.                         | 
| Content-Type   | 内容的媒体类型.                     | 
| User-Agent     | 关于创建这个请求的客户端的信息.     | 
| Require        | 查询是否支持指定的选项，不支持的选项会在 Unsupported 头中列出. | 


### 3.2 Response 语法

语法:

```
RTSP/1.0 &lt;Status Code&gt; &lt;Reason Phrase&gt; &lt;CRLF&gt;
Headerfield3: val3&lt;CRLF&gt;
Headerfield4: val4&lt;CRLF&gt;
...
&lt;CRLF&gt;
[Body]
```

应答的第一行包含了表示请求是否成功或者失败的状态码和原因短语. 在 RFC 2326 有对状态码的详细描述.

标准的 RTSP 应答状态码和原因短语:

```
 "100" ; Continue (all 100 range)
 "200" ; OK
 "201" ; Created
 "250" ; Low on Storage Space
 "300" ; Multiple Choices
 "301" ; Moved Permanently
 "302" ; Moved Temporarily
 "303" ; See Other
 "304" ; Not Modified
 "305" ; Use Proxy
 "350" ; Going Away
 "351" ; Load Balancing
 "400" ; Bad Request
 "401" ; Unauthorized
 "402" ; Payment Required
 "403" ; Forbidden
 "404" ; Not Found
 "405" ; Method Not Allowed
 "406" ; Not Acceptable
 "407" ; Proxy Authentication Required
 "408" ; Request Time-out
 "410" ; Gone
 "411" ; Length Required
 "412" ; Precondition Failed
 "413" ; Request Entity Too Large
 "414" ; Request-URI Too Large
 "415" ; Unsupported Media Type
 "451" ; Parameter Not Understood
 "452" ; reserved
 "453" ; Not Enough Bandwidth
 "454" ; Session Not Found
 "455" ; Method Not Valid in This State
 "456" ; Header Field Not Valid for Resource
 "457" ; Invalid Range
 "458" ; Parameter Is Read-Only
 "459" ; Aggregate operation not allowed
 "460" ; Only aggregate operation allowed
 "461" ; Unsupported transport
 "462" ; Destination unreachable
 "500" ; Internal Server Error
 "501" ; Not Implemented
 "502" ; Bad Gateway
 "503" ; Service Unavailable
 "504" ; Gateway Time-out
 "505" ; RTSP Version not supported
 "551" ; Option not supported
```

下面的头字段可以在所有的 RTSP 应答消息中包含。

| 头字段           | 描述                           | 
| ---              | ---                            |
| CSeq             | 应答序列号 (和请求序列匹配).   | 
| Session          | 会话 ID.                       | 
| WWW-Authenticate | 客户端的认证信息.              | 
| Date             | 应答的日期和时间.              | 
| Unsupported      | 服务端不支持的特性和功能.      | 

### 3.3 DESCRIBE

DESCRIBE 命令用于请求指定的媒体流的 SDP 描述信息。关于 SDP ( Session Description Protocol,会话描述协议) 请参考 RFC 2327.

DESCRIBE 请求消息接受如下附加的头字段：

| 头字段         | 描述            | 
| ---            | ---             |
| Accept         | 列出客户支持的内容类型 (application/sdp is the only supported type). | 

DESCRIBE 命令的应答消息包含如下附加的头字段：

| 头字段         | 描述                         | 
| ---            | ---                          |
| Content-Type   | 内容类型 (application/sdp).  | 
| Content-Length | SDP 描述串的长度.            | 
| Content-Base   | 如果 SDP 描述串中使用了相对 URL, 这里是相关的基本 URL. | 

request:  请求

```
DESCRIBE rtsp://myserver/live.mp4 RTSP/1.0
CSeq: 0
User-Agent: Vision MC
Accept: application/sdp
Authorization: Basic cm9vdDpwYXNz
```

response:  应答

```
RTSP/1.0 200 OK
CSeq: 0
Content-Type: application/sdp
Content-Base: rtsp://myserver/live.mp4
Date: Wed, 16 Jul 2008 12:48:47 GMT
Content-Length: 847
v=0
o=- 1216212527554872 1216212527554872 IN IP4 myserver
s=Media Presentation
e=NONE
c=IN IP4 0.0.0.0
b=AS:50064
t=0 0
a=control:rtsp://myserver/live.mp4
&resolution=640x480
a=range:npt=0.000000-
m=video 0 RTP/AVP 96
b=AS:50000
a=framerate:30.0
a=control:rtsp://myserver/live.mp4?trackID=1
a=rtpmap:96 H264/90000
a=fmtp:96 packetization-mode=1; profile-level-id=420029; sprop-parameter-sets=Z0IAKeKQFAe2AtwEBAaQeJEV,aM48gA==
m=audio 0 RTP/AVP 97
b=AS:64
a=control:rtsp://myserver/live.mp4?trackID=2
a=rtpmap:97 mpeg4-generic/16000/1
a=fmtp:97 profile-level-id=15; mode=AAC-hbr;config=1408; SizeLength=13; IndexLength=3;IndexDeltaLength=3; Profile=1; bitrate=64000;
```

### 3.4 OPTIONS

OPTIONS 请求用于返回服务端支持的 RTSP 命令列表 。也可以定时发送这个请求来保活相关的 RTSP 会话。

OPTIONS 命令的应答消息包含如下附加的头字段：

| 头字段          | 描述                  | 
| ---             | ---                   |
| Public          | 指出支持的 RTSP 命令. | 

例如：列出支持的 RTSP 命令.

request:  请求

```
OPTIONS * RTSP/1.0
CSeq: 1
User-Agent: Vision MC
Session: 12345678
Authorization: Basic cm9vdDpwYXNz
```

response:  应答

```
RTSP/1.0 200 OK
CSeq: 1
Session: 12345678
Public: DESCRIBE, GET_PARAMETER, PAUSE, PLAY, SETUP, SET_PARAMETER, TEARDOWN
Date: Wed, 16 Jul 2008 12:48:48 GMT
```

### 3.5 SETUP

SETUP 命令用于配置数据交付的方法。

SETUP 请求和应答需要一个同样的附加的头字段:

| 头字段    | 描述     | 
| ---       | ---      |
| Transport | 指出如何传输数据流。分别支持 RTP/AVP;unicast;client_port=port1-port2 RTP/AVP;multicast;client_port=port1-port2 RTP/AVP/TCP;unicast 等不同的传输方式 | 

这个请求的应答返回一个必须在流控制命令 (如 PLAY，PAUSE，TEARMDOWN) 中使用的会话 ID。

如果这个 Session 头字段包含了 timemout 参数, 除非有保活，否则会话会在超时时间后被关闭。会话可以通过发送包含 Session ID 的 RTSP 请求 (如 OPTIONS，GET_PARAMETER) 给服务端来保活。
或者使用 RTCP 消息。不支持中间重新更改传输参数。

例如: 在第一个 SETUP 请求的应答中返回会话的 ID。并且后续的请求中都包含这个会话 ID。

request:  请求

```
SETUP rtsp://myserver/live.mp4?trackID=1 RTSP/1.0
CSeq: 2
User-Agent: Vision MC
Transport: RTP/AVP;unicast;client_port=20000-20001
Authorization: Basic cm9vdDpwYXNz
```

response:  应答

```
RTSP/1.0 200 OK
CSeq: 2
Session: 12345678; timeout=60
Transport: RTP/AVP;unicast;client_port=20000-20001;server_port=50000-50001;ssrc=B0BA7855;mode="PLAY"
Date: Wed, 16 Jul 2008 12:48:47 GMT
```

request:  请求

```
SETUP rtsp://myserver/live.mp4
trackID=2 RTSP/1.0
CSeq: 3
User-Agent: Vision MC
Transport: RTP/AVP;unicast;client_port=20002-20003
Session: 12345678
Authorization: Basic cm9vdDpwYXNz
```

response:  应答

```
RTSP/1.0 200 OK
CSeq: 3
Session: 12345678; timeout=60
Transport: RTP/AVP;unicast;client_port=20002-20003;server_port=50002-50003;ssrc=D7EB59C0;mode="PLAY"
Date: Wed, 16 Jul 2008 12:48:48 GMT
```

Transport 头字段定义:

```
    Transport           =    "Transport" ":"
                          1\#transport-spec
    transport-spec      =    transport-protocol/profile[/lower-transport]
                          parameter
    transport-protocol  =    "RTP"
    profile             =    "AVP"
    lower-transport     =    "TCP" | "UDP"
    parameter           =    ( "unicast" | "multicast" )
                      |    ";" "destination" [ "=" address ]
                      |    ";" "interleaved" "=" channel [ "-" channel ]
                      |    ";" "append"
                      |    ";" "ttl" "=" ttl
                      |    ";" "layers" "=" 1*DIGIT
                      |    ";" "port" "=" port [ "-" port ]
                      |    ";" "client_port" "=" port [ "-" port ]
                      |    ";" "server_port" "=" port [ "-" port ]
                      |    ";" "ssrc" "=" ssrc
                      |    ";" "mode" = <"> 1\#mode <">
    ttl                 =    1*3(DIGIT)
    port                =    1*5(DIGIT)
    ssrc                =    8*8(HEX)
    channel             =    1*3(DIGIT)
    address             =    host
    mode                =    <">Method <"> | Method
    Example:
    Transport: RTP/AVP;multicast;ttl=127;mode="PLAY",
            RTP/AVP;unicast;client_port=3456-3457;mode="PLAY"
```


### 3.6 PLAY

这个 PLAY 用于启动 (当暂停时重启) 交付数据给客户端.

PLAY 命令的应答消息包含如下附加的头字段:

| 头字段   | 描述          | 
| ---      | ---           |
| Range    | 播放时间段.   | 
| RTP-Info | 关于 RTP 流的信息。包含相关的流的第一个包的序列号。 | 

request:  请求

```
PLAY rtsp://myserver/live.mp4 RTSP/1.0
CSeq: 4
User-Agent: Vision MC
Session: 12345678
Authorization: Basic cm9vdDpwYXNz
```

response:  应答

```
RTSP/1.0 200 OK
CSeq: 4
Session: 12345678
Range: npt=0.645272-
RTP-Info: url=rtsp://myserver/live.mp4?trackID=1;seq=46932;rtptime=1027887748, url=rtsp://myserver/live.mp4?trackID=2;seq=3322;rtptime=611053482
Date: Wed, 16 Jul 2008 12:48:48 GMT
```

例如： Play back the recording "myrecording".

request:  请求

```
PLAY rtsp://myserver/live.mp4?recordingid="myrecording" RTSP/1.0
CSeq: 4
User-Agent: Vision MC
Session: 12345678
Authorization: Basic cm9vdDpwYXNz
```

### 3.7 PAUSE

PAUSE 请求用于临时停止服务端的数据的交付。使用 PLAY 来重新启动数据交付。

request:  请求

```
PAUSE rtsp://myserver/live.mp4 RTSP/1.0
CSeq: 5
User-Agent: Vision MC
Session: 12345678
Authorization: Basic cm9vdDpwYXNz
```

response:  应答

```
RTSP/1.0 200 OK
CSeq: 5
Session: 12345678
Date: Wed, 16 Jul 2008 12:48:49 GMT
```


### 3.8 TEARDOWN

TEARDOWN 请求用于终止来自服务端的数据的传输。

request:  请求

```
TEARDOWN rtsp://myserver/live.mp4 RTSP/1.0
CSeq: 6
User-Agent: Vision MC
Session: 12345678
Authorization: Basic cm9vdDpwYXNz
```

response:  应答

```
RTSP/1.0 200 OK
CSeq: 6
Session: 12345678
Date: Wed, 16 Jul 2008 12:49:01 GMT
```

### 3.9 SET_PARAMETER

SET_PARAMETER 命令用于请求尽快生成一个 I 帧。例如当开始录像的时候。

**必须包含 X-Request-Key-Frame: 1 的头字段。**

request:  请求

```
SET_PARAMETER rtsp://myserver/live.mp4 RTSP/1.0
CSeq: 7
Session: 12345678
Authorization: Basic cm9vdDpwYXNz
X-Request-Key-Frame: 1
Content-Type: text/parameters
Content-Length: 19

Renew-Stream: yes
```

response:  应答

```
RTSP/1.0 200 OK
CSeq: 8
Session: 12345678
Date: Wed, 16 Jul 2008 13:01:25 GMT
```

### 3.10 GET_PARAMETER

标准协议中 GET_PARAMETER 可以用于查询参数状态, 目前设备主要通过 GET 命令来查询设备参数, 所以 GET_PARAMETER 用处不大, 目前主要用来用做会话保活请求.

request:  请求

```
GET_PARAMETER rtsp://myserver/live.mp4 RTSP/1.0
CSeq: 7
Session: 12345678
Authorization: Basic cm9vdDpwYXNz
```

response:  应答

```
RTSP/1.0 200 OK
CSeq: 8
Session: 12345678
Date: Wed, 16 Jul 2008 13:01:25 GMT
```

## 4 RTSP/RTP 交错传输方式.

实现 RTSP 的系统必须支持通过 TCP 传输 RTSP 数据包，并支持 UDP。对 UDP 和 TCP，RTSP 服务器的缺省端口都是 554。许多目的一致的 RTSP 包被打包成单个低层 UDP 或 TCP 流。RTSP 数据可与 RTP 和 RTCP 包交错传输, 即可以通过 TCP 传输 RTP 包。不像 HTTP，RTSP 消息必须总是包含一个内容长度头 (Content-Length)，无论消息是否包含消息内容。如果没有指定消息内容的长度则默认消息的内容的长度为 0。

当 RTP 通过 TCP 和 RTSP 消息交错传输时, 必须在 RTP 包前加 4 个字节长度的头, 它的结构如下: 

- BYTE  必须是 "$" or 0x24
- BYTE  Channel id ，在 SETUP 消息中 Transport 头字段中 interleaved 参数指定.
- WORD  数据包的长度（从接下来的数据开始算起, 不包括这 4 个字节的头的长度）

例如:

```

 C->S: SETUP rtsp://foo.com/bar.file RTSP/1.0
       CSeq: 2
       Transport: RTP/AVP/TCP;interleaved=0-1

 S->C: RTSP/1.0 200 OK
       CSeq: 2
       Date: 05 Jun 1997 18:57:18 GMT
       Transport: RTP/AVP/TCP;interleaved=0-1
       Session: 12345678

 C->S: PLAY rtsp://foo.com/bar.file RTSP/1.0
       CSeq: 3
       Session: 12345678

 S->C: RTSP/1.0 200 OK
       CSeq: 3
       Session: 12345678
       Date: 05 Jun 1997 18:59:15 GMT
       RTP-Info: url=rtsp://foo.com/bar.file;seq=232433;rtptime=972948234

 S->C: $\000{2 byte length}{"length" bytes data, w/RTP header}
 S->C: $\000{2 byte length}{"length" bytes data, w/RTP header}
 S->C: $\001{2 byte length}{"length" bytes  RTCP packet}

```


