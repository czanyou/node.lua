## SDP 协议

[TOC]

## SDP 协议简介

会话描述协议（SDP）为会话通知、会话邀请和其它形式的多媒体会话初始化等目的提供了多媒体会话描述。

会话目录用于协助多媒体会议的通告，并为会话参与者传送相关设置信息。SDP 即用于将这种信息传输到接收端。SDP 完全是一种会话描述格式 ― 它不属于传输协议 ― 它只使用不同的适当的传输协议，包括会话通知协议（SAP）、会话初始协议（SIP）、实时流协议（RTSP）、MIME 扩展协议的电子邮件以及超文本传输协议（HTTP）。

SDP 的设计宗旨是通用性，它可以应用于大范围的网络环境和应用程序，而不仅仅局限于组播会话目录，但 SDP 不支持会话内容或媒体编码的协商。

## SDP 文本信息包括：

- 会话名称和意图；
- 会话持续时间；
- 构成会话的媒体；
- 有关接收媒体的信息（地址等）。

## Session description

```
v=  (protocol version)
o=  (owner/creator and session identifier).
s=  (session name)
i=* (session information)
u=* (URI of description)
e=* (email address)
p=* (phone number)
c=* (connection information - not required if included in all media)
b=* (bandwidth information)
```

One or more time descriptions (see below)

```
z=* (time zone adjustments)
k=* (encryption key)
a=* (zero or more session attribute lines)
```

Zero or more media descriptions (see below)

### Time description

```
t=  (time the session is active)
r=* (zero or more repeat times)
```

### Media description

```
m=  (media name and transport address)
i=* (media title)
c=* (connection information - optional if included at session-level)
b=* (bandwidth information)
k=* (encryption key)
a=* (zero or more media attribute lines)
```

## 协议结构

SDP 信息是文本信息，采用 UTF-8 编 码中的 ISO 10646 字符集。SDP 会话描述如下：（标注 * 符号的表示可选字段）：

```
* v = （协议版本）
* o = （所有者/创建者和会话标识符）
* s = （会话名称）
* i = * （会话信息）
* u = * （URI 描述）
* e = * （Email 地址）
* p = * （电话号码）
* c = * （连接信息 ― 如果包含在所有媒体中，则不需要该字段）
* b = * （带宽信息）
```

一个或更多时间描述（如下所示）：

```
* z = * （时间区域调整）
* k = * （加密密钥）
* a = * （0 个或多个会话属性行）
* 0个或多个媒体描述（如下所示）
```

### 时间描述

```
* t = （会话活动时间）
* r = * （0或多次重复次数）
```

### 媒体描述

```
* m = （媒体名称和传输地址）
* i = * （媒体标题）
* c = * （连接信息 — 如果包含在会话层则该字段可选）
* b = * （带宽信息）
* k = * （加密密钥）
* a = * （0 个或多个会话属性行
```
