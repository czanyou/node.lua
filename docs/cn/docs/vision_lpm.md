# lpm 命令行工具


## 状态

这个模块还在完善中。


## 简介

lpm (lua package manager)

lpm 提供了一系统命令行工具, 方便开发, 管理, 使用 Node.lua 以及其应用程序.

注意 lpm 部分功能是内置的功能, 部分功能由应用程序提供需要安装相关的应用才能使用.


## 配置文件管理

### config

查看/修改配置文件

lpm 配置文件一般都保存在 `/usr/local/lnode/conf` 目录下

conf 文件内容为 JSON 文本格式, 支持多级参数

- `lpm config unset <key>` 删除指定名称的参数
- `lpm config get <key>` 打印指定名称的参数的值
- `lpm config list [name]` 打印配置文件的内容
- `lpm config set <key> <value>` 设置指定名称的参数的值
- `lpm config setjson <key> <value>` 设置指定名称的参数的 JSON 值
- `lpm unset <key>` 删除指定名称的参数
- `lpm get <key>` 打印指定名称的参数的值
- `lpm set <key> <value>` 设置指定名称的参数的值

参数:

- key 参数名, 多级参数以 '.' 分隔, 只支持字母数定和下划线等.
- value 参数值

默认会保存到 `/usr/local/lnode/conf/user.conf` 文件中

在源代码中可以通过 require('app/conf') 模块来访问配置文件.

比如:

```sh
# 修改 user.conf 文件, 将 lan.ipaddr 的值修改为 192.168.1.8
$ lpm set lan.ipaddr 192.168.1.8

# 查看 user.conf 配置文件内容
$ lpm config list
```

### unset

删除指定的名称的配置参数

是 `lpm config unset` 命令的缩写

    lpm unset <key>

key 可以是用 '.' 分隔的多级参数名.


### get

查询并显示指定的名称的配置参数

是 `lpm config get` 命令的缩写.

    lpm get <key>

key 可以是用 '.' 分隔的多级参数名.


### set

设置指定的名称的配置参数的值

是 `lpm config set` 命令的别名

    lpm set <key> <value>

key 可以是用 '.' 分隔的多级参数名.

### setjson

设置指定的名称的配置参数的值

是 `lpm config setjson` 命令的别名

    lpm setjson <key> <value>

- key 可以是用 '.' 分隔的多级参数名.
- value JSON 字符串

## 应用管理

### kill

杀掉指定名称应用的进程

    lpm kill <name>

- name 要杀掉的应用的名称

注意杀掉以 daemon 模式运行的应用, 还是会自动重启, 如果要彻底关闭这个应用需调用 `lpm stop` 命令, 更多信息请参考 lhost.app


### list

显示当前安装的所有应用

    lpm list


### ps

查看所有正在运行的应用的进程的列表

    lpm ps

注意这个命令暂时只支持 linux 系统.


### restart

重新启动指定的名称的应用

    lpm restart [name]

- name 要重启的应用的名称


### start

    lpm start <name>

以守护进程 (daemon) 模式运行指定名称的应用, 对于服务型应用如 WEB 服务器常以这个模式运行.

这个命令实际还是调用的应用的 'start' 方法. 所以实际执行的命令是:

`lnode -d /usr/local/lnode/app/test.app/init.lua start`

- name 要在后台运行的应用的名称

注意这个命令同时会向 lhost.app 注册为监控状态, 当这个应用意外退出时会被 lhost 自动重启.

如果要注销监控状态, 可使用 `lpm stop` 命令来关闭这个应用.

更多信息请参考 lhost.app


### stop

停止指定的名称的应用程序

     lpm stop [name]

- name 要停止指定的应用程序

执行这个命令会同时杀掉应用程序进程并从 lhost 注销, 防止再次自动重启.

## 系统更新

### install

> lpm install <filename>

安装固件文件

### update

从源下载最新更新包, 下载最新的 package.json 文件以及 nodelua-xxx-patch.zip

    lpm update

- 默认只下载更新包

### upgrade

更新 Node.lua 系统

    lpm upgrade
    lpm upgrade system

- 默认显示升级状态
- 如果指定了 system 参数则下载并安装整个系统安装包 (nodelua-xxx-sdk.zip)

## 其他

### bin

显示 Node.lua 可执行文件所在目录

### colors

显示 console 可以输出的颜色

### help

显示帮助信息

    lpm help

### info

显示 Node.lua 运行时信息

### root

显示 Node.lua 所在根目录

### scan

搜索局域网内的设备

在设备上运行 ssdp 这个 APP 就可以被扫描到.

    lpm scan [timeout]

- timeout 扫描时间, 单位为秒

### version

显示 Node.lua 版本信息

### wget

下载文件
