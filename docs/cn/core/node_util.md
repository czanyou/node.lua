# 工具类 (util)

util 提供一些便利的方法, 模块主要用于支持 Node.lua 内部开发, 也可以用于应用程序和模块开发者.

可通过 `require('util')` 调用

## 协程

### util.async

> `util.async(func, ...)`

创建一个协程来执行指定的函数. 和 await 配合使用.

- func `{function}` 要在协程中的运行的函数
- ... 执行这个函数时的参数

返回 co, err

- co `{object}` 相关的协程对象
- err `{string}` 如果运行中发生错误


### util.await

> `util.await(func, ...)`

异步等待, 用来执行异步方法, 必须在协程内调用这个方法, func 函数的最后一个参数必须是回调函数. 和 async 配合使用.

- func `{function}` 要调用的异步函数, 函数的最后一个参数必须是回调函数.
- ... 调用这个函数的参数

这个方法可把异步函数改为同步风格来调用, 这样  方法会直接返回回调函数参数, 使代码更好读避免陷入回调地狱.

如通常异步方法调用方式为:

```lua

local async_func = function(arg, callback)
    callback(arg * 10)
end

async_func(10, function(result)
    print(result) -- result = 100

    async_func(result, function(result)
        print(result) -- result = 1000

        async_func(result, function(result)
            print(result) -- result = 10000
        end)
    end)
end)

```

改为 async/await 调用方式后:

```lua
local await = util.await

local async_func = function(arg, callback)
    callback(arg * 10)
end

util.async(function(param)
    local result = await(async_func, param)
    print(result) -- 100

    result = await(async_func, result)
    print(result) -- 1000

    result = await(async_func, result)
    print(result) -- 10000

end, 10)
```

### util.bind

> `util.bind(func, self, ...)`

一般类的成员方法会内含 self 的首参数, 这样就不适合作为回调函数使用.

通过 util.bind 可以将类的成员方法变为可用的回调方法

- func `{function}`
- self `{object}`

```lua

local BindHelper = Object:extend()

function BindHelper:onTest(arg)
  console.log(self, arg)
  -- 期望是 object, 100
end

function test(arg, callback)
  callback(arg)
end

local object = BindHelper:new()

-- 错误的设置回调函数
test(100, object.onTest)

-- 设置正确的相匹配的回调函数
test(100, util.bind(object.onTest, object))   

```

## 字符编码

### util.base64Decode

> `util.base64Decode(encodedData)`

将 BASE64 编码字符串解码。

- encodedData `{string}` BASE64 编码字符串

返回解码后字符串


### util.base64Encode

> util.base64Encode(data)

将字符串以 BASE64 编码。

- data `{string}` 字符串

返回编码后的字符串

本函数将字符串以 MIME BASE64 编码。此编码方式可以让中文字或者图片也能在网络上顺利传输。

在 BASE64 编码后的字符串只包含英文字母大小写、阿拉伯数字、加号与反斜线，共 64 个基本字符，

不包含其它特殊的字符，因而才取名 BASE64。编码后的字符串比原来的字符串长度再加 1/3 左右。

更多的 BASE64 编码信息可以参考 RFC2045 文件之 6.8 节。

### util.hexEncode

> `util.hexEncode(data)`

将二进位字符串转成十六进位字符串。

- data `{string}` 二进位字符串

返回编码后的字符串

### util.hexDecode

> `util.hexDecode(data)`

将十六进位字符串转成二进位字符串。

- data `{string}` 十六进位字符串

返回解码后的字符串

## 源代码路径

### util.dirname

> `util.dirname()`

返回当前脚本所在的目录名.

### util.filename

> `util.filename(index)`

返回当前脚本的文件名.

- index 调用堆栈索引

## 哈希值

### util.md5

> `util.md5(data)`

计算字符串的 MD5 散列值。

- data `{string}` 字符串

返回一个 16 字节长度的原始二进制格式散列值。

### util.md5String

> `util.md5String(data)`

计算字符串的 MD5 散列值。

- data `{string}` 原始字符串

返回一个 32 字符长度的十六进制数字形式散列值。

```lua
local util = require('util')
local assert = require('assert')

local data = 'apple'
assert.equal(util.md5String(data), '1f3870be274f6c49b3e31a0c6728957f')

```

### util.sha1

> `util.sha1(data)`

计算字符串的 SHA1 散列值。

- data `{string}` 原始字符串

返回一个 20 字节长度的原始二进制格式散列值。

### util.sha1String

> `util.sha1String(data)`

计算字符串的 SHA1 散列值。

- data `{string}` 原始字符串

返回一个 40 字符长度的十六进制数字形式散列值。

```lua
local util = require('util')
local assert = require('assert')

local data = 'apple'
assert.equal(util.sha1String(data), 'd0be2dc421be4fcd0172e5afceea3970e2f3d940')

```
