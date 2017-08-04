# 系统更新

[TOC]

Node.lua 提供了系统热更新功能

## 热更新

热更新指在系统运行过程中可以随时更新应用程序功能

### 检查最新热更新包

> `lpm update`

这个命令会下载最新的热更新包, 热更新包只包含应用程序和扩展库, 不会更新主程序和核心库, 这样做的好处时即保证系统的稳定(不会影响核心应用功能), 又能方便更新应用功能.

```sh
$ lpm update
System target: x64-darwin
Upgrade server: http://node.sae-sz.com
URL: http://node.sae-sz.com/download/dist/x64-darwin/nodelua-x64-darwin-patch.json
The system information is up-to-date!
Done.
Package url: http://node.sae-sz.com/download/dist/x64-darwin/nodelua-x64-darwin-patch.2.0.102.zip
The update file is up-to-date!  /usr/local/lnode/update/patch.zip
Done.
latest version: 2.0.102
bogon:docs chengzhen$ 
```

### 安装最新热更新包

> `lpm upgrade`

这个命令会下载最新的热更新包并安装

```sh
$ lpm upgrade
The system information is up-to-date!
The update file is up-to-date!  /usr/local/lnode/update/patch.zip
Try to lock upgrade...
The "/usr/local/lnode" is a development path.
You can not update the system in development mode.

Upgrade path: /usr/local/lnode

Installing package (/usr/local/lnode/update/patch.zip)
Checking (108)...  
Upgrading system "/tmp" (total 0 files need to update).


Finished
```

## 更新整个系统

### 检查最新版本

> `lpm update system`

这个命令会从服务下载最新的 SDK 信息和更新包

```sh
cz@lnode:/$ lpm update system
System target: x64-linux
Upgrade server: http://node.sae-sz.com/lnode
URL: http://node.sae-sz.com/lnode/download/dist/linux/nodelua-linux-sdk.json
The system information is up-to-date!
Done.
Package url: http://node.sae-sz.com/lnode/download/dist/linux/nodelua-linux-sdk.0.9.17.zip
The update file is up-to-date!  /usr/local/lnode/update/update.zip
Done.
latest version: 0.9.17

```


### 修改更新服务器地址

默认下载地址由 app.rootURL 指定

可以修改 '/usr/local/lnode/package.json' 添加 root_url 属性来指定服务器地址:

    'root_url' : 'http://localhost/node'

你可以执行 `lpm info` 查看当前系统安装路径和更新服务器的地址:

```sh 
cz@lnode:/system/main/node$ lpm path
package.path:
/usr/local/lnode/lua/?.lua
/usr/local/lnode/lua/?/init.lua
/usr/local/lnode/lib/?.lua
/usr/local/lnode/lib/?/init.lua
/usr/local/lnode/app/?/lua/init.lua
./lua/?.lua
./lua/?/init.lua
./?.lua
./?/init.lua

package.cpath:
/usr/local/lnode/bin/?.so
/usr/local/lnode/lib/?.so
/usr/local/lnode/app/?/?.so
/usr/local/lnode/bin/loadall.so
./?.so

app.rootURL:  http://node.sae-sz.com
app.rootPath: /usr/local/lnode
app.target:   x64-darwin
os.arch:      x64
os.time:      1499677378
os.uptime:    879245.0
os.clock:     0.018743

```

### 命令行方式在线升级

> `lpm upgrade system`

### 升级示例

下面是在开发板上模拟在线升级的过程:

```sh
~ # lpm upgrade system
The "/usr/local/lnode" is a development path.
You can not update the system in development mode.

Try to lock upgrade...
Upgrade path: /tmp/lnode
The system information is up-to-date!
The update file is up-to-date!  /usr/local/lnode/update/update.zip

Installing package (/usr/local/lnode/update/update.zip)
Checking (200)...  
Upgrading system "/tmp/lnode" (total 16 files need to update).
Updating (1/16)...  app/httpd/www/appinfo/index.html
Updating (2/16)...  app/httpd/www/common.js
Updating (3/16)...  app/httpd/www/index.html
Updating (4/16)...  app/httpd/www/jquery.js
Updating (5/16)...  app/httpd/www/lang.js
Updating (6/16)...  app/httpd/www/login.html
Updating (7/16)...  app/httpd/www/style.css
Updating (8/16)...  app/lhost/package.json
Updating (9/16)...  app/lhost/www/index.html
Updating (10/16)...  app/mqtt/www/index.html
Updating (11/16)...  app/ssdp/init.lua
Updating (12/16)...  lib/device/init.lua
Updating (13/16)...  lua/ext/lpm.lua
Updating (14/16)...  lua/ext/upgrade.lua
Updating (15/16)...  lua/http/request.lua
Updating (16/16)...  package.json

Total (16) files has been updated!

```

更新程序会自动查询并下载最新稳定版的 SDK, 并且安装时只更新有修改的文件.
