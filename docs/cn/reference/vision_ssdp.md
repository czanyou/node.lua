# 简单服务发现协议

> 成真 整理, 这一章内容主要来自互联网

简单服务发现协议 (SSDP，Simple Service Discovery Protocol) 是一种应用层协议，是构成通用即插即用 (UPnP) 技术的核心协议之一。

## 简介

简单服务发现协议提供了在局部网络里面发现设备的机制。控制点 (也就是接受服务的客户端) 可以通过使用简单服务发现协议，根据自己的需要查询在自己所在的局部网络里面提供特定服务的设备。设备 (也就是提供服务的服务器端) 也可以通过使用简单服务发现协议，向自己所在的局部网络里面的控制点声明它的存在。

## 实现

简单服务发现协议是在 HTTPU 和 HTTPMU 的基础上实现的协议。

```seq
# 示意图
控制点->设备:   M-SEARCH "ssdp:discover"
设备-->控制点:  200 OK
```

按照协议的规定，当一个控制点 (客户端) 接入网络的时候，它可以向一个特定的多播地址的 SSDP 端口使用 M-SEARCH 方法发送 "ssdp:discover" 消息。当设备监听到这个保留的多播地址上由控制点发送的消息的时候，设备会分析控制点请求的服务，如果自身提供了控制点请求的服务，设备将通过单播的方式直接响应控制点的请求。

```seq
# 示意图
设备->控制点:  NOTIFY "ssdp:alive"
设备-->设备:   经过一段时间
设备-->控制点: NOTIFY "ssdp:alive"
```

类似的，当一个设备接入网络的时候，它应当向一个特定的多播地址的 SSDP 端口使用 NOTIFY 方法发送 "ssdp:alive" 消息。控制点根据自己的策略，处理监听到的消息。考虑到设备可能在没有通知的情况下停止服务或者从网络上卸载，"ssdp:alive" 消息必须在 HTTP 协议头 CACHE-CONTROL 里面指定超时值，设备必须在约定的超时值到达以前重发 "ssdp:alive" 消息。如果控制点在指定的超时值内没有再次收到设备发送的"ssdp:alive"消息，控制点将认为设备已经失效。

```seq
# 示意图
设备->控制点:  NOTIFY "ssdp:alive"
设备->控制点:  NOTIFY "ssdp:alive"
设备->控制点:  NOTIFY "ssdp:alive"
设备-->设备:   计划关闭服务
设备-->控制点:  NOTIFY "ssdp:byebye"
```

当一个设备计划从网络上卸载的时候，它也应当向一个特定的多播地址的 SSDP 端口使用 NOTIFY 方法发送 "ssdp:byebye" 消息。但是，即使没有发送 "ssdp:byebye" 消息，控制点也会根据 "ssdp:alive" 消息指定的超时值，将超时并且没有再次收到的 "ssdp:alive" 消息对应的设备认为是失效的设备。

在 IPv4 环境，当需要使用多播方式传送相关消息的时候，SSDP 一般使用多播地址 239.255.255.250 和 UDP 端口号 1900。

根据互联网地址指派机构的指派，SSDP 在 IPv6 环境下使用多播地址 FF0x::C，这里的 X 根据 scope 的不同可以有不同的取值。

## HTTP 协议基础

HTTP (Hyper Text Transfer Protocol) 是超文本传输协议的缩写，它用于传送 WWW 方式的数据，关于 HTTP 协议的详细内容请参考 RFC 2616。HTTP 协议采用了请求/响应模型。客户端向服务器发送一个请求，请求头包含请求的方法、URI、协议版本、以及包含请求修饰符、客户信息和内容的类似于 MIME 的消息结构。服务器以一个状态行作为响应，相应的内容包括消息协议的版本，成功或者错误编码加上包含服务器信息、实体元信息以及可能的实体内容。

通常 HTTP 消息包括客户机向服务器的请求消息和服务器向客户机的响应消息。这两种类型的消息由一个起始行，一个或者多个头域，一个只是头域结束的空行和可选的消息体组成。HTTP 的头域包括通用头，请求头，响应头和实体头四个部分。每个头域由一个域名，冒号 (:) 和域值三部分组成。域名是大小写无关的，域值前可以添加任何数量的空格符，头域可以被扩展为多行，在每行开始处，使用至少一个空格或制表符。

### 通用头域

通用头域包含请求和响应消息都支持的头域，通用头域包含 Cache-Control、Connection、Date、Pragma、Transfer-Encoding、Upgrade、Via。对通用头域的扩展要求通讯双方都支持此扩展，如果存在不支持的通用头域，一般将会作为实体头域处理。下面简单介绍几个在UPnP消息中使用的通用头域。

#### Cache-Control 头域

Cache-Control 指定请求和响应遵循的缓存机制。在请求消息或响应消息中设置 Cache-Control 并不会修改另一个消息处理过程中的缓存处理过程。请求时的缓存指令包括 no-cache、no-store、max-age、max-stale、min-fresh、only-if-cached，响应消息中的指令包括public、private、no-cache、no-store、no-transform、must-revalidate、proxy-revalidate、max-age。各个消息中的指令含义如下:

| 名称    | 描述                                                         |
| ------- | ------------------------------------------------------------ |
| Public  | 指示响应可被任何缓存区缓存。                                 |
| Private | 指示对于单个用户的整个或部分响应消息，不能被共享缓存处理。这允许服务 器仅仅描述当用户的部分响应消息，此响应消息对于其他用户的请求无效。 |
| no-cache    | 指示请求或响应消息不能缓存 |
| no-store    | 用于防止重要的信息被无意的发布。在请求消息中发送将使得请求和响应消息 都不使用缓存。|
| max-age     | 指示客户机可以接收生存期不大于指定时间 (以秒为单位) 的响应。|
| min-fresh   | 指示客户机可以接收响应时间小于当前时间加上指定时间的响应。|
| max-stale   | 指示客户机可以接收超出超时期间的响应消息。如果指定 max-stale 消息的值， 那么客户机可以接收超出超时期指定值之内的响应消息。|

#### Date 头域

Date 头域表示消息发送的时间，时间的描述格式由 rfc822 定义。例如，Date: Mon, 31 Dec 2001 04:25:57 GMT。Date 描述的时间表示世界标准时，换算成本地时间，需要知道用户所在的时区。

#### Pragma 头域

Pragma 头域用来包含实现特定的指令，最常用的是 Pragma: no-cache。在 HTTP/1.1 协议中，它的含义和 Cache-Control: no-cache 相同。

### 请求消息

请求消息的第一行为下面的格式:

```
Method SP Request-URI SP HTTP-Version CRLF
```

Method 表示对于 Request-URI 完成的方法，这个字段是大小写敏感的，包括 OPTIONS、GET、HEAD、POST、PUT、DELETE、TRACE。方法 GET 和 HEAD 应该被所有的通用 WEB 服务器支持，其他所有方法的实现是可选的。GET 方法取回由 Request-URI 标识的信息。HEAD 方法也是取回由 Request-URI 标识的信息，只是可以在响应时，不返回消息体。POST 方法可以请求服务器接收包含在请求中的实体信息，可以用于提交表单，向新闻组、BBS、邮件群组和数据库发送消息。

SP 表示空格。Request-URI 遵循URI格式，在此字段为星号 (*) 时，说明请求并不用于某个特定的资源地址，而是用于服务器本身。HTTP-Version 表示支持的 HTTP 版本，例如为HTTP/1.1。CRLF 表示换行回车符。请求头域允许客户端向服务器传递关于请求或者关于客户机的附加信息。请求头域可能包含下列字段 Accept、Accept-Charset、Accept-Encoding、Accept-Language、Authorization、From、Host、If-Modified-Since、If-Match、If-None-Match、If-Range、If-Range、If-Unmodified-Since、Max-Forwards、Proxy-Authorization、Range、Referer、User-Agent。对请求头域的扩展要求通讯双方都支持，如果存在不支持的请求头域，一般将会作为实体头域处理。

典型的请求消息:

```
GET http://download.microtool.de:80/somedata.exe
Host: download.microtool.de
Accept: */*
Pragma: no-cache
Cache-Control: no-cache
Referer: http://download.microtool.de/
User-Agent: Mozilla/4.04 [en] (Win95; I ;Nav)
Range: bytes=554554-
```

上例第一行表示 HTTP 客户端 (可能是浏览器、下载程序) 通过 GET 方法获得指定 URL 下的文件。棕色的部分表示请求头域的信息，绿色的部分表示通用头部分。

#### Host 头域

Host 头域指定请求资源的 Intenet 主机和端口号，必须表示请求 url 的原始服务器或网关的位置。HTTP/1.1 请求必须包含主机头域，否则系统会以 400 状态码返回。

#### Referer 头域

Referer 头域允许客户端指定请求 uri 的源资源地址，这可以允许服务器生成回退链表，可用来登陆、优化 cache 等。他也允许废除的或错误的连接由于维护的目的被追踪。如果请求的 uri 没有自己的 uri地址，Referer 不能被发送。如果指定的是部分 uri 地址，则此地址应该是一个相对地址。

#### Range 头域

Range 头域可以请求实体的一个或者多个子范围。例如，

```
表示头500个字节:          bytes = 0 - 499
表示第二个500字节:        bytes = 500 - 999
表示最后500个字节:        bytes = -500
表示500字节以后的范围:    bytes = 500-
第一个和最后一个字节:     bytes = 0-0 , -1
同时指定几个范围:         bytes = 500-600, 601-999
```

但是服务器可以忽略此请求头，如果无条件 GET 包含 Range 请求头，响应会以状态码 206 (Partial Content) 返回而不是以 200 (OK) 。

#### User-Agent 头域

User-Agent 头域的内容包含发出请求的用户信息。

### 响应消息

响应消息的第一行为下面的格式:

```
HTTP-Version SP Status-Code SP Reason-Phrase CRLF
```

HTTP-Version 表示支持的 HTTP 版本，例如为 HTTP/1.1。Status-Code 是一个三个数字的结果代码。Reason-Phrase 给 Status-Code 提供一个简单的文本描述。Status-Code 主要用于机器自动识别，Reason-Phrase 主要用于帮助用户理解。Status-Code 的第一个数字定义响应的类别，后两个数字没有分类的作用。第一个数字可能取 5 个不同的值:

- 1xx : 信息响应类，表示接收到请求并且继续处理
- 2xx : 处理成功响应类，表示动作被成功接收、理解和接受
- 3xx : 重定向响应类，为了完成指定的动作，必须接受进一步处理
- 4xx : 客户端错误，客户请求包含语法错误或者是不能正确执行
- 5xx : 服务端错误，服务器不能正确执行一个正确的请求

响应头域允许服务器传递不能放在状态行的附加信息，这些域主要描述服务器的信息和 Request-URI 进一步的信息。响应头域包含 Age、Location、Proxy-Authenticate、Public、Retry-After、Server、Vary、Warning、WWW-Authenticate。对响应头域的扩展要求通讯双方都支持，如果存在不支持的响应头域，一般将会作为实体头域处理。

典型的响应消息:

```
HTTP/1.0 200 OK
Date: Mon, 31 Dec 2001 04:25:57 GMT
Server: Apache/1.3.14 (Unix)
Content-type: text/html
Last-modified: Tue, 17 Apr 2001 06:46:28 GMT
Etag: "a030f020ac7c01:1e9f"
Content-length: 39725426
Content-range: bytes 554554-40279979/40279980
```

上例第一行表示 HTTP 服务端响应一个 GET 方法。棕色的部分表示响应头域的信息，绿色的部分表示通用头部分，红色的部分表示实体头域的信息。

#### Location 响应头

Location 响应头用于重定向接收者到一个新URI地址。

#### Server 响应头

Server响应头包含处理请求的原始服务器的软件信息。此域能包含多个产品标识和注释，产品标识一般按照重要性排序。

### 实体

请求消息和响应消息都可以包含实体信息，实体信息一般由实体头域和实体组成。实体头域包含关于实体的原信息，实体头包括 Allow、Content-Base、Content-Encoding、Content-Language、Content-Length、Content-Location、Content-MD5、Content-Range、Content-Type、Etag、Expires、Last-Modified、extension-header。extension-header 允许客户端定义新的实体头，但是这些域可能无法未接受方识别。实体可以是一个经过编码的字节流，它的编码方式由 Content-Encoding 或 Content-Type 定义，它的长度由 Content-Length 或 Content-Range 定义。

#### Content-Type 实体头

Content-Type 实体头用于向接收方指示实体的介质类型，指定 HEAD 方法送到接收方的实体介质类型，或 GET 方法发送的请求介质类型。

#### Content-Range 实体头

Content-Range 实体头用于指定整个实体中的一部分的插入位置，他也指示了整个实体的长度。在服务器向客户返回一个部分响应，它必须描述响应覆盖的范围和整个实体长度。一般格式:

```
Content-Range: bytes-unit SP first-byte-pos -last-byte-pos/entity-legth
```

例如，传送头 500 个字节次字段的形式: Content-Range: bytes 0-499/1234 如果一个 http 消息包含此节 (例如，对范围请求的响应或对一系列范围的重叠请求) ，Content-Range 表示传送的范围，Content-Length 表示实际传送的字节数。

#### Last-modified 实体头

Last-modified 实体头指定服务器上保存内容的最后修订时间。

## SSDP 协议消息

### 设备通知消息

在设备加入网络，UPnP 发现协议允许设备向控制点广告它的服务。它使用向一个标准地址和端口多址传送发现消息来实现。控制点在此端口上侦听是否有新服务加入系统。为了通知所有设备，一个设备为每个其上的嵌入设备和服务发送一系列相应的发现消息。每个消息也包含它表征设备或服务的特定信息。

#### ssdp:alive 消息

在设备加入系统时，它采用多播传送方式发送发现消息，包括告知设备包含的根设备信息，所有嵌入设备以及它包含的服务。每个发现消息包含四个主要对象:

- 在 NT 头中包含的潜在搜索目标。
- 在 USN 头中包含的复合发现标识
- 在 LOCATION 头中关于设备信息的 URL 地址
- 在 CACHE-CONTROL 头中表示的广告消息的合法存在时间。

对于根设备，存在三种发现消息:

| NT                   | USN
| ---                  | ---
| 根设备的 UUID        | 根设备的 UUID
| 设备类型: 设备版本   | 根设备的 UUID，设备类型: 设备版本
| upnp:rootdevice      | 根设备的 UUID，设备类型和 upnp:rootdevice

对于嵌入设备，存在两种发现消息:

| NT                   | USN
| ---                  | ---
| 嵌入设备的 UUID      | 嵌入设备的 UUID
| 设备类型: 设备版本   | 嵌入设备的 UUID，设备类型和设备版本

对于每个服务:

| NT                   | USN
| ---                  | ---
| 服务类型: 服务版本   | 相关设备的 UUID，服务类型和服务版本

如果一个根设备有 n 个嵌入设备，m 个嵌入服务，而且包含 k 个不同的服务类型，这将会发出 3 + 2n + k 次请求。这些广告消息像控制点描述了设备的所有信息。这些消息必须作为一系列一起发出，发送的顺序无关紧要，但是不能对单个消息进行刷新或取消的操作。 选择一个适当的持续期是在最小化网络通讯和最大化设备状态及时更新之间求得一个平衡，相对较短的持续时间可以保证控制点在牺牲网络流量的前提下获得设备的当前状态；持续期越长可以大大减少设备刷新造成的网络流量。一般而言，设备制造商应该选择一个适当的持续时间值。

由于 UDP 协议是不可信的，设备应该发送多次设备发现消息。而且为了降低控制点无法收到设备或服务广告消息的可能性，设备应该定期发送它的广告消息。在设备加入网络时，它必须用 NOTIFY 方法发送一个多播传送请求。NOTIFY 方法发送的请求没有回应消息，典型的设备通知消息格式如下:

```
NOTIFY * HTTP/1.1
HOST: 239.255.255.250:1900
CACHE-CONTROL: max-age = seconds until advertisement expires
LOCATION: URL for UPnP description for root device
NT: search target
NTS: ssdp:alive
USN: advertisement UUID
```

各 HTTP 协议头的含义简介:

| 名称              | 描述
| ---               | ---
| HOST              | 设置为协议保留多播地址和端口，必须是 239.255.255.250:1900。
| CACHE-CONTROL     | max-age 指定通知消息存活时间，如果超过此时间间隔，控制点可以认为设备不存在
| LOCATION          | 包含根设备描述得 URL 地址
| NT                | 在此消息中，NT 头必须为服务的服务类型。
| NTS               | 表示通知消息的子类型，必须为 ssdp:alive
| USN               | 表示不同服务的统一服务名，它提供了一种标识出相同类型服务的能力。


一个发现响应可以包含 0 个、1 个或者多个服务类型实例。为了做出分辨，每个服务发现响应包括一个 "USN:根设备" 的标识。在同样的设备里，一个服务类型的多个实例必须用包含 USN:ID 的服务标识符标识出来。例如，一个灯和电源共用一个开关设备，对于开关服务的查询可能无法分辨出这是用于灯的。UPNP 论坛工作组通过定义适当的设备层次以及设备和服务的类型标识分辨出服务的应用程序场景。这么做的缺点是需要依赖设备的描述 URL。

#### ssdp:byebye 消息

在设备和它的服务将要从网络中卸载时，设备应该对于每个未超期的 ssdp:alive 消息多播方式传送 ssdp:byebye 消息。但如果设备突然从网络卸载，它可能来不及发出这个通知消息。因此，发现消息必须在 CACHE-CONTROL 包含超时值，如果不重新发出广告消息，发现消息最后超时并从控制点的缓存中除去。典型的设备卸载消息格式如下:

```
NOTIFY * HTTP/1.1
HOST: 239.255.255.250:1900
NT: search target
NTS: ssdp:byebye
USN: advertisement UUID各HTTP协议头的含义简介:
```

- HOST 设置为协议保留多播地址和端口，必须是 239.255.255.250:1900
- NT  在此消息中，NT 头必须为服务的服务类型。
- NTS 表示通知消息的子类型，必须为 ssdp:alive
- USN 表示不同服务的统一服务名，它提供了一种标识出相同类型服务的能力。

### 设备查询消息

当一个控制点加入到网络中时，设备发现过程允许控制点寻找网络上感兴趣的设备。发现消息包括设备的一些特定信息或者某项服务的信息，例如它的类型、标识符、和指向 XML 设备描述文档的指针。从设备获得响应从本质上说，内容与多址传送的设备广播相同，只是采用单址传送方式。设备查询通过 HTTP 协议扩展 M-SEARCH 方法实现的。典型的设备查询请求消息格式:

```
M-SEARCH * HTTP/1.1
HOST: 239.255.255.250:1900
MAN: "ssdp:discover"
MX: seconds to delay response
ST: search target
```

各 HTTP 协议头的含义简介:

| 名称      | 描述
| ---       | ---
| HOST      | 设置为协议保留多播地址和端口，必须是 239.255.255.250:1900。
| MAN       | 设置协议查询的类型，必须是 "ssdp:discover"。
| MX        | 设置设备响应最长等待时间，设备响应在0和这个值之间随机选择响应延迟的值。这样可以为控制点响应平衡网络负载。
| ST        | 设置服务查询的目标


ST 必须是下面的类型:

- ssdp:all 搜索所有设备和服务
- upnp:rootdevice 仅搜索网络中的根设备
- uuid:device-UUID 查询UUID标识的设备
- urn:schemas-upnp-org:device:device-Type:version 查询 device-Type 字段指定的设备类型，设备类型和版本由 UPNP 组织定义。
- urn:schemas-upnp-org:service:service-Type:version 查询 service-Type 字段指定的服务类型，服务类型和版本由 UPNP 组织定义。

在设备接收到查询请求并且查询类型 (ST 字段值) 与此设备匹配时，设备必须向多播地址 239.255.255.250:1900 回应响应消息。典型:

```
HTTP/1.1 200 OK
CACHE-CONTROL: max-age = seconds until advertisement expires
DATE: when reponse was generated
EXT:
LOCATION: URL for UPnP description for root device
SERVER: OS/Version UPNP/1.0 product/version
ST: search target
USN: advertisement UUID
```

各 HTTP 协议头的含义简介:

| 名称          | 描述
| ---           | ---
| CACHE-CONTROL | max-age 指定通知消息存活时间，如果超过此时间间隔，控制点可以认为设备不存在
| DATE          | 指定响应生成的时间
| EXT           | 向控制点确认 MAN 头域已经被设备理解
| LOCATION      | 包含根设备描述得 URL 地址
| SERVER        | 饱含操作系统名，版本，产品名和产品版本信息
| ST            | 内容和意义与查询请求的相应字段相同
| USN           | 表示不同服务的统一服务名，它提供了一种标识出相同类型服务的能力。

在所有的发现通知中，表示 UPnP 根设备描述的 LOCATION 和统一服务名 (USN)必须提供。此外，在响应消息中查询目标头 (ST) 必须与 LOCATION 和统一服务名 (USN)一起提供。

专有设备或服务可以不遵循标准的 UPNP 模版。但如果设备或服务提供 UPNP 发现、描述、控制和事件过程的所有对象，它的行为就像一个标准的 UPNP 设备或服务。为了避免命名冲突，使用专有设备命名时除了 UPNP 域之外必须包含一个前缀"urn:schemas-upnp-org"。在与标准模版相同时，应该使用整数版本号。但如果与标准模版不同，不可以使用设备复用和徽标。

简单设备发现协议不提供高级的查询功能，也就是说，不能完成某个具有某种服务的设备这样的复合查询。在完成设备或者服务发现之后，控制点可以通过设备或服务描述的URL地址完成更为精确的信息查询。

## 设备描述

UPnP 使用一个 XML 文档来描述设备，我们则改为用更简洁的 JSON 格式来描述:

### 根设备描述:

```json
{
    "version": 1,
    "device": {
        "type": "NetworkCamera:1",
        "url": "http://192.168.77.1:80"
        "name": "Wireless Camera 1201",
        "manufacturer": "CMPP",
        "model": "WG-1201",
        "serialNumber": "12345678900001",
        "udn": "uuid:8c15e41f-3d83-41c1-b35d-15EF301EF7FB",
        "serviceList": [
            {
                "type": "NetworkCamera:1",
                "url" "camera.json"
            },
            {
                "type": "Hygrothermograph:1",
                "url" "hygrothermograph.json"
            }
        ],
        "deviceList": [
            {
                "type": "Network:1",
                "name": "Network Interface",
                "serviceList": [
                    {
                        "type": "WiFi:1",
                        "url" "wifi.json"
                    },
                    {
                        "type": "Ethernet:1",
                        "url" "eth.json"
                    }
                ]
            }
        ]
    }
}

```

- version 当前协议版本，现在只有版本 1
- device.type 设备类型
- device.name 设备显示名称
- device.url 设备访问地址
- device.manufacturer 设备的制造商名称
- device.model 设备的硬件型号
- device.serialNumber 设备的硬件序列号
- device.udn 设备的 UUID
- device.serviceList 设备提供的服务列表
- device.deviceList 设备包含的嵌入设备列表

- service.type 服务类型
- service.url 服务的描述文档地址

### 服务描述

下面是一个温湿计服务的描述:

```json
{
    "version": 1
    "type": "Hygrothermograph:1",
    "serviceStateTable": [
        {
            "name":"TemperatureUnit",
            "type":"string"
            "allowed":["Centigrade","Fahrenheit"]
        },
        {
            "name":"Temperature",
            "type":"number",
            "event": true,
            "readonly":true
        },
        {
            "name":"Humidity",
            "type":"number",
            "event": true,
            "readonly":true
        },
    ]
}
```

- version 当前服务版本号，总是为 1
- type 当前服务类型
- serviceStateTable 当前服务状态列表
- state.name 状态名称
- state.type 状态数据类型，可以是 string,number 等.
- state.event 是否可以订阅事件，即在这个状态改变是可以事件通知
- state.readonly 是否只读

## 变量读写

### 读取

    GET http://<host:port>/service/<service>/<state>

例如返回所有状态:

    GET http://192.168.77.1/service/Hygrothermograph/

返回值:

```json
{
    "type":"Hygrothermograph:1",
    "version":1,
    "serviceStateTable":[
        {"value":26.9,"name":"Temperature"},
        {"value":56,"name":"Humidity"},
        {"value":"Centigrade","name":"TemperatureUnit"}
    ]
}
```

### 修改

    POST http://192.168.77.1/service/Hygrothermograph/Temperature

## 事件订阅

### 订阅事件

    SUBSCRIBE http://192.168.77.1/service/Hygrothermograph/ -- 订阅所有事件

### 取消订阅

    UNSUBSCRIBE http://192.168.77.1/service/Hygrothermograph/ -- 取消订阅所有事件

### 发送事件

    NOTIFY *

## 参考资料

RFC 2616:

    关于超文本传输协议 (HTTP 1.1) 原文 IETF 的 RFC 文档 http://www.ietf.org/rfc/rfc2616.txt?number=2616

SSDP 协议:

    简单服务发现协议，协议原文参考 http://www.upnp.org/download/draft_cai_ssdp_v1_03.txt

GENA:

    通用事件通知结构，协议原文参考 http://www.upnp.org/download/draft-cohen-gena-client-01.txt

HTTPU 和 HTTPMU:

    在 UDP 上实现 HTTP 协议传送以及 HTTP 协议多址传送。协议规范参考 http://www.upnp.org/download/draft-goland-http-udp-04.txt

原文地址:

    http://www.ibm.com/developerworks/cn/linux/other/UPnP/part2/index.html



