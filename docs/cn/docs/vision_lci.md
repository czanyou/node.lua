# lci 命令行配置工具

## 概述

- 运行环境初始化
- 网络管理
  - 指定 MAC 地址
  - 4G 拨号
  - DHCP 动态地址分配
  - 静态 IP 地址
- WEB 配置服务
- 时间同步服务
- Reset 按键监控和处理
- 定时重启设备
- 其他网络服务

## 命令列表

### activate

> lci activate <password>

激活设备

### boot

> lci boot

在设备启动时执行，完成一些 Node.lua 所需要的初始化工作

- 初始化 GPIO 口
- 初始化 /var/xxx 目录
- 初始化 /etc/init.d/xxx 等初始化脚本
- 初始化 pppd 所需要的配置文件

###board

> lci board <board>

初始化指定名称的开发板信息

- 指定开发板信息

###get

> lci get <url> 

执行 HTTP GET 请求

### info

> lci info

查看网络等信息

### password

> lci password <username> <password>

修改 WEB 管理密码

### post

> lci post <url>

执行 HTTP POST 请求

### reset

> lci reset

恢复出厂设置

- 恢复网络参数设置
- 恢复用户配置参数
- 恢复到未激活状态

### service

> lci service <name>

执行指定名称的服务

- button 在后台监控 reset 等按键状态和事件
- crond 运行和监控 crond 服务
- dhcp 运行和监控 dhcp 客户端
- http 运行和监控 web 配置服务
- network 运行和监控网络配置服务
- ntp 运行和监控 ntp 时间同步服务
- rpc 运行和监控 lci RPC 服务
- schedule 运行和监控定时重启服务

### start

> lci start

执行所有的服务

### switch

> lci switch <name> [value]

查看或设置指定名称的 GPIO 的值

### test

> lci test <name>

自检测试

### view

> lci view <name>

查看指定名称 RPC 服务的状态