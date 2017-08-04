# 查询字符串 (query string)

[TOC]

这个模块提供一些解析或者格式化 URL query 字符串的工具。可通过如下的方式访问：

    local querystring = require('querystring')

## querystring.escape

    querystring.escape(str)

对指定的字符串进行百分号方式编码, 特殊字符为替换为百分号加16进制的值。

供 querystring.stringify 使用的转意函数，在必要的时候可被重写。

- str {String}

## querystring.parse

    querystring.parse(str, [sep], [eq], [options])

将一个 query string 解析为一个包含键值对的表。可以选择是否覆盖默认的分割符（'&'）和分配符（'='）。

- str {String} 要解析的 URL query 字符串
- sep {String} 用来分隔键值对的符号，默认为 '&'
- eq  {String} 用来分隔键和值的符号，默认为 '='
- options {Object} 对象可能包含 
  + maxKeys {Number} (默认为 1000), 它可以用来限制处理过的键 (key)的数量. 设为 0 可以去除键 (key) 的数量限制.
  + decodeURIComponent {Function} 用来替代默认的 querystring.unescape 方法

实例：

```lua
    querystring.parse('foo=bar&baz=qux&baz=quux&corge')
    -- returns { foo: 'bar', baz: ['qux', 'quux'], corge: '' }
```

## querystring.stringify

    querystring.stringify(obj, [sep], [eq], [options])

序列化一个包含键值对的表到一个 query 字符串。可以选择是否覆盖默认的分割符（'&'）和分配符（'='）。

- obj {Object} 要序列化为 URL query 字符串的对象
- sep {String} 用来分隔键值对的符号，默认为 '&'
- eq  {String} 用来分隔键和值的符号，默认为 '='
- options {Object} 对象可能包含 
  + encodeURIComponent {Function} 用来替代默认的 querystring.escape 方法

实例：

```lua
    querystring.stringify({ foo: 'bar', baz: ['qux', 'quux'], corge: '' })
    -- returns 'foo=bar&baz=qux&baz=quux&corge='

    querystring.stringify({foo = 'bar', baz = 'qux'}, ';', ':')
    -- 返回如下字串: 'foo:bar;baz:qux'
```

## querystring.unescape

    querystring.unescape(str)

对指定的字符串进行百分号方式解码

供 querystring.parse 使用的反转意函数，在必要的时候可被重写。

- str {String} 
