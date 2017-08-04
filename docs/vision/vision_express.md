# Express 嵌入式 WEB 服务器

[TOC]

基于 Node.Lua 平台，快速、开放、极简的 web 开发框架。

这个模块是 Node.js Express 项目的简化版，为了在嵌入系统上运行只实现了最核心的基本功能。

通过 `require('express')` 调用。

## express.app

    express.app()

创建并返回一个 Express 的应用实例

## Application

### app:get

    app:get(path, callback)

使用指定的回调函数处理指定路径的 HTTP GET 请求.

- path {String} 路径
- callback {Function} 回调函数 `function(req, res)`

### app:post

    app:post(path, callback)

使用指定的回调函数处理指定路径的 HTTP POST 请求.

- path {String} 路径
- handler {callback} 回调函数 `function(req, res)`

### app:listen

    app:listen(port, [hostname], [backlog], [callback])

绑定并在指定的端口和主机上侦听连接请求。

- port {Number} 端口
- hostname {String} 主机 IP 地址，没有指定则为 `0.0.0.0`
- callback {Function} 

## Request

### 属性: request.body

请求消息体, 通常是键值表

目前支持以下类型内容的解析:

- application/json
- application/x-www-form-urlencoded
- multipart/form-data (暂未完成)
   
如果是其他未知类型则 body 为请求消息原始内容 

### 属性: request.hostname

请求的主机地址

### 属性: request.path

请求的路径

### 属性: request.protocol

请求协议类型, 一般为 'http' 或 'https'.

### 属性: request.query

请求 URL 参数键值表

### request:get

    request:get(field)

返回指定名称的头字段的值

- field {String} 头字段的名称

### request:getSession

    request:getSession(create)

- create {Boolean} 如果不存在，是否创建一个

### request:readBody

    request:readBody(callback)

读取请求消息内容，读取结果保存在 request.body 属性中

具体请参考 request.body 属性

- callback `function() end` 当请求收到 'end' 事件后调用这个函数

注意：一般不需要直接调用这个方法，但在一些情况下例外：
所有 `<app>/www` 目录下的 lua 文件中的 request 对象是需要手动调用这个方法的，即默认 request.body 为空，但是如果调用了 `httpd.call` 后就不需要手动调用了，这样设计的目的是为了让应用开发者能处理更多细节的东西，比如上传大文件等。

## Response

### 属性: response.headersSent

Boolean 类型，指出当前 HTTP 应答头字段是否已发送.

### response:sendStatus

    response:sendStatus(statusCode, message)

发送指定的状态码的应答消息

- statusCode {Number}  消息状态码
- message {String} 消息状态字符串

### response:json

    response:json(value)

发送 JSON 内容的应答消息

- value {Object} 要转换的对象

### response:send

    response:send(text)

发送指定字符串内容的应答消息

- text {String}

### response:sendFile

    response:sendFile(filename)

发送指定名称的文件或目录的内容的应答消息

- filename {String} 要发送的文件的名称

这个方法最终会根据文件的类型来调用 sendFileList, sendStaticFile 或 sendScriptFile 方法.


### response:sendScript

    response:sendScript(script, [name])

发送指定名称的脚本文件执行的结果的应答消息

- script {String} 要执行的脚本的内容
- name {String} 要执行的脚本的名称

这个方法会传递 request, response 对象给脚本并会动态执行指定的脚本。


### response:sendStatus

    response:sendStatus(statusCode, [statusMessage])

发送指定状态的应答消息

- statusCode {Stream} 要发送的状态码
- statusMessage {String} 要发送的状态字符串

### response:sendStream

    response:sendStream(stream, [contentType], [contentLength])

发送指定流的应答消息

- stream {Stream} 要发送的流
- contentType {String} 要发送的流的 MIME 类型
- contentLength {Number} 要发送的数据的长度

### response:status

    response:status(code)

设置应答状态码

- code {Number}

### response:set

    response:set(field, [value])

设置头字段

- field {String|Object} 头字段的名称或头字段的集合
- value {String} 头字段的值

```lua

res:set('Host', '192.168.1.1')

or 

res:set({'Host' =  '192.168.1.1', 'Server' = 'Express'})

```

