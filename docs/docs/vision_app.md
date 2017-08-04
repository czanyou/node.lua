# 应用程序开发指南

[TOC]

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

## 应用图标

在应用程序目录添加一个名为 'icon.png' 的文件即可

## WEB 访问插件

在应用程序目录添加一个 www 的子目录, 用户打开应用程序管理后台, 访问这个应用时, 会自动加载这个目录下的 `index.html` 文件, 
相当于一个 Web APP.

所有包含 www 子目录的应用都会显示在 WEB 管理后台主页中

### 动态脚本

所有 www 目录下的 lua 文件都会被动态加载运行

默认有 `request` 和 `response` 两个全局变量

默认 request.body 为空没有被读取，可以调用 request.readBody() 方法自动读取并解析请求消息内容。

### httpd 模块

通过 require('httpd') 引入.

httpd 应用提供的通用的辅助方法，方便开发动态 lua WEB 页面

#### httpd.isLogin

    httpd.isLogin(request)

指出用户是否登录

#### httpd.call

    httpd.call(methods, request, response)

通用的 API 分发方法，请求 URL 中必须带名为 api 的参数

- methods {Object} 键名为 api 名称（或路径），值为处理方法: `function(request, response)`
- request {Object} 请求对象，这里的 request.body 已经读取完毕, 可以直接使用
- response {Object} 应答对象

比如:

```lua
local function on_login(request, response)
    local status = { ret = 0 }
    response:json(status)
end

local function on_logout(request, response)
    local status = { ret = 0 }
    response:json(status)
end

local methods = {}
-- api 处理方法列表
methods['/login']  = on_login
methods['/logout'] = on_logout

-- /login 方法不需要登录认证也可以访问
methods['@noauth'] = { ['/login'] = true }

httpd.call(methods, request, response)

```

## 特殊应用

Node.lua 中内置了多个系统应用, 提供了一些很有用的基本功能, 它们分别是:

### build

构建工具, 只用于开发机, 在开发板上一般用不到.

主要功能是用来打包应用程序, 以及打包 Node.lua SDK 包.

### httpd

嵌入式 WEB 服务器, 一般在 80 端口侦听, 提供一个统一的 WEB 访问接口.

其他应用可以提供插件 (添加 www 子目录), 使用户通过 WEB 后台来访问.

httpd 提供了基本的用户登录，应用列表，多语言等服务

httpd 还提供了如下共用的资源文件：

#### /api.lua

全局动态脚本，提供的主要 WEB API 如下：

- /login (password,username) 用户登录
- /logout 用户注销
- /applications 返回应用程序列表
- /application/info (path) 返回指定的名称的应用程序的详细信息

#### /jquery.js

jquery JavaScript 脚本

#### /common.js

提供一些公共方法的 JavaScript 脚本

包含且不限于：

- $.form.init(values, form) 
- $.form.isIpAddress(address, flags)
- $.form.nextElement(obj)
- $.form.setElementValue(form, name, value)
- $.form.showTip(input, isRight, text)
- $.format.formatBytes(value)
- $.format.formatFloat(value, n)
- $.lang.name()
- $.lang.select(lang)
- $.lang.update(type, data)
- $.parseIn(value, defaultValue)
- $translate(element)
- OnAppStatusGetDetailHTML(data)
- OnAppStatusPageLoad()
- OnLeftMenuClick()
- OnLeftMenuDefaultItem()
- OnLeftMenuHashChange(hash)
- OnLeftMenuInit()
- OnLeftMenuItemClick()
- OnLeftMenuPageResize()
- OnLogout()
- String.prototype.startsWith(str)
- String.prototype.trim()
- T(key, defaultText)
- validateIPAddress()

#### /favicon.ico

默认的图标文件

#### /index.html

默认的首页，主要是实现应用列表的功能

#### /lang.js

提供基本的多语言方法的 JavaScript 脚本

在应用程序中添加多语言的方法如下：

```js
var VisionLangZh =
{
    Version             : "版本"
}

var VisionLangEn =
{
    Version             : "Version"
}

$.lang.update('zh-cn', VisionLangZh) // 添加简体中文翻译条目
$.lang.update('en',    VisionLangEn) // 添加英文翻译条目
```

在 html 页面中，直接在写页面中使用 ${Version} 的形式即可，会被自动替换成相应的多语言文本

```html
<!DOCTYPE html>
<html>
<head>
  <title>Settings</title>
  <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, minimum-scale=1.0, user-scalable=no"/>
  <link rel="stylesheet" href="/style.css?v=100001"/>
  <script src="/jquery.js?v=100001"></script>
  <script src="/common.js?v=100001"></script>
  <script src="lang.js?v=100001"></script>
  <script>
    window.onhashchange = OnLeftMenuHashChange;
    window.onresize = OnLeftMenuPageResize;

    $(document).ready(function() {
        $translate(document.body)

        OnLeftMenuInit()
    });
  </script>
</head>
<body class="frame-body" style="display:none;">

<div id="wrapper" class="frame-wrapper">
  <div id="left-wrapper"> 
    <div id="sidebar" class="sidebar"><div class="block leftmenu" id="basic_menu">
        <a class="home" href="/index.html">${Home}</a>
        <h1>${NetworkSettings}</h1>
        <div id="menu-header" style="display:none;"></div>
        <ul id="left_menu_list">
        <li><a id="menu_item" name="menu_item" href="#status">${About}</a></li>
        <li><a id="menu_item" name="menu_item" href="#network">${NetworkSettings}</a></li>
        <li><a id="menu_item" name="menu_item" href="#wireless">${WirelessSettings}</a></li>
        </ul>
    </div></div>
  </div>

  <div id="container">
    <div id="frame-content-wrapper"><div id="container-header">X</div><iframe id="frame-content" name="frame-content" frameborder="0"></iframe></div>
  </div>
</div>

</body>
</html>
```

#### /login.html

默认的登录页面

#### /style.css

全局样式文件


### mqtt

嵌入式 MQTT 客户端, 提供一个统一的 MQTT 客户端, 其他应用可以通过这个应用间接地发布或接收 MQTT 消息, 而不必每个应用都建立一个和 MQTT 服务器的连接.

### ssdp

提供 SSDP 服务, 使这个设备可以被其他设备扫描到.

### lhost

这个是一个应用守护应用, 它主要用于监控和管理其他应用, 在其他应用意外退出地, 能自动重启它们, 保存相关的应用程序能在后台一直运行.

注意目前只支持 linux 系统, 其他平台只支持其中很小的一部分功能.

因为开发板一般都是嵌入式 linux 系统, 而这个功能一般只用在开发板上, 所以暂时不考虑支持其他平台.

### sdcp

实现简单的设备控制协议.

用来管理设备以及管理和云服务器的通信.



