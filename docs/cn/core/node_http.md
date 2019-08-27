# 超文本传输协议 (HTTP)

要使用 HTTP 服务器或客户端功能，需引用此模块 `require('http')`.

The HTTP interfaces in Node are designed to support many features of the protocol which have been traditionally difficult to use. In particular, large, possibly chunk-encoded, messages. The interface is careful to never buffer entire requests or responses--the user is able to stream data. 

Node 中 HTTP 接口被设计用来支持 HTTP 协议中原来使用很困难的特性，特别是一些很大或者块编码的消息。在处理的时候，这些接口会非常谨慎，它从来不会把请求 (request) 和响应 (response) 完全的缓存下来，

HTTP 的消息头 (Headers) 通过如下对象来表示:

```lua
{ 'content-length': '123',
  'content-type': 'text/plain',
  'connection': 'keep-alive',
  'host': 'mysite.com',
  'accept': '*/*' }
```

其中键为小写字母，值是不能修改的。

为了能全面地支持可能的 HTTP 应用程序，Node 提供的 HTTP API 都很底层。它处理的只有流处理和消息解析。它把一份消息解析成报文头和报文体，但是它不解析实际的报文头和报文体。

定义好的消息头允许多个值以, 分割, 除了set-cookie 和 cookie, 因为他们表示值的数组. 像 content-length 这样只能有单个值的消息头直接解析, 并且只有单值可以表示成已解析好的对像.

接收到的原始头信息以数组形式 [key, value, key2, value2, ...] 保存在 rawHeaders 属性中. 例如, 前面提到的消息对象会有 rawHeaders 列表如下:

```lua
[ 'ConTent-Length', '123456',
  'content-LENGTH', '123',
  'content-type', 'text/plain',
  'CONNECTION', 'keep-alive',
  'Host', 'mysite.com',
  'accepT', '*/*' ]
```

## 属性: http.globalAgent

超全局的代理实例，是http客户端的默认请求。

## 属性: http.STATUS_CODES

    {Object}

全部标准 HTTP 响应状态码的集合和简短描述。例如 `http.STATUS_CODES[404] === 'Not Found'`。

## http:createClient

    http.createClient([port], [host])

该函数已弃用,请用http.request()代替. 创建一个新的HTTP客户端. port 和host 表示所连接的服务器.

## http:createServer

    http.createServer([requestListener])

返回一个新的web服务器对象

参数 requestListener 是一个函数,它将会自动加入到 'request' 事件的监听队列.

## http:get

    http:get(options, callback)

因为大部分的请求是没有报文体的GET请求，所以Node提供了这种便捷的方法。该方法与http.request()的唯一区别是它设置的是GET方法并自动调用req.end()。

实例：

```lua
http:get("http://www.google.com/index.html", function(res) 
  print("响应：" + res.statusCode)
end).on('error', function(e) 
  print("错误：" + e.message)
end);
```

## http:request

    http:request(options, callback)

Node 维护几个连接每个服务器的HTTP请求。 这个函数允许后台发布请求。

options可以是一个对象或一个字符串。如果options是一个字符串, 它将自动使用url.parse()解析。

Options:

- host：请求发送到的服务器的域名或IP地址。默认为'localhost'。
- hostname：用于支持url.parse()。hostname比host更好一些
- port：远程服务器的端口。默认值为80。
- localAddress：用于绑定网络连接的本地接口。
- socketPath：Unix域套接字 (使用host:port或socketPath) 
- method：指定HTTP请求方法的字符串。默认为'GET'。
- path：请求路径。默认为'/'。如果有查询字符串，则需要包含。例如'/index.html?page=12'。请求路径包含非法字符时抛出异常。目前，只否决空格，不过在未来可能改变。
- headers：包含请求头的对象。
- auth：用于计算认证头的基本认证，即'user:password'
- agent：控制Agent的行为。当使用了一个Agent的时候，请求将默认为Connection: - keep-alive。可能的值为：
undefined (默认) ：在这个主机和端口上使用[全局Agent][]。
Agent对象：在Agent中显式使用passed。
false：在对Agent进行资源池的时候，选择停用连接，默认请求为：Connection: close。
- keepAlive：{Boolean} 保持资源池周围的套接字在未来被用于其它请求。默认值为false
- keepAliveMsecs：{Integer} 当使用HTTP KeepAlive的时候，通过正在保持活动的套接字发送TCP KeepAlive包的频繁程度。默认值为1000。仅当keepAlive被设置为true时才相关。

http.request() 返回一个 http.ClientRequest 类的实例。ClientRequest 实例是一个可写流对象。如果需要用 POST 请求上传一个文件的话，就将其写入到 ClientRequest 对象。

实例：

```lua
-- write data to request body
req:write('data\n')
req:write('data\n')
req:finish()
```

注意，例子里的req.end()被调用了。使用http.request()方法时都必须总是调用req.end()以表明这个请求已经完成，即使响应body里没有任何数据。

如果在请求期间发生错误 (DNS解析、TCP级别的错误或实际HTTP解析错误

) ，在返回的请求对象会触发一个'error'事件。

有一些特殊的标题应该注意。

- 发送 'Connection: keep-alive'将会告知Node保持连接直到下一个请求发送。
- 发送 'Content-length' 头将会禁用默认的 chunked 编码.
- 发送 'Expect'报头会立即发送请求报头. 通常当发送 'Expect: 100-continue'时，你会同时发送一个超时和监听继续的事件。 查看 RFC2616 第 8.2.3 章节获得更多信息。
- 发送一个授权报头将会覆盖使用 auth 选项来完成基本授权。

## Class: http.Server

这是一个包含下列事件的EventEmitter:

### 事件: 'checkContinue'

    function (request, response)

每当收到 `Expect: 100-continue` 的 http 请求时触发。 如果未监听该事件，服务器会酌情自动发送 100 Continue 响应。

处理该事件时，如果客户端可以继续发送请求主体则调用 `response.writeContinue`， 如果不能则生成合适的HTTP响应 (例如，400 请求无效) 。

需要注意到, 当这个事件触发并且被处理后, request 事件将不再会触发.

### 事件: 'clientError'

    function (exception, socket)

如果一个客户端连接触发了一个 'error' 事件, 它就会转发到这里.

socket 是导致错误的 net.Socket 对象。

### 事件: 'close'

当此服务器关闭时触发

### 事件: 'connect'

    function (request, socket, head)

每当客户端发起CONNECT请求时出发。如果未监听该事件，客户端发起CONNECT请求时连接会被关闭。

- request 是该HTTP请求的参数，与request事件中的相同。
- socket 是服务端与客户端之间的网络套接字。
- head 是一个Buffer实例，隧道流的第一个包，该参数可能为空。

在这个事件被分发后，请求的套接字将不会有data事件监听器，也就是说你将需要绑定一个监听器到data事件，来处理在套接字上被发送到服务器的数据。

### 事件: 'connection'

    function (socket)

新的TCP流建立时出发。 socket是一个net.Socket对象。 通常用户无需处理该事件。 特别注意，协议解析器绑定套接字时采用的方式使套接字不会出发readable事件。 还可以通过request.connection访问socket。

### 事件: 'request'

    function (request, response)

每次收到一个请求时触发.注意每个连接又可能有多个请求(在keep-alive的连接中).request是http.IncomingMessage的一个实例.response是http.ServerResponse的一个实例

### 事件: 'upgrade'

    function (request, socket, head)

每当一个客户端请求http升级时，该事件被分发。如果这个事件没有被监听，那么这些请求升级的客户端的连接将会被关闭。

- request 是该HTTP请求的参数，与request事件中的相同。
- socket 是服务端与客户端之间的网络套接字。
- head 是一个Buffer实例，升级后流的第一个包，该参数可能为空。

在这个事件被分发后，请求的套接字将不会有data事件监听器，也就是说你将需要绑定一个监听器到data事件，来处理在套接字上被发送到服务器的数据。

### server.maxHeadersCount

最大请求头数目限制, 默认 1000 个. 如果设置为 0, 则代表不做任何限制.

### server.timeout

{Number} 默认 120000 (2 分钟)

一个套接字被判断为超时之前的闲置毫秒数。

注意套接字的超时逻辑在连接时被设定，所以更改这个值只会影响新创建的连接，而不会影响到现有连接。

设置为 0 将阻止之后建立的连接的一切自动超时行为。

### server:close

    server:close([callback])

禁止服务端接收新的连接. 查看 `net.Server.close()`.

### server:listen

    server:listen(port, [hostname], [backlog], [callback])

开始在指定的主机名和端口接收连接。如果省略主机名，服务器会接收指向任意IPv4地址的链接 (INADDR_ANY) 。

监听一个 unix socket, 需要提供一个文件名而不是端口号和主机名。

积压量 backlog 为连接等待队列的最大长度。实际长度由您的操作系统通过 sysctl 设置决定，比如 Linux 上的 tcp_max_syn_backlog 和 somaxconn。该参数缺省值为 511 (不是 512) 。

这个函数是异步的。最后一个参数callback会被作为事件监听器添加到 'listening' 事件。另见 `net.Server.listen(port)`。

### server:listen

    server:listen(path, [callback])

启动一个 UNIX 套接字服务器在所给路径 path 上监听连接。

该函数是异步的.最后一个参数 callbac k将会加入到 [listening][]事件的监听队列中.又见 `net.Server:listen(path)`.

### server:listen

    server:listen(handle, [callback])

- handle 处理器
- callback {Function} 回调函数 function

handle 变量可以被设置为 server 或者 socket (任一以下划线开头的成员 _handle), 或者一个 {fd: <n>} 对象

这将使服务器用指定的句柄接受连接，但它假设文件描述符或者句柄已经被绑定在特定的端口或者域名套接字。

Windows 不支持监听一个文件描述符。

这个函数是异步的。最后一个参数callback会被作为事件监听器添加到'listening'事件。另见net.Server.listen()。

### server:setTimeout

    server:setTimeout(msecs, callback)

- msecs {Number}
- callback {Function}

为套接字设定超时值。如果一个超时发生，那么 Server 对象上会分发一个'timeout'事件，同时将套接字作为参数传递。

如果在Server对象上有一个'timeout'事件监听器，那么它将被调用，而超时的套接字会作为参数传递给这个监听器。

默认情况下，服务器的超时时间是 2 分钟，超时后套接字会自动销毁。 但是如果为‘timeout’事件指定了回调函数，你需要负责处理套接字超时。

## Class: http.ServerResponse

这是一个由 HTTP 服务器内部创建的对象 (不是由用户自行创建) 。它将作为第二个参数传递到 'request' 事件中。

该响应实现了 Writable Stream 接口。这是一个包含下列事件的 EventEmitter ：

### 事件: 'close'

需要注意的是，底层链接在 response.end() 被调用或可以冲洗掉之前就被终结了。

### 属性: response.headersSent

布尔型值(只读).如果 headers 发送完毕,则为 true, 反之为 false

### 属性: response.sendDate

若为 true, 则当 headers 里没有 Date 值时自动生成 Date 并发送. 默认值为true

只有在测试环境才禁用它; 因为 HTTP 要求响应包含 Date 头.

### 属性: response.statusCode

当使用默认 headers时 (没有显式地调用 response.writeHead() 来修改 headers) ，这个属性决定 headers 更新时被传回客户端的 HTTP 状态码。

实例：

    response.statusCode = 404;

当响应头被发送回客户端，那么这个属性则表示已经被发送出去的状态码。

### response:addTrailers

    response:addTrailers(headers)

这个方法添加 HTTP 尾随 headers (一个在消息末尾的 header) 给响应。

只有 当数据块编码被用于响应时尾随才会被触发。如果不是 (例如，请求是HTTP/1.0 ) ，他们将会被自动丢弃。

需要注意的是如果要触发尾随消息HTTP要求一个报文头场列表和 Trailer 报头一起发送，例如：

```lua
response:writeHead(200, { 'Content-Type': 'text/plain',
                          'Trailer': 'Content-MD5' })
response:write(fileData)
response:addTrailers({'Content-MD5': "7895bf4b8828b55ceaf47747b4bca667"})
response:finish()
```

当所有的响应报头和报文被发送完成时这个方法将信号发送给服务器；服务器会认为这个消息完成了。 每次响应完成之后必须调用该方法。

如果指定了参数 data , 就相当于先调用 `response:write(data)` 之后再调用 response:end().

### response:done

    response:done([data])


### response:getHeader

    response:getHeader(name)

读取一个在队列中但是还没有被发送至客户端的header。需要注意的是 name 参数是不区分 大小写的。它只能在header还没被冲洗掉之前调用。

实例：

    local contentType = response:getHeader('content-type');

### response:removeHeader

    response:removeHeader(name)

取消掉一个在队列内等待发送的header。

实例：

    response:removeHeader("Content-Encoding");

### response:setHeader

    response:setHeader(name, value)

为默认或者已存在的头设置一条单独的头内容。如果这个头已经存在于 将被送出的头中，将会覆盖原来的内容。如果我想设置更多的头， 就使用一个相同名字的字符串数组

实例：

    response:setHeader("Content-Type", "text/html");

或者

    response:setHeader("Set-Cookie", {"type=ninja", "language=javascript"});

### response:setTimeout

    response:setTimeout(msecs, callback)

- msecs {Number}
- callback {Function}

设定套接字的超时时间为 msecs。如果提供了回调函数，会将其添加为响应对象的 'timeout' 事件的监听器。

如果请求、响应、服务器均未添加'timeout'事件监听，套接字将在超时时被销毁。 如果监听了请求、响应、服务器之一的'timeout'事件，需要自行处理超时的套接字。

### response:write

    response:write(chunk)

如果这个方法被调用但是 response:writeHead() 没有被调用，它将切换到默认 header 模式并更新默认的 headers。

它将发送一个响应体的数据块。这个方法可能被调用很多次以防止继承部分响应体。

chunk可以是字符串或者缓存。如果chunk 是一个字符串， 第二个参数表明如何将这个字符串编码为一个比特流。默认的 encoding是'utf8'。

注意: 这是底层的 HTTP 报文，高级的多部分报文编码无法使用。

当第一次 response.write() 被调用时，将会发送缓存的header信息和第一个报文给客户端。 第二次response.write()被调用时，Node假设你将发送数据流，然后分别地发送。这意味着响应 是缓存到第一次报文的数据块中。

如果所有数据被成功刷新到内核缓冲区，则返回true。如果所有或部分数据在用户内存里还处于队列中，则返回false。当缓冲区再次被释放时，'drain'事件会被分发。

### response:writeContinue

    response:writeContinue()

发送一个 `HTTP/1.1 100 Continue`消息至客户端，表明请求体可以被发送。可以再服务器上查看 'checkContinue' 事件。

### response:writeHead

    response:writeHead(statusCode, [reasonPhrase], [headers])

向请求回复响应头. statusCode 是一个三位是的 HTTP 状态码, 例如 404. 最后一个参数, headers, 是响应头的内容. 可以选择性的，把人类可读的‘原因短句’作为第二个参数。

实例：

```lua
local body = 'hello world'
response:writeHead(200, {
  'Content-Length': body.length,
  'Content-Type': 'text/plain' })
```

这个方法只能在当前请求中使用一次，并且必须在 response.end() 之前调用。

如果你在调用这之前调用了 response.write() 或者 response.end() , 就会调用这个函数，并且 不明/容易混淆 的头将会被使用。

## Class: http.Agent

HTTP Agent 是用于把套接字做成资源池，用于 HTTP 客户端请求。

HTTP Agent 也把客户端的请求默认为使用Connection:keep-alive。如果没有HTTP请求正在等待成为空闲的套接字的话，那么套接字将关闭。这意味着Node的资源池在负载的情况下对keep-alive有利，但是仍然不需要开发人员使用KeepAlive来手动关闭HTTP客户端。

如果你选择使用HTTP KeepAlive，那么你可以创建一个标志设为true的Agent对象。 (见下面的构造函数选项。) 然后，Agent将会在资源池中保持未被使用的套接字，用于未来使用。它们将会被显式标记，以便于不保持Node进程的运行。但是当KeepAlive agent没有被使用时，显式地destroy() KeepAlive agent仍然是个好主意，这样套接字们会被关闭。

当套接字触发了close事件或者特殊的agentRemove事件的时候，套接字们从agent的资源池中移除。这意味着如果你打算保持一个HTTP请求长时间开启，并且不希望它保持在资源池中，那么你可以按照下列几行的代码做事：

```lua
http:get(options, function(res)
  -- 做点事
end).on("socket", function (socket)
  socket:emit("agentRemove")
end);
```

另外，你可以直接使用agent:false选择完全停用资源池。

```lua
http:get({
  hostname: 'localhost',
  port: 80,
  path: '/',
  agent: false  -- 仅仅为了这一个请求，而创建一个新的agent
}, function (res) 
  -- 为响应做些事
end)
```

### Agent:new([options])

- options {Object} 设置于agent上的配置选项的集合。可以有下列字段：
    - keepAlive {Boolean} 保持在资源池周围套接未来字被其它请求使用。默认值为false
    - keepAliveMsecs {Integer} 当使用HTTP KeepAlive时, 通过正在被保持活跃的套接字来发送TCP KeepAlive包的频繁程度。默认值为1000。仅当keepAlive设置为true时有效。
    - maxSockets {Number} 每台主机允许的套接字的数目的最大值。默认值为Infinity。
在空闲状态下还依然开启的套接字的最大值。仅当keepAlive设置为true的时候有效。默认值为256。

被 http.request 使用的默认的 http.globalAgent 有设置为它们各自的默认值的全部这些值。

要配置这些值，你必须创建一个你自己的Agent对象。

```lua
local http = require('http')
local keepAliveAgent = http.Agent:new({ keepAlive: true })
keepAliveAgent:request(options, onResponseCallback)
```

### agent.freeSockets

一个当使用HTTP KeepAlive时保存当前等待用于代理的数组对象。 请不要修改。

### agent.requests

一个保存还没有指定套接字的请求队列对象。 请不要修改。

### agent.maxSockets

默认设置为Infinity。决定每台主机上的agent可以拥有的并发套接字的打开的数量。

### agent.maxFreeSockets

默认设置为256。对于支持HTTP KeepAlive的Agent，这设置了在空闲状态下仍然打开的套接字数目的最大值。

### agent.sockets

一个保存当前被代理使用的套接字的数组对象。 请不要修改。

### agent.destroy

    agent.destroy()

销毁被此agent占用的任何套接字

通常并不需要这样做。然而当我们知道不会再用到一个保持连接的代理是，最好还是把它关掉。否贼 套接字在服务器结束他们之前保持打开相当长的一段时间。

### agent.getName

    agent.getName(options)

通过设置请求选项获得一个独一无二的名称，来决定是否一个连接是否可以再生。 在http代理中，它将返回host:port:localAddress`。在https代理中，这个名称 包含CA, cert, ciphers,和其他HTTPS/TLS特殊选项来决定一个套接字是否可以再生。


## Class: http.ClientRequest

该对象在内部创建，并由 http.request() 返回。它表示着一个正在处理 的请求，其头部已经进入请求队列。该头部仍然可以通过 `setHeader(name, value), getHeader(name), removeHeader(name)` 等 API 进行修改。实际的头部将会随着第一个数据块发送，或在连接关闭时发送。

为了获得响应对象，给请求对象添加一个 'response' 监听器。当接收到响应头时，请求对象将会触发 'response'。'response' 事件执行时有一个参数，该参数为 http.IncomingMessage 的一个实例。

在 'response' 事件期间，可以为响应对象添加监听器，尤其是监听'data'事件。

如果没有添加 'response' 处理函数，响应将被完全忽略。然而，如果你添加了一个 'response' 事件处理函数，那么你必须 消费掉响应对象的数据：可以在 'readable' 事件时调用 response.read()，可以添加一个 'data' 处理函数，也可以调用 .resume() 方法。数据被消费掉后，'end' 事件被触发。如果数据未被读取，它将会消耗内存，最终产生 'process out of memory' 错误。

注意: Node 不会检查 Content-Length 和被传输的 body 长度是否相同.

该请求实现了 Writable Stream 接口。这是一个包含下列事件的 EventEmitter：

### 事件: 'connect'

    function(response, socket, head)

- response {http.IncomingMessage}
- socket {net.Socket}
- head {}

每次服务器使用 CONNECT 方法响应一个请求时被触发。如果该事件未被监听，接收 CONNECT 方法的客户端将关闭它们的连接。

如下是一对客户端/服务端代码,向你演示如何监听connect事件。

```lua
local http = require('http');
local net = require('net');
local url = require('url');

-- Create an HTTP tunneling proxy
local proxy = http.createServer( function(req, res)
  res:writeHead(200, {'Content-Type': 'text/plain'});
  res:done('okay');
end);

proxy:on('connect', function(req, cltSocket, head)
  -- connect to an origin server
  local srvUrl = url.parse("http://" .. req.url);
  local srvSocket = net.connect(srvUrl.port, srvUrl.hostname, function()
    cltSocket:write('HTTP/1.1 200 Connection Established\r\n' +
                    'Proxy-agent: Node-Proxy\r\n' +
                    '\r\n');
    srvSocket:write(head);
    srvSocket:pipe(cltSocket);
    cltSocket:pipe(srvSocket);
  end);
end);

-- now that proxy is running
proxy:listen(1337, '127.0.0.1', function()

  -- make a request to a tunneling proxy
  local options = {
    port: 1337,
    hostname: '127.0.0.1',
    method: 'CONNECT',
    path: 'www.google.com:80'
  };

  local req = http.request(options);
  req:done();

  req:on('connect', function(res, socket, head)
    console.log('got connected!');

    -- make a request over an HTTP tunnel
    socket:write('GET / HTTP/1.1\r\n' +
                 'Host: www.google.com:80\r\n' +
                 'Connection: close\r\n' +
                 '\r\n');
    socket:on('data', function(chunk)
      console.log(chunk);
    end);

    socket:on('end', function()
      proxy:close();
    end);
  end);
end);
```

### 事件: 'continue'

当服务器发送 100 Continue 响应时触发，通常是因为请求包含 Expect: 100-continue。该指令表示客户端应发送请求体。

### 事件: 'response'

    function (response)

当接收到请求的响应时触发，该事件只被触发一次。response 参数是 http.IncomingMessage 的一个实例。

Options:

- host: 请求要发送的域名或服务器的IP地址。
- port: 远程服务器的端口。
- socketPath: Unix Domain Socket  (使用 host:port 和 socketPath 其中之一) 

### 事件: 'socket'

    function (socket)

触发于一个套接字被赋予为这个请求的时候。

### 事件: 'upgrade'

    function (response, socket, head)

每次服务器返回 upgrade 响应时触发。如果该事件未被监听，客户端收到 upgrade 后将关闭连接。

如下是一对客户端/服务端代码, 向你演示如何监听 upgrade 事件。

```lua
  req:on('upgrade', function(res, socket, upgradeHead)
    print('got upgraded!')
    socket:finish()
    process:exit(0)
  end)

```

### request:abort

    request.abort()

终止一个请求.

### request:done

    request.done([data])

结束发送请求。如果请求体的某些部分还发送，该函数将会把它们 flush 到流中。如果该请求是分块的，该方法将会发送终结符 `0\r\n\r\n`。

如果指定了data,那么等价于 先调用 `request:write(data)`, 再调用 `request:end()`.

### request:setNoDelay

    request:setNoDelay([noDelay])

一旦一个套接字被分配给该请求并且完成连接，socket.setNoDelay()将会被调用。

### request:setSocketKeepAlive

    request:setSocketKeepAlive([enable], [initialDelay])

一旦一个套接字被分配到这个请求，而且成功连接，那么socket.setKeepAlive()就会被调用。

### request:setTimeout

    request:setTimeout(timeout, [callback])

一旦一个套接字被分配给该请求并且完成连接，socket.setTimeout()将会被调用。

### request:write

    request:write(chunk)

发送一块请求体。调用该方法多次，用户可以流式地发送请求体至服务器——在这种情况下，创建请求时建议使用['Transfer-Encoding', 'chunked']头。

chunk 参数必须是 Buffer 或者 string.

## http.IncomingMessage

一个 IncomingMessage 对象是由 http.Server 或 http.ClientRequest 创建的，并作为第一参数分别传递给 'request' 和 'response' 事件。它也可以被用来访问应答的状态，头文件和数据。

它实现了 Readable Stream 接口以及以下额外的事件，方法和属性。

### 事件: 'close'

    function() end

表示在 response:done() 被调用或强制刷新之前，底层的连接已经被终止了。

跟 'end' 一样，这个事件对于每个应答只会触发一次。详见 http.ServerResponse 的 'close' 事件。

### 属性: message.headers

请求/响应头对象.

只读的消息头名称和值的映射。消息头名称全小写。示例：

```lua

console.log(request.headers)
-- 输出类似这样：
--
-- { 'user-agent': 'curl/7.22.0',
--   host: '127.0.0.1:8000',
--   accept: '*/*' }

```

### 属性: message.httpVersion

客户端向服务器发出请求时，客户端发送的 HTTP 本；或是服务器向客户端返回应答时，服务器的 HTTP 版本。通常是 '1.1' 或 '1.0'。

另外，response.httpVersionMajor 是第一个整数，response.httpVersionMinor 是第二个整数。

### 属性: message.method

仅对从 http.Server 获得到的请求 (request) 有效.

请求 (request) 方法如同一个只读的字符串，比如 ‘GET’、‘DELETE’。

### 属性: message.rawHeaders

接收到的原始请求/响应头字段列表。

注意键和值在同一个列表中，它并非一个元组列表。于是，偶数偏移量为键，奇数偏移量为对应的值。

头名称没有转换为小写，也没有合并重复的头。

```lua
console.log(request.rawHeaders);
-- Prints something like:
--
-- [ 'user-agent',
--   'this is invalid because there can be only one',
--   'User-Agent',
--   'curl/7.22.0',
--   'Host',
--   '127.0.0.1:8000',
--   'ACCEPT',
--   '*/*' ]

```

### 属性: message.rawTrailers

接收到的原始的请求/响应尾部键和值，只在 'end' 事件时存在。

### 属性: message.socket

与此连接 (connection) 关联的 net.Socket 对象.

### 属性: message.trailers

请求/响应的尾部对象，只在 'end' 事件时是存在的。

### 属性: message.url

仅对从 http.Server 获得到的请求 (request) 有效.

请求的 URL 字符串.它仅包含实际 HTTP 请求中所提供的URL.加入请求如下:

```lua
GET /status?name=ryan HTTP/1.1\r\n
Accept: text/plain\r\n
\r\n
```

则 request.url 为:

```lua
'/status?name=ryan'
```

如果你想要将URL分解出来, 你可以用 `require('url').parse(request.url)`. 例如:

```lua
require('url').parse('/status?name=ryan')
--
--{ href: '/status?name=ryan',
--  search: '?name=ryan',
--  query: 'name=ryan',
--  pathname: '/status' }
```

如果你想要提取出从请求字符串 `(query string)` 中的参数, 你可以用 `require('querystring').parse` 函数, 或者将 true 作为第二个参数传递给 `require('url').parse`. 例如:

```lua
require('url').parse('/status?name=ryan', true)
--{ href: '/status?name=ryan',
--  search: '?name=ryan',
--  query: { name: 'ryan' },
--  pathname: '/status' }

```

### message.statusCode

仅对从 `http.ClientRequest` 获得的响应 (response) 有效.

三位数的 HTTP 响应状态码. 例如 404.

### message:setTimeout

    message:setTimeout(msecs, callback)

- msecs {Number}
- callback {Function}

调用 `message.connection:setTimeout(msecs, callback)`

返回 `message`

