# 网络 (network)

`net` 模块用于创建基于流的 TCP 或 IPC 的服务器[`net.createServer()`](http://nodejs.cn/s/e8cikS)与客户端[`net.createConnection()`](http://nodejs.cn/s/RTNxdX)。
可以用 `require('net')` 来引入这个模块. 

## IPC 支持

`net` 模块在 Windows 上支持命名管道 IPC，在其他操作系统上支持 Unix 域套接字。

### IPC 连接的识别路径

[`net.connect()`](http://nodejs.cn/s/mw8BBV), [`net.createConnection()`](http://nodejs.cn/s/RTNxdX), [`server.listen()`](http://nodejs.cn/s/xGksiu) 和 [`socket.connect()`](http://nodejs.cn/s/fGCDDg) 使用一个 `path` 参数来识别 IPC 端点。

在 Unix 上，本地域也称为 Unix 域。 参数 `path` 是文件系统路径名。

在 Windows 上，本地域通过命名管道实现。路径必须是以 `\\?\pipe\` 或 `\\.\pipe\` 为入口。

## 类: net.Server

此类用于创建 TCP 或 IPC 服务器。

### 事件

`net.Server` 是一个 `EventEmitter`，实现了以下事件:

#### 事件: 'close'

当服务被关闭时触发. 

注意：如果当前仍有活动连接, 这个事件将等到所有连接都结束后才触发. 

#### 事件: 'connection'

- connection `{net.Socket}` 连接对象

在一个新连接被创建时触发. `connection` 是一个 `net.Socket` 的实例. 

#### 事件: 'error'

当一个错误发生时触发. [`'close'`](http://nodejs.cn/s/3c6jjk) 事件不会在这个事件触发后继续触发.  参见 server.listen 中的例子. 

#### 事件: 'listening'

在服务器调用 `server.listen` 绑定服务器后触发. 

### 属性

#### server.listening

- `boolean` 表明 server 是否正在监听连接。

### server:address

    server:address()

返回操作系统报告的绑定的地址, 协议族和端口. 对查找操作系统分配的地址哪个端口已被分配非常有用， 
如. { port: 12346, family: 'IPv4', address: '127.0.0.1' }

在 'listening' 事件发生前请勿调用 server.address(). 

### server:close

    server:close([callback])

- callback `{function}` 当 server 被关闭时调用。
- 返回: `net.Server`

阻止 server 接受新的连接并保持现有的连接。 该函数是异步的，server 将在所有连接结束后关闭并触发 `'close'` 事件。 可选的 `callback` 将在 `'close'` 事件发生时被调用。 与 `'close'` 事件不同的是，如果 server 在关闭时未打开，回调函数被调用时会传入一个 `Error` 对象作为唯一参数。

### server:getConnections

    server:getConnections(callback)

- callback `{function}`
- 返回: `net.Server`

异步获取服务器当前活跃的连接数. 用于套接字发送给子进程. 

回调函数需要两个参数 err 和 count.

### server:listen

    server:listen(port, [host], [backlog], [callback])
    server:listen(path, [backlog], [callback])

- port `{number}` 端口
- host `{string}` 主机地址
- backlog `{number}`待连接队列的最大长度
- callback `{function}`
- path `{string}` IPC 路径

在指定端口 port 和主机 host 上开始接受连接. 如果省略 host 则服务器会接受来自所有 IPv4 地址 
(INADDR_ANY) 的连接；端口为 0 则会使用分随机分配的端口. 

如果 path 被传入，则创建一个 Unix Socket 服务器。

在 Windows 下命名方式为： `"\\\\?\\pipe\\uv-test"`
在其他系统下命名方式为： `"/tmp/uv-test.sock"`

积压量 backlog 为连接等待队列的最大长度. 实际长度由您的操作系统通过 sysctl 设置决定, 
比如 Linux 上的 tcp\_max\_syn_backlog 和 somaxconn. 该参数缺省值为 511 (不是 512) . 

这是一个异步函数. 当服务器已被绑定时会触发 'listening' 事件. 最后一个参数 callback 会被用作 
'listening' 事件的监听器. 

有些用户会遇到的情况是遇到 'EADDINUSE' 错误. 这表示另一个服务器已经运行在所请求的端口上.
一个处理这种情况的方法是等待一段时间再重试

```lua
server:on('error', function(message, code) 
  if (code == 'EADDRINUSE') then
    print('地址被占用, 重试中...')
    setTimeout(function() 
      server:close()
      server:listen(PORT, HOST)
    end, 1000)
  end
end)
```

 (注意：Node 中的所有套接字已设置了 SO_REUSEADDR) 

## 类: net.Socket

这个对象是一个 TCP 或 UNIX 套接字的抽象. net.Socket 实例实现了一个双工流接口. 
他们可以被用户使用在客户端 (使用 connect()) 或者它们可以由 Node 创建, 
并通过 'connection' 服务器事件传递给用户. 

### 事件

`net.Socket` 实例是带有以下事件的 `EventEmitter` 对象：

#### 事件: 'close'

- had_error `{boolean}` 如果套接字发生了传输错误则此字段为 true

当套接字完全关闭时该事件被触发. 参数 had_error 是一个布尔值, 
表示了套接字是否因为一个传输错误而被关闭. 

#### 事件: 'connect'

当一个 socket 连接成功建立的时候触发该事件. 见 connect(). 

#### 事件: 'data'

- data `{Buffer}`

当接收到数据的时触发该事件. data 参数会是一个 Buffer 或 String 对象. 

请注意, 如果一个 Socket 对象触发 'data' 事件时没有任何监听器存在, 则数据会丢失. 

#### 事件: 'drain'

当写入缓冲被清空时触发. 可被用于控制上传流量. 

请参阅：`socket:write()` 的返回值

#### 事件: 'end'

当 socket 的另一端发送一个 FIN 包的时候触发，从而结束 socket 的可读端。

默认情况下（`allowHalfOpen` 为 `false`），socket 将发送一个 FIN 数据包，并且一旦写出它的等待写入队列就销毁它的文件描述符。 当然，如果 `allowHalfOpen` 为 `true`，socket 就不会自动结束 end() 它的写入端，允许用户写入任意数量的数据。 用户必须调用 end() 显式地结束这个连接（例如发送一个 FIN 数据包）。

#### 事件: 'error'

- error `{Error}`

当一个错误发生时产生. 'close' 事件会紧接着该事件被触发. 

#### 事件: 'lookup'

这个事件在解析主机名之后, 连接主机之前被触发.. 对 UNIX 套接字不适用. 

- err `{Error}` 错误对象. 见 [dns.lookup()][]. 
- address `{string}` IP 地址. 
- family `{string}` 得知类型. 见 [dns.lookup()][]. 

#### 事件: 'timeout'

当套接字因为非活动状态而超时时该事件被分发. 这只是用来表明套接字处于空闲状态.
用户必须手动关闭这个连接. 

参阅：`socket:setTimeout()`

### 属性

#### 属性: socket.bufferSize

是一个 net.Socket 的属性, 用于 socket.write(). 用于帮助用户获取更快的运行速度. 
计算机不能一直处于大量数据被写入状态 —— 网络链接可能会变得过慢. 
Node 在内部会排队等候数据被写入套接字并确保传输连接上的数据完好.  
(内部实现为：轮询套接字的文件描述符等待它为可写).

内部缓冲的可能后果是内存使用会增加. 这个属性表示了现在处于缓冲区等待被写入的字符数. 
(字符的数目约等于要被写入的字节数, 但是缓冲区可能包含字符串, 而字符串是惰性编码的, 
所以确切的字节数是未知的. ) 

遇到数值很大或者增长很快的 bufferSize 的时候, 用户应该尝试用 pause() 和 resume() 来控制数据流. 

#### 属性: socket.bytesRead

所接收的字节数. 

#### 属性: socket.bytesWritten

所发送的字节数. 

#### 属性: socket.connecting

如果为 `true` 则 [`socket.connect(options[, connectListener\])`]() 被调用但还未结束。 它将保持为真，直到 socket 连接，然后设置为 `false` 并触发 `'connect'` 事件。 注意，[`socket.connect(options[, connectListener\])`]() 的回调是 `'connect'` 事件的监听器。

#### 属性: socket.destroyed

- `boolean` 指示连接是否已经被销毁。一旦连接被销毁就不能再使用它传输任何数据。

有关更多详细信息，参见 [`writable.destroyed`](http://nodejs.cn/s/VyLsm8)。

#### 属性: socket.localAddress

远程客户端正在连接的本地IP地址的字符串表示. 例如, 如果你在监听 '0.0.0.0' 
而客户端连接在 '192.168.1.1'，这个值就会是 '192.168.1.1'. 

#### 属性: socket.localPort

本地端口的数值表示. 比如 80 或 21. 

#### 属性: socket.remoteAddress

远程 IP 地址的字符串表示. 例如，'74.125.127.100' 或 '2001:4860:a005::68'. 

#### 属性: socket.remotePort

远程端口的数值表示. 例如, 80 或 21. 

### Socket:new

    Socket:new([options])

构造一个新的套接字对象. 

options 是一个包含下列缺省值的对象：

```lua
{ 
  fd: nil
  type: nil
}
```

fd 允许你指定一个存在的文件描述符和套接字. type 指定一个优先的协议. 他可以是 'tcp4', 'tcp6', 
或 'unix'. 关于 allowHalfOpen, 参见 createServer() 和 'end' 事件. 

### socket:address

    socket:address()

返回 socket 绑定的IP地址, 协议类型 (family name) 以及 端口号 (port). 
具体是一个包含三个属性的对象, 形如 `{ port: 12346, family: 'IPv4', address: '127.0.0.1' }`

### socket:connect

    socket:connect(port, [host], [connectListener])
    socket:connect(path, [connectListener])

使用传入的套接字打开一个连接, 如果 port 和 host 都被传入，那么套接字将会被以 TCP 套接字打开, 
如果 host 被省略, 默认为 localhost. 如果 path 被传入, 套接字将会被已指定路径 UNIX 套接字打开. 

一般情况下这个函数是不需要使用, 比如用 net.createConnection 打开套接字. 
只有在您实现了自定义套接字时候才需要. 

这是一个异步函数. 当 'connect' 触发了的套接字是 established 状态.
或者在连接的时候出现了一个问题, 'connect' 事件不会被触发， 而 'error' 事件会触发并发送异常信息. 

connectListener 用于 'connect' 事件的监听器

### socket:destroy

    socket:destroy(error)

- error `{Error}`
- 返回: `net.Socket`

确保没有 I/O 活动在这个套接字. 只有在错误发生情况下才需要 (处理错误等等) . 

有关更多详细信息，参见 writable.destroy()

### socket:close

    socket.close([data],[callback])

- data `{string}` 
- callback `{function}`
- 返回:  socket 本身。

半关闭套接字, 它发送一个 FIN 包. 可能服务器仍在发送数据. 

如果 data 被传入, 等同于调用 `socket:write(data)` 然后调用 `socket:close()`.

### socket:pause

    socket:pause()

暂停读取数据. 'data' 事件不会被触发. 对于控制上传非常有用. 

### socket:resume

    socket:resume()

在调用 pause() 后恢复读操作. 

### socket:setKeepAlive

    socket:setKeepAlive([enable], [initialDelay])

- enable `{boolean}`
- initialDelay `{number}`

禁用/启用长连接功能, 并在第一个在闲置套接字上的长连接 probe 被发送之前, 
可选地设定初始延时. enable 默认为 false. 

设定 initialDelay (毫秒)，来设定在收到的最后一个数据包和第一个长连接 probe 之间的延时. 
将 initialDelay 设成 0 会让值保持不变(默认值或之前所设的值). 默认为 0. 

### socket:setNoDelay

    socket:setNoDelay([noDelay])

- noDelay `{boolean}`

禁用纳格 (Nagle) 算法. 默认情况下 TCP 连接使用纳格算法, 这些连接在发送数据之前对数据进行缓冲处理. 将 noDelay 设成 true 会在每次 `socket.write()` 被调用时立刻发送数据. noDelay 默认为 true. 

### socket:setTimeout

    socket:setTimeout(timeout, [callback])

- timeout `{number}`
- callback `{function}`

如果套接字超过 timeout 毫秒处于闲置状态, 则将套接字设为超时. 默认情况下 net.Socket 不存在超时. 

当一个闲置超时被触发时, 套接字会接收到一个'timeout'事件, 但是连接将不会被断开.
用户必须手动 finish() 或 destroy() 这个套接字. 

如果 timeout 为 0, 那么现有的闲置超时会被禁用. 

可选的 callback 参数将会被添加成为 'timeout' 事件的一次性监听器. 

### socket:write

    socket:write(data, [callback])

- data `{string}`
- callback `{function}`

在套接字上发送数据. 

如果所有数据被成功刷新到内核缓冲区, 则返回 true. 如果所有或部分数据在用户内存里还处于队列中, 
则返回 false. 当缓冲区再次被释放时，'drain' 事件会被分发. 

当数据最终被完整写入时, 可选的 callback 参数会被执行 - 但不一定是马上执行. 

## net.createServer

    net.createServer([options], [connectionListener])

创建一个新的 TCP 服务器. 参数 connectionListener 会被自动作为 'connection' 事件的监听器. 

- options `{object}` 是一个包含下列值的对象：
  + handle `{tcp_stream_t}`
- connectionListener `{function}` `function(connection) end`

下面是一个监听 8124 端口连接的应答服务器的例子：

```lua
local net = require('net');
local server = net.createServer(function(connection) -- 'connection' 监听器
  print('服务器已连接')
  connection:on('end', function() 
    print('服务器已断开')
  end)
  connection:write('hello\r\n')
  connection:pipe(connection)
end);

server:listen(8124, function() -- 'listening' 监听器
  print('服务器已绑定')
end)
```

## net.connect

    net.connect(options, [connectionListener])
    net.connect(port, [host], [connectListener])

## net.createConnection

net.connect 方法的别名.

创建一个新的套接字对象并连接到所给的位置. 当套接字就绪时会触发 'connect' 事件. 

对于 TCP 套接字, 选项 `options` 参数应为一个指定下列参数的对象：

- `port`：客户端连接到的端口 (必须) 
- `host`：客户端连接到的主机, 缺省为 'localhost'
- `connectListener`: 用于 'connect' 事件的监听器

下面是一个上述应答服务器的客户端的例子：

```lua
local net = require('net')
local client = net.connect({port = 8124}, function() --'connect' 监听器
  print('client connected')
  client:write('world!\r\n')
end)

client:on('data', function(data) 
  print(data.toString())
  client:end()
end)

client:on('end', function() 
  print('客户端断开连接')
end)
```

## 