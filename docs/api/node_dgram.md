# 数据报套接字 (UDP)

[TOC]

数据报套接字通过 require('dgram') 提供。

## dgram.createSocket

    dgram.createSocket(type, [callback])

- type {String} 可以是 'udp4' 或 'udp6'
- callback {function} 可选, 会被作为 message 事件的监听器。
- 返回：Socket 对象

创建一个指定类型的数据报 Socket。有效类型包括 udp4 和 udp6。

接受一个可选的回调, 会被添加为 'message' 事件的监听器。

如果您想接收数据报则可调用 socket.bind。socket.bind() 会绑定到 "所有网络接口" 
地址的一个随机端口（udp4 和 udp6 皆是如此）。然后您可以通过 socket:address().address 
和 socket:address().port 来取得地址和端口。

## 类: dgram.Socket

dgram Socket 类封装了数据报功能, 可以通过 dgram.createSocket(type, [callback]) 创建。

### 事件: 'message'

- msg {Buffer} 对象, 消息
- rinfo {Object}, 远程地址信息

当套接字中有新的数据报时发生。msg 是一个 Buffer, rinfo 是一个包含了发送者地址信息的对象：

```lua
socket:on('message', function(msg, rinfo)
  print('收到 %d 字节, 来自 %s:%d\n',
              msg.length, rinfo.address, rinfo.port)
end)
```

### 事件: 'listening'

当一个套接字开始监听数据报时产生。它会在 UDP 套接字被创建时发生。

### 事件: 'close'

当一个套接字被 close() 关闭时产生。之后这个套接字上不会再有 message 事件发生。

### 事件: 'error'

- exception {Error}

当发生错误时产生。

### socket.addMembership

    socket.addMembership(multicastAddress, [multicastInterface])

- multicastAddress {String}
- multicastInterface {String}, 可选

以 IP\_ADD_MEMBERSHIP 套接字选项告诉内核加入一个组播分组。

如果未指定 multicastInterface, 则操作系统会尝试向所有有效接口添加关系。

### socket.address()

返回一个包含了套接字地址信息的对象。对于 UDP 套接字, 该对象会包含地址 address、
地址族 family 和端口号 port。

### socket.bind

    socket.bind(port, [address], [callback])

- port {Number}
- address {String}, 可选
- callback {function} 没有参数的 function, 可选, 当绑定完成时被调用。

对于 UDP 套接字, 在一个具名端口 port 和可选的地址 address 上监听数据报。如果 address 未指定, 
则操作系统会尝试监听所有地址。当绑定完成后, 一个 "listening" 事件会发生, 
并且回调 callback（如果指定）会被调用。
同时指定 "listening" 事件监听器和 callback 并不会产生副作用, 但也没什么用。

一个绑定了的数据报套接字会保持 node 进程运行来接收数据报。

如果绑定失败, 则一个 "error" 事件会被产生。在极少情况下（比如绑定一个已关闭的套接字）, 
该方法会抛出一个 Error。

一个监听端口 41234 的 UDP 服务器的例子：

```lua
server:bind(41234);
-- 服务器正在监听 0.0.0.0:41234
```

### socket.close

    socket.close()

关闭底层套接字并停止监听数据。

### socket.dropMembership

    socket.dropMembership(multicastAddress, [multicastInterface])

- multicastAddress {String}
- multicastInterface {String}, 可选

与 addMembership 相反, 以 IP\_DROP_MEMBERSHIP 套接字选项告诉内核退出一个组播分组。
当套接字被关闭或进程结束时内核会自动调用, 因此大多数应用都没必要调用它。

如果未指定 multicastInterface, 则操作系统会尝试向所有有效接口移除关系。

### socket.send

    socket.send(buffer, port, address, [callback])

- buffer {String} 对象, 要发送的消息
- offset {Number}, Buffer 中消息起始偏移值。
- length {Number}, 消息的字节数。
- port {Number}, 目标端口
- address {String}, 目标 IP
- callback {function}, 可选, 当消息被投递后的回调。

对于 UDP 套接字, 必须指定目标端口和 IP 地址。address 参数可以是一个字符串, 它会被 DNS 解析。
可选地可以指定一个回调以用于发现任何 DNS 错误或当 buf 可被重用。请注意 DNS 
查询会将发送的时间推迟到至少下一个事件循环。确认发送完毕的唯一已知方法是使用回调。

如果套接字之前并未被调用 bind 绑定, 则它会被分配一个随机端口并绑定到“所有网络接口”地址
（udp4 套接字是 0.0.0.0；udp6 套接字是 ::0）。

向 localhost 随机端口发送 UDP 报文的例子：

```lua
local dgram = require('dgram')
local message = "Some bytes"
local client = dgram.createSocket("udp4")
client:send(message, 41234, "localhost", function(err) 
  client:close()
end)
```

关于 UDP 数据报大小的注意事项

一个 IPv4/v6 数据报的最大大小取决与 MTU（最大传输单位）和 Payload Length 字段大小。

Payload Length 字段宽 16 bits, 意味着正常负载包括网络头和数据不能大于 64K
（65,507 字节 = 65,535 − 8 字节 UDP 头 − 20 字节 IP 头）；这对环回接口通常是真的, 
但如此大的数据报对大多数主机和网络来说是不切实际的。

MTU 是一个给定的数据链路层技术能为数据报提供支持的最大大小。对于任何连接, 
IPv4 允许最小 68 字节的 MTU, 而 IPv4 所推荐的 MTU 为 576（通常作为拨号类应用的推荐 MTU）, 
无论它们是完整接收还是分片。

对于 IPv6, 最小的 MTU 为 1280 字节, 但所允许的最小碎片重组缓冲大小为 1500 字节。 
68 的值是非常小的, 因为现在大多数数据链路层技术有都具有 1500 的最小 MTU（比如以太网）。

请注意我们不可能提前得知一个报文可能经过的每一个连接 MTU, 因此通常情况下不能发送一个大于
（接收者的）MTU 的数据报（报文会被悄悄地丢掉, 而不会将数据没有到达它意图的接收者的消息告知来源）。

### socket.setBroadcast

    socket.setBroadcast(flag)

- flag {Boolean}

设置或清除 SO_BROADCAST 套接字选项。当该选项被设置, 则 UDP 报文可能被发送到一个本地接口的广播地址。

### socket.setMulticastLoopback

    socket.setMulticastLoopback(flag)

- flag {Boolean}

设置或清除 `IP_MULTICAST_LOOP` 套接字选项。当该选项被设置时, 组播报文也会被本地接口收到。

### socket.setMulticastTTL

    socket.setMulticastTTL(ttl)

- ttl {Number}

设置 `IP_MULTICAST_TTL` 套接字选项。TTL 表示 “Time to Live”（生存时间）, 
但在此上下文中它指的是报文允许通过的 IP 跃点数, 特别是组播流量。
各个转发报文的路由器或网关都会递减 TTL。如果 TTL 被一个路由器递减到 0, 则它将不会被转发。

setMulticastTTL() 的参数为介于 1 至 255 的跃点数。在大多数系统上缺省值为 1。

### socket.setTTL

    socket.setTTL(ttl)

- ttl {Number} 生存时间

设置 IP_TTL 套接字选项。TTL 表示 “Time to Live”（生存时间）, 
但在此上下文中它指的是报文允许通过的 IP 跃点数。各个转发报文的路由器或网关都会递减 TTL。
如果 TTL 被一个路由器递减到 0, 则它将不会被转发。改变 TTL 值通常被用于网络探测器或多播。

setTTL() 的参数为介于 1 至 255 的跃点数。在大多数系统上缺省值为 64。

