# WOT 云客户端服务

## 概述

- 运行状态灯
- 网络状态状态灯
- 网关根设备
  - 设备
  - 网络
  - 固件
- TCP 隧道
- 远程命令

## WebThings 客户端

底层通信协议为 MQTT，使用了 WoT Script API 接口创建客户端

## 设备注册

注册周期为 1 小时

## 状态上报

### 设备信息

- 设备信息
- 网络信息
- 固件信息

### 设备状态

- CPU
- 内存
- 存储
- 网络

## 设备远程管理

### 设备

当前网关设备监控和维护

#### read

读取当前设备状态

#### reboot

重启设备

#### factoryReset

恢复出厂设置

#### write

设置时间，时区等信息

#### execute

执行远程命令

#### errorReset

重置错误码

#### log

查看日志信息

### 固件

当前网关固件升级和维护

#### read

读取当前固件状态

#### update

更新固件

### 配置参数

读写当前网关配置参数

#### read

读取当前配置参数

#### write

修改当前配置参数

#### reload

重新加载并应用当前配置参数

### 网络

查询网关通信状态

### read

查看当前网络状态

### 外围子设备

用来配置绑定到这个网关的子设备

#### read

读取配置参数

#### write

修改配置参数

### TCP 隧道

用来维护局域网内的其他网络设备

#### read

读取当前状态

#### start

开始 TCP 隧道

#### stop

停止 TCP 隧道

## 固件升级

### 下载

### 安装

### 事件

- 开始下载
- 开始安装
- 完成安装
- 发生错误

### 日志

- 开始下载
- 下载完成
- 开始安装
- 完成安装
- 发生错误

## 子设备管理

子设备类型

了设备 ID

## 远程命令

内存状态

CPU 使用率

网络状态

存储状态

远程命令

## TCP 隧道

目前只支持创建一个 TCP 隧道

## RPC 服务

### firmware

固件升级事件

### tags

发布定位信息

### log

发布日志事件

### status

查看客户端状态

### network

查看客户端连接状态


