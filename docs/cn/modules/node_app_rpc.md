# RPC 远程过程调用

一个简单易用的进程间 RPC 通信模块.

通过 `require('app/rpc')` 调用。

## rpc.bind

> rpc.bind(url, ...)

实现更便利的远程过程调用方式

- url `{string}` 远程主机地址和端口, 目前只支持 HTTP/JSONRPC 2.0 协议的 RPC 服务器
- ... 要绑定到本地的远程方法名称列表

例如:

```lua

local url = "http://127.0.0.1:9000/"

-- 绑定远程的 test 方法
local remote = rpc.bind(url, 'test')

-- 可以象调用本地方法一样调用远程的方法
remote.test(10, 12, function(err, result)
    print(err, result)
end)

```


## rpc.call

> rpc.call(url, method, params, callback)
> rpc.call(port, method, params, callback)

调用指定的远程主机上的方法, 并返回执行结果

- url `{string}` 远程主机地址和端口, 目前只支持 HTTP/JSONRPC 2.0 协议的 RPC 服务器
- port `{number}` 本地主机的端口, 目前只支持 HTTP/JSONRPC 2.0 协议的 RPC 服务器
- method `{string}` 要调用的方法名
- params` {array}` 执行指定的方法所需的参数, 只支持 String, Number, Boolean, nil 以及包含上述类型值的 Table 等基本数据类型
- callback `{function}` 当远程方法执行成功并返回后调用

示例:

```lua

local url = "http://127.0.0.1:9000/"

rpc.call(url, 'test', {10, 12}, function(err, result)
    print(err, result)
end)

-- or:

local port = 9000

rpc.call(port, 'test', {10, 12}, function(err, result)
    print(err, result)
end)

```

err `{object}` 包含以下属性:

- code` {number}` 错误码
- message `{string}` 错误信息

| code      | message           | meaning
| ---       | ---               | ---
| -32700    | Parse error       | Invalid JSON was received by the server.
| -32600    | Invalid Request   | The JSON sent is not a valid Request object.
| -32601    | Method not found  | The method does not exist / is not available.
| -32602    | Invalid params    | Invalid method parameter(s).
| -32603    | Internal error    | Internal JSON-RPC error.
| -32000 to -32099  | Server error  | Reserved for implementation-defined server-errors.


## rpc.server

> rpc.server(port, handler, callback)

创建一个 RPC 服务器, 注意 RPC 只支持单个返回值, 多个返回值将被丢弃.

目前只支持 HTTP/JSONRPC 2.0 协议

- port` {number}` 侦听端口
- handler `{object}` 要封装的对象, 这个对象的所有方法将可以被远程调用
- callback `{function}` 回调方法

示例:

```lua

local PORT = 9000

local handler = {
    test = function(self, a, b)
        return a * b
    end
}

local server = rpc.server(PORT, handler, function()
    print("RPC server started!")
end)

```