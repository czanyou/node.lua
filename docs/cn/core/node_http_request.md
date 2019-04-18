# Request



一个简单易用的 HTTP 客户端请求工具。

可以通过 `require('http/request')` 引入这个模块。

## callback 方法

```lua
function callback(err, response, body)
```

这个客户端的相关方法的回调函数。

- err {String} 如果发生错误, 这个值将不为空
- response {HttpResponse Object} 相关的应答消息对象
  + statusCode {Number} 状态码
- body {String} 返回的消息体内容

## request

```lua
request(urlString, [options], callback)
```

发起一个 GET 请求并返回请求结果

- urlString {String}  HTTP URL 地址
- options {Object} 请求选项
  + host {String} 服务器主机地址
  + port {Number} 服务器端口
  + path {String} 文件路径
  + timeout {Number} 超时时间
  + method {String} 请求方法
  + headers {Array} 头字段
- callback {Function} `function(err, response, body) end` 回调函数

示例:

```lua
request('http://test.com/', function(err, response, body)
    if (err) then
        print(err)
        return
    end

    print(response.statusCode, body)
end)

```

## request.delete

```lua
request.delete(urlString, [options], callback)
```

发起一个 DELETE 请求并返回请求结果

- urlString {String} URL
- options {Object} 请求选项
  - data {String} 请求内容为二进制数据
  - json {String} 请求内容为 JSON 字符串
  - form {String} 表单, 使用的格式为 `application/x-www-form-urlencoded`
  - contentType {String} 指定请求内容格式，如 `application/json`
  - headers {Object} 头字段
  - timeout {Number} 超时时间
- callback {Function} `function(err, response, body) end` 回调函数

## request.download

```lua
request.download(urlString, [options], callback)
```

下载文件

- urlString {String} URL
- options {Object} 请求选项
- callback {Function}  `function(err, percent, response, body)` 回调函数
  + err {String} 错误信息
  + percent {Number} 已下载的百分比, 当 percent 等于 100 时表示全部下载完毕
  + response {Object} 应答消息
  + body {String} 应答消息内容

## request.get

```lua
request.get(urlString, [options], callback)
```

发起一个 GET 请求并返回请求结果

- urlString {String} URL
- options {Object} 请求选项
- callback {Function} `function(err, response, body) end` 回调函数


## request.post

```lua
request.post(urlString, [options], callback)
```

发起一个 POST 请求并返回请求结果

- urlString {String} URL
- options {Object} 请求选项
  + data {String} 二进制数据, 默认使用格式为 `application/octet-stream`
  + json {String} JSON 字符串，使用的格式为`application/json`
  + files {Object} 文件, 使用的格式为 `multipart/form-data`
  + form {Object} 表单, 使用的格式为 `pplication/x-www-form-urlencoded`
  + contentType {String} 指定请求内容格式，如 `application/json`
  + headers {Object} 头字段
  + timeout {Number} 超时时间
- callback {Function} `function(err, response, body) end` 回调函数

POST 可以向服务器发送如下内容的数据

### data - 单个文件方式

这种方式适合上传单个文件等, 消息内容仅包含文件的内容.

### json - 发送 JSON 请求数据

```lua
local options = { json = { foo = 'bar' }}
request.post('http://test.com/send', options, function(err, response, body)
    print(response.statusCode, body)
end)
```

### form - 表单方式

表单方式上传的是键值对参数, 以 URL 方式编码.

```json
{'key':'value', ... } 
```

会被编码成:

```json
key=value&foo=bar
```

示例:

```lua
-- 通过表单方式上传数据 
local options = { form = { foo = 'bar' }}
request.post('http://test.com/upload', options, function(err, response, body)
    print(response.statusCode, body)
end)
```

### files - 文件上传

文件上传一般采用这种方式, 参数格式如下:

```json
{
    'key': { 'name': name, 'data': data }
}
```

- key {Object} 代表一个字段或一个文件
  + name {String} 文件名
  + data {String} 文件二进制数据内容

示例:

```lua

-- 通过表单方式上传文件
local filename = 'test.txt'
local filedata = fs.readFileSync(filename) 
local options = { files = { file = { name = filename, data = filedata } } }
request.post('http://test.com/upload', options, function(err, response, body)
    print(response.statusCode, body)
end)

```

## request.put

    request.put(urlString, [options], callback)

发起一个 PUT 请求并返回请求结果

- urlString {String} URL 
- options {Object} 请求选项, 请参考 `request.post`
- callback {Function} `function(err, response, body) end` 回调函数

示例:

```lua
-- 直接上传文件
local filename = 'test.txt'
local filedata = fs.readFileSync(filename) 
local options = { data = filedata }
local urlString = 'http://test.com/upload?filename=' .. filename
request.put(urlString, options, function(err, response, body)
    print(response.statusCode, body)
end)

```


## request.upload

    request.upload(urlString, [options], callback)

发起一个文件上传请求并返回请求结果

- urlString {String} URL 文件上传 URL
- options {Object} 请求选项, 请参考 request.post
  + filename {String} 要上传的文件的名称, 上传格式为表单格式
  + filedata {String} 要上传的文件的内容, 只有当 filename 不为空时有效
  + data {String} 要上传的数据流的内容, 只有当 filename 为空时有效, 上传格式为流的格式
- callback {Function} - `function(err, percent, response, body)` 回调函数
  + err {String} 错误信息
  + percent {Number} 已上传的百分比，当 percent 等于 100 时表示全部上传完毕
  + response {Object} 应答消息
  + body {String} 应答消息内容


