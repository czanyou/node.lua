# 应用程序开发指南


本文主要描述如何创建并开发一个新的 Node.lua 应用程序.

## 创建应用

首先在 /node/app 目录下创建一个新的应用目录, 如 "/node/app/test".

注意应用目录名全部为小写字母并且不要超过 8 个字节.

然后在这个目录下新建一个名为 `init.lua`  的 Lua 文件做为这个应用的入口.

其次再创建一个名为 `package.json` 的文件来描述这个应用

## 应用描述

`package.json` 的内容如下:

```json

{
    "depends": ["lnode", "vision"],
    "description": "Test Framework",
    "filename": "test",
    "name": "test",
    "privacy": "system",
    "tags": ["test", "runtime"],
    "version": "1.0.0"
}

```

## 开始编写应用

修改 `init.lua` 文件内容为:

```lua
local app = require('app')

local exports = {}

-- 实现一个名为 help 的 action
function exports.help()
    print("usage: lpm test <start|help|test>")
end

-- 实现一个名为 start 的 action
function exports.start(...)
    print("hello", ...)
end

-- 实现一个名为 print 的 action
function exports.print(...)
    print("print", ...)
end

app(exports) -- APP 入口函数, 会根据命令行参数调用这个应用相关的 action

```

这样我们实现一个只有简单打印功能的应用程序

## 运行应用

上面的脚本可以用 lnode 直接执行, 但是更方便的方法是用 lpm 命令来执行:

比如要执行上面应用的 test 方法的方式为:

`lpm test print bar`

运行后会打印:

`print bar`

首先 lpm 会查找名为 test 的应用程序, 然后执行这个应用的 init.lua 文件, 相当于在 
test 目录执行 `lnode init.lua print bar`

但 lpm 会自动查找要执行的应用的目录, 所有会更加方便, 调用方式也更加统一.
