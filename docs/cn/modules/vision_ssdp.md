# SSDP 简单服务发现协议

这个模块用于发现网络中的设备, SSDP 通过简单的 UDP 广播和组播消息机制和发现局域网的 SSDP 设备。通常设备会在指定 UDP 端口侦听搜索请求广播消息。当收到搜索请求消息时，向发送消息的地址发送一个应答消息。这样就可以主动发现局域网内的 SSDP 设备了。

通过 `require('ssdp')` 调用。

## 类 `SsdpClient`

### SsdpClient:new

> SsdpClient:new(options)

创建一个新的 SSDP 客户端的实例。

- options `{object}` 选项
    + ssdpPort `{number}` 要搜索的端口，默认为 1900

### 事件 'request'

> callback(request, rinfo)

当收到局域网内 SSDP 设备的 NOTIFY 广播消息，产生这个事件。

### 事件 'response'

> callback(response, rinfo)

当收到局域网内 SSDP 设备的搜索应答消息时，产生这个事件。

### client:start

> client:start()

准备开始搜索，将向局域网广播 M-SEARCH 消息，详情请参考 SSDP 协议文档。

### client:stop

> client:stop()

停止搜索，停止发送搜索消息并且不再接收 M-SEARCH 应答消息。

### client:search

> client:search(serviceType)

立即发送 M-SEARCH 广播消息。

- serviceType {string} 要搜索的设备或者服务类型，如："ssdp:all" 表示搜索所有类型的根设备.

比如网关设备类型为:

```
ST:urn:schemas-upnp-org:device:InternetGatewayDevice:1
```

立即搜索

使用客户端的例子:

```lua

local SsdpClient = require("ssdp/client").SsdpClient
local client = SsdpClient:new()

client:on('response', function(response, rinfo)
    print(response.statusCode, rinfo.ip)
end)

-- get a list of all services on the network 
client:search('ssdp:all')

-- search for a service type 
client:search('urn:schemas-webofthings-org:device')

```

## 类 `SsdpServer`

### SsdpServer:new

> SsdpServer:new(options)

创建一个新的 SSDP 服务器的实例. 

- options `{object}` 选项
    + adInterval `{number}` NOTIFY 广播通告间隔, 单位为秒, 默认为 10 秒
    + ssdpPort `{number}` 要侦听的 UDP 端口, 默认为 1900
    + udn {string} 这个设备的 UUID


### server:start

> server:start()

开始服务，开始在指定的 UDP 端口侦听搜索消息，并定时发送 NOTIFY 广播通告消息。

### server:stop

> server:stop()

停止服务，不再侦听 UDP 端口的消息，并停止定时发送 NOTIFY 广播通告消息。

### server:notify

> server:notify(alive)

立即发送 NOTIFY 广播通告消息, 详情请参考 SSDP 协议详细介绍。

- alive `{boolean}` 通告是上线，还是下线

使用服务端的例子:

```lua

local SsdpServer = require("ssdp/server").SsdpServer
local server = SsdpServer:new()

ssdpServer:addUSN('upnp:rootdevice');
ssdpServer:addUSN('urn:schemas-webofthings-org:device');

ssdpServer:start()

process:on('exit', function()
    ssdpServer:stop() -- advertise shutting down and stop listening 
end)


```


