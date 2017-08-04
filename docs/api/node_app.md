# Node.lua 应用

[TOC]

> 未稳定: 这个模块的方法还在随时调整中


这个模块提供了一些用于开发 Node.lua 应用程序的便利方法 

可通过 `require('app')` 引入。

应用程序为一个独立的文件夹包含了入口脚本 (init.lua), 描述文件(package.json), 资源文件等多个文件, 并在 init.lua 中提供了多个导出方法 (action) 可以被分别调用

Node.lua 应用可以用 lpm 命令行工具快速调用, 其格式通常如下

    lpm <app> <action> [args, ...]

- app 是要执行的应用的名称
- action 要执行的方法, 如果没有指定则通常会调用 help 方法
- args 多个要传给这个方法的参数, 可选

例如: `lpm lhost list` 表示执行 lhost 应用的 list 方法, 这个方法会打印当前正在运行的所有应用.

常用的 action 有:

- help 显示使用帮助信息
- start 运行当前应用, 会在执行 `lpm start <app>` 时默认调用, 要实现一个后台应用必须实现这个方法

开发者还可以自行添加其他 action, 但是尽量不要改变上述 action 的默认行为方式, 以免引起使用者迷惑!

这是一个简单的 Node.lua 应用模版 (test):

```lua

local app = require('app')

-- 定义一个表格, 用来存放要导出的方法
local exports = {}

-- 导出一个名为 help 的方法, 一般用来打印帮助信息
function exports.help()
    print("usage: lpm test <start|help|test>")
end

-- 导出一个名为 start 的常用方法 
function exports.start(...)
    print("hello", ...)
end

-- 导出一个名为 test 的自定义方法 
function exports.test(...)
    print("test", ...)
end

-- 根据命令行参数决定并执行上述导出的相关的方法
app(exports)

```

这个应用可以通过 `lpm test start` 以及 `lpm test test` 来调用

如果没有指定 action 则默认会调用 help 这个方法.


## app

    app(exports)

运行当前的 APP, 一般在应用程序 init.lua 最后调用这个方法.

- exports {Object} 要运行的 APP


## 属性 app.rootPath

{String} Node.lua 的安装根目录.

比如在 linux 下默认为 '/usr/local/lnode'.


## 属性 app.rootURL

{String} Node.lua 的云服务访问地址, 云服务主要提供热更新等功能.

可以添加一个名为 ${exports.rootPath}/conf/root.url 的文件来替换默认的 rootURL.

比如默认为 'http://node.sae-sz.com'.


## app.get

    app.get(key)

返回指定的名称的配置参数的值, 是对 conf.get 的封装

- key {String} 以 '.' 分隔的参数名

比如:

```lua
local value = app.get('video.width')
```


## app.del

    app.del(key)

删除指定的名称的配置参数的值, 是对 conf.del 的封装

- key {String} 以 '.' 分隔的参数名


## app.set

    app.set(key, value)
    app.set(table)

修改指定的名称的配置参数的值, 是对 conf.set 的封装

- key {String} 以 '.' 分隔的参数名
- value {String|Number} 要修改的参数的值
- table {Object} 名称和值对表格, 可一次性修改多个参数的值

比如:

```lua
app.set('video.width', 100)

app.set({'video.width' = 100, 'video.height' = 80})

```


## app.daemon

    app.daemon(name)

调用这个方法会让指定名称的应用程序在后台运行.

注意后台模式目前不支持 Windows

- name 要在后台运行的应用的名称


## app.execute

    app.execute(name, ...)

执行指定名称的应用程序

- name {String} 要执行的应用程序的名称
- ... 调用方法时所需的参数


## app.list

    app.list()

打印所有安装的应用


## app.main

    app.main(handler, action, ...)

默认 main 函数, 即根据参数的值来决定调用 APP 哪个方法, 这样 APP 可以不用自己实现入口函数, 
只需实现具体子方法即可被自动调用

- handler {Object} 处理器, 包含多个不同名称的方法可被调用
- action {String} 要执行的方法名
- ... 从命令行传入的其他参数, 将作为要调用的方法的输入参数


## app.tableDivision

    app.tableDivision(cols, ch)

打印表格分隔线

- cols {Array} 每一列的宽度, 单位为字符
- ch {String} 要打印的分隔线符号, 默认为 '-'


## app.tableHeader

    app.tableHeader(cols, title)

打印表格标题

- cols {Array} 每一列的宽度, 单位为字符
- title {String} 要打印的标题


## app.tableLine

    app.tableLine(cols, ...)

打印表格行, 应用中常需要打印一些表格信息, 这里提供标准和统一的打印方法

- cols {Array} 每一列的宽度, 单位为字符, 如 '{16, 8, 8, 12}'
- ... {Any} 要打印的值


## app.rpc

    app.rpc(name, handler)

创建一个远程过程调用服务器

- name {String} 侦听的名称
- handler {Object} 远程方法提供者

返回创建的 RPC 服务器

示例:

```lua
-- server
local server = app.rpc('foo', {
    bar = function(self, ...)
        console.log(...)
    end
})

-- client
local rpc = require('ext/rpc')
rpc.call('foo', 'bar', 100)

-- print:
-- 100

```

## app.target

     app.target()

返回当前目标板的名称


## app.usage

    app.usage(dirname)

这个方法能够根据 package.json 的描述打印当前 APP 的使用方法等信息.

- dirname {String} 当前 APP 所在目录
