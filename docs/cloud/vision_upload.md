# 文件云存储服务

[TOC]

- 作者: 成真

本文主要参考了 7牛 云存储上传接口文档, 目的是为了保持最大限度的兼容, 以便将来能在不同的云存储服务之间迁移.

当使用网络摄像机等设备时会产生较大的图片和短视频等文件数据, 需要用到文件云存储服务, 本文主要定义了上传的接口. 
服务端和客户端可以使用任意语言来实现.

## 基本结构

上传服务主要涉及到如下几个关键组件:

### 云存储服务器

云存储服务以键值对方式提供非结构化资源存储服务, 向业务服务器提供资源管理服务, 向客户端提供上传和下载服务.

### 业务服务器

业务服务器由具体业务开发者管理和维护, 并至少提供如下几个基础功能:

- 生成各钟安全凭证
- 使用数据库存储和管理用户账号信息
- 使用数据库管理用户和文件资源之间的关联
- 提供 API 供客户端访问各个业务接口

### 客户端(或前端)

客户端通常是资源的生产者或者同时也是消费者.

上传文件前需要先从业务服务器取得上传凭证, 否则云存储服务器会拒绝上传的文件.

下载公开的文件资源是不需要下载凭证的, 但下载私有的文件资源除外.

## 存储结构

由于需要分布式存储文件, 所以上传的文件都是 key 的方式来索引文件, 每一个上传的文件都有一个唯一的 key, 相同的 key 表示同一个文件.
这个 key 是由可读字符组成的, 可以由客户端指定, 也可以由服务器自动生成.

所以如下的 key 都是允许的:

- /root/type/time/43435.jpg
- 34ksjgal349895lgaj2342asd.jpg
- 345639.jpg

它们的访问地址将为:

- http://upload.sae-sz.com/iot/root/type/time/43435.jpg
- http://upload.sae-sz.com/iot/34ksjgal349895lgaj2342asd.jpg
- http://upload.sae-sz.com/iot/345639.jpg

但在服务器上的存储路径完全由服务器自行决定.

## 安全机制

在使用云存储服务的过程中，需要考虑安全机制的场景主要有如下几种：

- 上传资源
- 访问资源
- 管理和修改资源

因为生成凭证需要用到密钥等信息, 而密钥不应当发送给客户端或在公网上传输, 所以为了安全起见, 
应当由处在安全环境的业务服务器来生成并通过网络返回这些凭证给客户端, 然后再由客户端使用凭证
和云存储服务器通信.

### 上传凭证

客户端要上传前需先取得上传凭证, 这个凭证是客户端从业务服务器那里取得的. 没有凭证时服务端将返回 401 错误.
云存储服务器和客户端只有上传和下载的接口, 没有其他的业务逻辑.

生成凭证需要如下要素:

- 权限
- 时间戳, 单位为秒, 从 1970-1-1 以来经过的秒数.
- 可选的用户标识 ID

#### 上传策略

注意: 如下流程都是在业务服务器完成的. AccessKey 和 SecretKey 是由云存储服务器管理的, 必须由字
母和数字组成. 业务服务器申请到 AccessKey 和 SecretKey 将它们保存到服务器端, 其中 SecretKey 
不可以公开, 相当于账号和密码的关系. 客户端不需要理解上述内容. 

用 JSON 字符串表示上传策略, 如

```json
{
    "scope": "iot:*",
    "deadline": 1451491200,
    "returnBody": {}
}
```

其中 scope 表示上传范围, 如 iot 表示只可上传到 iot. deadline 表示授权有效时间, 单位为秒. 
returnBody 是可选的. 取决于具体实现.

首先将上述字符串用 base64 编码.

    var encodedPolicy = base64_encode(policy);

将上面编码的字符串和密钥一起用 sha1 算法来签名

    var sign = sha1(policy, "<SecretKey>");

同样再用 base64 编码

    var encodedSign = base64_encode(sign);


最终连接成上传凭证:

    var token = AccessKey + ':' + encodedSign + ':' + encodedPolicy;

    
注意: 为了保证验证正确, 云存储服务器和业务服务器应准确校时, 以免出现奇诡的验证不通过的问题.
    
#### 业务流程

```seq

# 示意图
客户端->业务服务器:  请求上传凭证
业务服务器-->客户端: 下发上传凭证
客户端-->云存储服务器: 上传文件1(附带上传凭证)
云存储服务器-->客户端: 返回上传结果
客户端-->云存储服务器: 上传文件2(附带上传凭证)
云存储服务器-->客户端: 返回上传结果

```

### 下载凭证

在客户端查询私有的文件资源时用到.

TODO: 待完善

```seq
# 示意图
客户端-->云存储服务器: 下载公开文件1
云存储服务器-->客户端: 返回下载结果
客户端->业务服务器:  请求下载凭证
业务服务器-->客户端: 下发下载凭证
客户端-->云存储服务器: 下载私有文件2(附带下载凭证)
云存储服务器-->客户端: 返回下载结果

```

### 管理凭证

在业务服务器删除, 移动文件资源是需用到.

TODO: 待完善

```seq
# 示意图
业务服务器-->云存储服务器: 删除文件(附带管理凭证)
云存储服务器-->业务服务器: 返回删除结果
```

## 上传类型

### 表单上传

使用 HTTP/HTML 表单的方式上传文件, 要求文件在 4M 以内, 且一次只上传一个文件.

### 分片上传

当文件超过 4M 时, 可以使用分片上传, 这时候文件会分为多个 4M 大小以内的块, 上传到服务器后再合并成一个文件. 
可以实现断点续传等功能. 增强大小文件上传体验. 但会增加系统复杂度, 所以在没有这个需求前, 暂时不实现这个接口.

## 表单上传接口

表单上传最基础的接口，用于在一次 HTTP 会话中上传单一的一个文件。

### 使用方法

我们可以用如下的 HTML 表单来描述表单上传的基本用法：

```html
<form method="post" action="http://upload.sae-sz.com/"
 enctype="multipart/form-data">
  <input name="key" type="hidden" value="<resource_key>">
  <input name="x:<custom_name>" type="hidden" value="<custom_value>">
  <input name="token" type="hidden" value="<upload_token>">
  <input name="file" type="file" />
  <input name="crc32" type="hidden" />
  <input name="accept" type="hidden" />
</form>

```

### 请求语法

请求报文的内容以 **multipart/form-data** 格式组织：

```c
POST / HTTP/1.1
Host:           upload.sae-sz.com
Content-Type:   multipart/form-data; boundary=<boundary>
Content-Length: <multipartContentLength>

--<boundary>
Content-Disposition:       form-data; name="token"

<uploadToken>
--<boundary>
Content-Disposition:       form-data; name="key"

<key>
--<boundary>
Content-Disposition:       form-data; name="<xVariableName>"

<xVariableValue>
--<boundary>
Content-Disposition:       form-data; name="crc32"

<crc32>
--<boundary>
Content-Disposition:       form-data; name="accept"

<acceptContentType>
--<boundary>
Content-Disposition:       form-data; name="file"; filename="<fileName>"
Content-Type:              application/octet-stream
Content-Transfer-Encoding: binary

<fileBinaryData>
--<boundary>--

```

#### 头部信息

| 头部名称       | 必填   | 说明
| ---            | ---    | 
| Host	         | 是	  | 上传服务器域名，暂时为 upload.sae-sz.com。
| Content-Type	 | 是	  | 固定为 multipart/form-data。boundary 为 [Multipart格式][multipartFrontierHref]，必须是任何 Multipart 消息都不包含的字符串。
| Content-Length | 是	  | 整个 Multipart 内容的总长度，单位为字节（Byte）。

#### 请求参数

请求报文的每一个参数（以“<>”标记）的具体说明如下表所示（按出现位置顺序排列）：

| 参数名称        | 必填  | 说明
| ---             | ---   | ---    
| token           | 是	  | 上传凭证，位于 token 消息中。
| xVariableName   | 否	  | 自定义变量的名字。
| xVariableValue  | 否	  | 自定义变量的值。
| file            | 是	  | 原文件名。对于没有文件名的情况，建议填入随机生成的纯文本字符串。
| fileBinaryData  | 是	  | 上传文件的完整内容。
| key             | 否    | 资源的最终名称，位于 key 消息中。如不指定则使用上传策略 saveKey 字段所指定模板生成 Key，如无模板则使用 Hash 值作为 Key。

注意：用户自定义变量可以有多对。

### 响应语法

```c
HTTP/1.1 200 OK
Content-Type:   application/json
Cache-Control:  no-store
{
    "hash":  "<Hash>",
    "key":  "<Key>"
}
```

#### 头部信息

| 头部名称	     | 必填	| 说明
| ---           | ---   | ---
| Content-Type	| 是	    | MIME 类型，固定为 application/json。
| Cache-Control	| 是	    | 缓存控制，固定为 no-store，不缓存。

#### 响应内容

如果请求成功，返回包含如下内容的 JSON 字符串（已格式化，便于阅读）：

```json
{
    "hash": "<Hash string>",
    "key":  "<Key string>"
}
```

| 字段名称	| 必填	| 说明
| ---      | ---    | ---
| hash	   | 是	   | 目标资源的 hash 值，可用于 ETag 头部。
| key	   | 是	   | 目标资源的最终名字，可由云存储自动命名。

如果请求失败，返回包含如下内容的JSON字符串（已格式化，便于阅读）：

```json
{
  "code":    "<HttpCode int>", 
  "error":   "<ErrMsg string>"
}
```

| 字段名称	| 必填	| 说明
| ---     | ---     | ---
| code	  | 是	   | HTTP 状态码，请参考响应状态码。
| error	  | 是	   | 与 HTTP 状态码对应的消息文本。


#### 响应状态码

| HTTP 状态码| 含义
| ---       | ---
| 200	    | 上传成功。
| 400	    | 请求报文格式错误，报文构造不正确或者没有完整发送。
| 401	    | 上传凭证无效。
| 413	    | 上传内容长度大于 fsizeLimit 中指定的长度限制。
| 579	    | 回调业务服务器失败。
| 599	    | 服务端操作失败。
| 614	    | 目标资源已存在。

