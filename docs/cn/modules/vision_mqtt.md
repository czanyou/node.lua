# MQTT

`mqtt` 是一个 MQTT 协议的客户端模块, 由纯 Lua 语言实现.

可通过 `local mqtt = require('mqtt')` 引入这个模块。

## 示例

为了方便演示, 在同一个文件中同时实现了发布和订阅功能

```lua
local mqtt = require('mqtt')

local client = mqtt.connect('mqtt://test.mosquitto.org')

client:on('connect', function()
  client:subscribe('presence')

  client:publish('presence', 'Hello mqtt')
end)

client:on('message', function(topic, message)
  console.log(message)
  client:close()
end)

```

输出:

```sh
Hello mqtt
```

如果想使用自己的 MQTT 服务器, 可以使用 [Mosquitto](http://mosquitto.org) 或
[Mosca](http://mcollina.github.io/mosca/), 也可以使用如下的公共测试服务器: test.mosquitto.org 或 test.mosca.io

## mqtt.connect([url], options)

连接到指定的 URL 服务器并返回一个 Client 实例.

- url {String} MQTT 服务器 URL
- options {Object} 连接选项
  - callback {Function} 当收到订阅的消息时调用
  - clean
  - clientId {String} 客户端 ID
  - connectTimeout {Number} 
  - hostname {String} 服务器主机名称或 IP 地址
  - incomingStore
  - keepalive  {Number} 保活时间
  - outgoingStore
  - password {String} 密码
  - port {Number} 服务器端口
  - protocol {String} 连接协议
  - reconnectPeriod {Number} 重连周期
  - username {String} 用户名

关于所有选项, 请查看 Client 构建方法说明.

## Client:new(options)

客户端对象封装了 MQTT 客户端和服务端之间的客户端连接。

客户端会自动处理如下机制

* 心跳机制
* QoS 流
* 自动重连

参数:

* options 客户端选项，包含：
  * keepalive: 默认为 `10` 秒, 设为 `0` 来禁止 keep-alive 机制
  * clientId: 客户端的 ID
  * reconnectPeriod: 默认为 `1000` 毫秒, 两次重连的间隔时间
  * connectTimeout:  默认为 `30 * 1000` 毫秒, 在收到 CONNACK 之前等待的时间
  * username: 用于验证身份的用户名
  * password: 用于验证身份的密码

### Event `'connect'`

`function(connack)`

当连接(或重连)成功时调用

### Event `'reconnect'`

`function()`

当开始重新连接时调用

### Event `'close'`

`function()`

当断开连接后调用

### Event `'offline'`

`function() {}`

当客户端变为离线时调用

### Event `'error'`

`function(error)`

当客户端无法连接或发生解析错误时调用

### Event `'message'`

`function(topic, message)`

当客户端收到一个发布消息包时调用

* `topic` {String} 收到的消息的主题
* `message` {String} 收到的消息的内容

### client:connect

```c
client:connect()
```

开始连接

### client:publish

```lua
client:publish(topic, message, [options], [callback])
```

发布一个消息到一个主题

* `topic` {String} 要发布的主题
* `message` {String} 要发布的消息内容
* `options` {Ojbect} 发布选项，包含:
  * `qos` {Number} QoS 级别, 默认为 `0`
  * `retain` {Boolean} retain 标记, 默认为 `false`
* `callback` {Function} - `function(err)` 回调函数，在 Qos 事务完成后调用，如果 qos 为 0 则在下一个 tick 时调用。

### client:subscribe

    client:subscribe(topic, [options], [callback])

订阅指定的主题或多个主题

* topic {String|Array|Object} 要订阅的主题或主题列表，可以用 Object 方式指定每个主题的 Qos 比如: `{'test1': 0, 'test2': 1}`.
* options {Object} 订阅选项
  * qos {Number} 订阅 Qos, 默认为 0
* callback {Function} - `function(err, granted)` 在收到 ACK 确认时调用
  * err {String} 订阅错误信息
  * granted {Array} is an array of `{topic, qos}` where:
    * topic {String} is a subscribed to topic
    * qos {Number} is the granted qos level on it

### client:unsubscribe

    client:unsubscribe(topic, [options], [callback])

取消订阅指定的主题或多个主题

* `topic` {String|Array} 要取消订阅听主题或主题列表
* `callback` {Function} - `function(err)` 在收到 ACK 确认时调用

### client:close

    client:close([force], [callback])

关闭这个客户端, 并接受如下的选项:

* `force` {Boolean} 设置为 true 时表示立即关闭客户端而不管是否收到相关 ACK 消息。
* `callback` {Function} 当客户端被关闭时调用
