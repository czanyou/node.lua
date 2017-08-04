# URL

[TOC]

该模块包含用于 URL 解析的实用函数。 使用 `require('url')` 来调用该模块。

## URL Parsing

不同的 URL 字符串解析后返回的对象会有一些额外的字段信息，仅当该部分出现在 URL 中才会有。以下是一个 URL 例子：

```
'http://user:pass@host.com:8080/p/a/t/h?query=string#hash'
```

- href: 所解析的完整原始 URL。协议名和主机名都已转为小写。

```
Example: 'http://user:pass@host.com:8080/p/a/t/h?query=string#hash'
```

- protocol: 请求协议，小写

```
Example: 'http:'
```

- slashes: The protocol requires slashes after the colon.

```
Example: true or false
```

- host: URL主机名已全部转换成小写, 包括端口信息

```
Example: 'host.com:8080'
```

- auth: URL中身份验证信息部分

```
Example: 'user:pass'
```

- hostname: 主机的主机名部分, 已转换成小写

```
Example: 'host.com'
```

- port: 主机的端口号部分

```
Example: '8080'
```

- pathname: URL的路径部分,位于主机名之后请求查询之前.

```
Example: '/p/a/t/h'
```

- search: URL 的“查询字符串”部分，包括开头的问号。

```
Example: '?query=string'
```

- path: pathname 和 search 连在一起。

```
Example: '/p/a/t/h?query=string'
```

- query: 查询字符串中的参数部分（问号后面部分字符串），或者使用 querystring.parse() 解析后返回的对象。

```
Example: 'query=string' or {'query':'string'}
```

- hash: URL 的 “#” 后面部分（包括 # 符号）

```
Example: '#hash'
```

### Escaped Characters

Spaces (' ') and the following characters will be automatically escaped in the properties of URL objects:

```
< > " ` \r \n \t { } | \ ^ '
```

## url.format

    url.format(urlObj)

输入一个 URL 对象，返回格式化后的 URL 字符串。

- href 属性会被忽略处理.
- protocol 无论是否有末尾的 : (冒号)，会同样的处理
    + 这些协议包括 http, https, ftp, gopher, file 后缀是 :// (冒号-斜杠-斜杠).
    + 所有其他的协议如 mailto, xmpp, aim, sftp, foo, 等 会加上后缀 : (冒号)
- auth 如果有将会出现.
- hostname 如果 host 属性没被定义，则会使用此属性.
- port 如果 host 属性没被定义，则会使用此属性.
- host 优先使用，将会替代 hostname 和 port
- pathname 将会同样处理无论结尾是否有/ (斜杠)
- search 将会替代 query属性
- query (object类型; 详细请看 querystring) 如果没有 search,将会使用此属性.
- search 无论前面是否有 ? (问号)，都会同样的处理
- hash 无论前面是否有# (井号, 锚点)，都会同样处理

## url.parse

    url.parse(urlStr[, parseQueryString][, slashesDenoteHost])

输入 URL 字符串，返回一个对象。

将第二个参数设置为 true 则使用 querystring 模块来解析 URL 中的查询字符串部分，默认为 false。

将第三个参数设置为 true 来把诸如 //foo/bar 这样的 URL 解析为 { host: 'foo', pathname: '/bar' } 而不是 { pathname: '//foo/bar' }。 默认为 false。


## url.resolve

    url.resolve(from, to)

给定一个基础 URL 路径，和一个 href URL 路径，并且象浏览器那样处理他们可以带上锚点。 例如：

```lua
url.resolve('/one/two/three', 'four')         -- '/one/two/four'
url.resolve('http://example.com/', '/one')    -- 'http://example.com/one'
url.resolve('http://example.com/one', '/two') -- 'http://example.com/two'
```
