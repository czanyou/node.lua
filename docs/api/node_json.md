# JSON

[TOC]

通过 require('json') 调用

JSON：JavaScript 对象表示法（JavaScript Object Notation）。

JSON 是存储和交换文本信息的语法。类似 XML。

JSON 比 XML 更小、更快，更易解析。

## json.decode

    json.decode(data)

json.parse 方法的别名

## json.encode

    json.encode(value)

json.stringify 方法的别名

## json.null

代表 JSON 中的 `null` 值, 因为 Lua 中的 table 不允许存放 nil 值, 所以用 json.null 来代表 null 值, 它实际上是一个 userdata 类型的数据.

## json.parse

    json.parse(data)

将 JSON 格式字符串解析为 Lua 对象

- data {String} 要解析的 JSON 格式字符串

## json.stringify

    json.stringify(value)

将 Lua 对象编码为 JSON 格式字符串

- value {Object} 要编码的 Lua 对象, 如 table, 字符串, 数值等等


