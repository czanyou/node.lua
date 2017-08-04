# RPC 远程过程调用

[TOC]

一个简单易用的进程间 RPC 通信模块.

通过 `require('ext/rpc')` 调用。

## rpc.bind

    rpc.bind(url, ...)

实现更便利的远程过程调用方式

- url {String} 远程主机地址和端口, 目前只支持 HTTP/JSONRPC 2.0 协议的 RPC 服务器
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

    rpc.call(url, method, params, callback)
    rpc.call(port, method, params, callback)

调用指定的远程主机上的方法, 并返回执行结果

- url {String} 远程主机地址和端口, 目前只支持 HTTP/JSONRPC 2.0 协议的 RPC 服务器
- port {Number} 本地主机的端口, 目前只支持 HTTP/JSONRPC 2.0 协议的 RPC 服务器
- method {String} 要调用的方法名
- params {Array} 执行指定的方法所需的参数, 只支持 String, Number, Boolean, nil 以及包含上述类型值的 Table 等基本数据类型
- callback {Function} 当远程方法执行成功并返回后调用

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

err {Object} 包含以下属性:

- code {Number} 错误码
- message {String} 错误信息

| code      | message           | meaning
| ---       | ---               | ---
| -32700    | Parse error       | Invalid JSON was received by the server.
| -32600    | Invalid Request   | The JSON sent is not a valid Request object.
| -32601    | Method not found  | The method does not exist / is not available.
| -32602    | Invalid params    | Invalid method parameter(s).
| -32603    | Internal error    | Internal JSON-RPC error.
| -32000 to -32099  | Server error  | Reserved for implementation-defined server-errors.


## rpc.publish

    rpc.publish(topic, data, qos, callback)

向 mqtt.app 发布消息

- topic {String} MQTT 主题
- data {String} MQTT 消息内容
- qos {Number} QoS 值, 默认为 0, 目前只支持 QoS=1
- callback {Function} - function(err, result) 回调函数

说明:

mqtt.app 相当于 MQTT 协议网关, 它将和 MQTT 云服务器创建一个单一的 MQTT/TCP/IP 连接.

其他应用程序可以向 mqtt.app 发布消息, 再由 mqtt.app 转发给云服务器, 这样避免每个应用都创建一个到云服务器的 MQTT 连接.

示例:

```lua
local rpc = require('vision/ext/rpc')
local topic = "/device/test"
local payload = '{state:"on"}'
local qos = 0
rpc.publish(topic, payload, qos, function(err, result)
    if (err) then
        print('err:', err)
    else
        print('result:', result)
    end
end)

```

## rpc.server

    rpc.server(port, handler, callback)

创建一个 RPC 服务器, 注意 RPC 只支持单个返回值, 多个返回值将被丢弃.

目前只支持 HTTP/JSONRPC 2.0 协议

- port {Number} 侦听端口
- handler {Object} 要封装的对象, 这个对象的所有方法将可以被远程调用
- callback {Function} 回调方法

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

## rpc.subscribe

    rpc.subscribe(options, callback)

这个方法专用于其他 APP 和 mqtt.app 通信用, 用于订阅一个指定的 MQTT 主题并接收这个主题的推送消息.

- options {Object} 订阅选项, 支持以下参数
  + notify {Function} - function(self, topic, payload) 用来接收和处理收到的推送消息
  + port {Number} 本应用接收回调的 IPC 服务器端口
  + topic {String} 要订阅的 MQTT 主题

说明:

注意这个方法会创建一个 IPC 服务器来接收 mqtt.app 的回调消息

示例:

```lua

local rpc = require('vision/ext/rpc')
local options = {
    port = 10001,
    topic = '/device/test',
    notify = function(self, topic, payload)
        print('notify', topic, payload)
    end
}

rpc.subscribe(options, function()

end)

```

## rpc.unsubscribe

    rpc.subscribe(options, callback)

取消订阅指定的 MQTT 主题, 取消订阅后将不再收到指定主题推送的消息



