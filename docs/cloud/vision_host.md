# 蓝牙主机通信协议

[TOC]

> 版本: 1.4 草稿版
> 
> 编写: 成真

本文主要描述了基于 MCU 的蓝牙主机和云服务器之间的通信协议

本文档非最终版本，随时可能更新，仅供参考

## 名词

- **蓝牙主机:** 指具有蓝牙采集模块，并能和云服务器通过 TCP/IP 通信的设备

- **iBeacon:**  Apple 定义的低功耗蓝牙信标协议, 包含 UUID, Major, Minor 等信息

- **蓝牙广播包:**  指 iBeacon 等蓝牙设备定时发送的广播数据包, 通常不超过 31 个字节

- **蓝牙应答包:**  指 iBeacon 等蓝牙设备在收到主机扫描请求时回应的广播数据包

- **RSSI:** 接收信号强度, -255dB 到 0dB 之间

- **MAC** 指通信模块的物理地址, 通常为 6 个字节

- **网管服务器** 指管理蓝牙主机等网络设备的管理服务器

- **采集服务器** 指接受并处理蓝牙广播数据的服务器

## 公共定义

### 固件版本

用整数表示，数据越大版本越新， 如 100.

### 设备型号

> 产品系列(大写字母) + 数字编号 + 'v' + 硬件版本(数字)

用大写首字母表系列，多个数字表示具体型号，v加上数字表示PCBA 版本:

- P4011-v3 可表示 POE 版蓝牙 4.0 主机第3版
- W5012-v2 可表示 WiFi 版蓝牙 5.0 主机第2版

具体编号等选型完成后再协商确定

### 系统时间

用整数表示, 单位为秒，表示 1970-1-1 以来经过的秒数


## 数据格式

### 键值对字符串格式

对于参数等简单的数据采用键值对字符串格式，直观，容易解析：

| MIME-Type                 | ID   | Reference
| ---                       | ---  | ---
| text/plain;charset=utf-8  | 0    | - 

**每行一个键值对, 键和值用 = 号分隔, 如:**

```json
foo=124
name=Lucy
```

### 二进制流数据格式

对于非常复杂的数据则使用二进制流数据格式

| MIME-Type                  | ID   | Reference
| ---                        | ---  | ---
| application/octet-stream   | 42   | -


## 系统配置参数表


| 参数          | 读写    | 默认值            | 说明
| ---           | ---     | ---              | ---
| server_host   | 只读    | nms.beaconice.cn | 服务器的 IP 或域名
| server_port   | 只读    | 8907             | 服务器的访问端口
| wl_ssid       | 只读    | SAE_BEACONICE    | WiFi SSID
| wl_key        |  *      | beaconice        | WiFi 密码
| mac           | 只读    | -                | 网口的 MAC 地址, 必须固定和唯一
| version       | 只读    | -                | 当前固件版本
| model         | 只读    | -                | 当前硬件型号
| ble_mac       | 只读    | -                | BLE 的 MAC 地址, 非必须
| date          | 只读    | -                | 系统时间, 自 1970-1-1 以来经过的秒
| expired       | 读写    | 3600             | 单位为秒, 注册期满时间
| heartbeat     | 读写    | 60               | 单位为秒, 心跳间隔时间, 
| interval      | 读写    | 1                | 单位为秒, 最长批量上传间隔
| collect_host  | 读写    | -                | 采集服务器的 IP 或域名
| collect_port  | 读写    | -                | 采集服务器的访问端口

*: 为了安全起见, Wi-Fi 密码无法读出

## CoAP 底层通信协议

因为 MCU 代码和 RAM 空间有,限，所以选用 CoAP 协议作为通信的基础协议，CoAP 类似 HTTP 协议， 二进制格式基于 UDP, 具体请参考 RFC7252

### 通信流程


```seq
# 示意图
蓝牙主机->网管服务:   1) GET register
网管服务-->蓝牙主机:  2.05 with config payload
蓝牙主机->采集服务器:   2) POST push
采集服务器-->蓝牙主机:  2.01 Created

蓝牙主机->网管服务:   3) PING
网管服务-->蓝牙主机:  RESET
蓝牙主机->网管服务:   4) PING
网管服务-->蓝牙主机:  RESET
```

图1: 蓝牙主机正常工作通信流程

- 1): 蓝牙主机首先向网管服务器发起注册请求
- 注册通过后网管服务器向主机下发配置参数表, 其中包含采集服务器的地址和端口
- 2): 蓝牙主机向采集服务器发送 push 请求上报采集到的蓝牙广播数据
- 3~4): 蓝牙主机定时向网管理服务器发送心跳消息


```seq
浏览器客户-->网管服务:  HTTP GET: 请求立即更新固件
网管服务->蓝牙主机:   5) GET upgrade
蓝牙主机-->网管服务:  2.05 with action result
蓝牙主机->网管服务:   6) GET firmware
网管服务-->蓝牙主机:  2.05 with firmware data
```

图2: 蓝牙主机固件强制更新通信流程

- 5): 由网管服务器向指定的蓝牙主机发起更新固件请求
- 6): 蓝牙主机收到请求后, 向网管服务器下载所需的固件用于升级


## 上报数据

** 请求 **

> push

请求类型为 POST

通过蓝牙主机采集周边的蓝牙广播数据包，并实时上报给云服务器

| 参数          | 必须  | 说明
| ---           | ---  | ---
| mac           | 是    | Host 网口的 MAC 地址


** 要上报的内容 **

- 蓝牙广播包内容（原封不动上传给云服务器）
- 发送此蓝牙广播包的蓝牙设备的 MAC 地址
- 接收此蓝牙广播包的 RSSI 值 （用来估计发送距离)

** 上报策略 **

因为短时间内可能收到很多条蓝牙广播数据包，主机可以采用批量上传的方式：

- 在一个请求包内上传多少蓝牙广播数据包以及相关信息
- 最大请求包不要超过单个 UDP 的大小 (max=32个)
- 从收到广播包到上传给云服务器，不要超过 1 秒

** 数据格式 **

要上传的蓝牙广播数据用二进制表示, 单条广播信息格式为:

```
[ MAC:6Bytes ][ RSSI: 1Byte ][ LEN: 1Byte ][ PDU: nBytes ]
```

| 参数     | 长度(字节)| 类型           | 说明
| ---      | ---      | ---            | ---
| MAC      | 6        | 字节           | 蓝牙设备物理地址
| RSSI*    | 1        | 整数           | RSSI值 + 255
| LEN      | 1        | 整数           | PDU 总长度
| PDU      | n        | 字节           | 蓝牙广播 PDU 内容, 最长 31 字节

*: 注意因为 RSSI 的范围为 -255dB ~ 0dB, 所以这里这个值对应范围为 0 ~ 255.

当上传多个广播时简单拼接即可.

```
[MAC][RSSI][LEN][PDU]
[MAC][RSSI][LEN][PDU]
[MAC][RSSI][LEN][PDU]
[MAC][RSSI][LEN][PDU]
```

** 应答 **

- 2.01 表示上传成功
- 4.00 表示上传的数据格式不正确, 或未指定 mac 参数等
- 4.03 表示被禁止上传
- 4.15 表示上传的内容类型不是 application/octet-stream
- 5.00 表示服务器内部发生错误


** 示例 **

```sh
H -> S: POST 
  Header:  POST (T=CON) 
  Options: 
    Uri-Path: "push"
    Uri-Query: mac=A01122334455
    Content-Format: "application/octet-stream"
  Payload: [D6BE898E402160BF8AB9CDC50B094E6F726469635F48524D0319410302010607030D180F180A18EFA6F0...]

S -> H: Response 2.01
  Header: 2.01 (T=ACK)

```


## 注册

主机启动或重启后需向服务器注册，上传自己的身份信息，并获取服务器配置信息

由蓝牙主机发送给云服务器

** 请求 **

> register

请求类型为 POST

| 参数          | 必须  | 说明
| ---           | ---  | ---
| mac           | 是    | 网口的 MAC 地址
| version       | 是    | 主机的软件版本, 整数值，数值越大版本越新
| model         | 是    | 表示硬件的型号和版本, 如 "P1101-v3" 表示 T1101 型号的主机每三个硬件版本

** 应答 **

- 2.05 表示注册成功, 并返回参数列表
- 4.00 表示上传的数据格式不正确, 如缺少 mac 等必须的参数
- 4.01 表示注册认证失败, 可能是非法或未登记的蓝牙主机
- 5.00 表示服务器内部发生错误


应答消息体包含了当前服务器系统时间, 以及其他全局配置参数:

| 参数          | 必须  | 说明
| ---           | ---  | ---
| date          | 是   | 服务器的系统时间，自 1970-1-1 以来经过的秒, 主机可以用来校时
| collect_host  | 是   | 采集服务器的 IP 或域名
| collect_port  | 是   | 采集服务器的访问端口
| expired*      | 否   | 服务器指定的注册期满时间, 单位为秒
| heartbeat     | 否   | 服务器指定的心跳间隔时间, 单位为秒
| interval      | 否   | 服务器指定的上报间隔时间, 单位为秒

*: 蓝牙主机在注册后超过 expired 指定的时间之后必须重新注册, 并重新获取服务器返回的配置参数.

** 示例 **

```sh

H -> S: POST 
  Header:  POST (T=CON) 
  Options: Uri-Path: "register"
     Content-Format: "text/plain"
  Payload:
      
     mac=A01122334455
     version=3
     model=P1101-v3

S -> H: Response 2.05
  Header: 2.05 Content (T=ACK)
  Options: Content-Format: "text/plain"
  Payload: 

  collect_host=192.168.1.2
  collect_port=8902  
  date=12456095
  expired=3600
  heartbeat=60

```


## 心跳

主机定时向服务器发送表示自己在线

由蓝牙主机发送给云服务器

** 请求 **

由主机向服务器发送需求确认的空消息 (Confirmable Empty Message) 表示 PING 请求. 详情请看 RFC7252 第 4.3 节.

注意必须在 heartbeat 时间内向服务器发送心跳请求消息表明设备在线, 如果服务器超过 heartbeat 参数指定的时间未收到设备的心跳请求, 可以认为设备已离线

** 应答 **

- 总是返回一个 RESET 空消息

### 示例

```sh

H -> S: Code=0.00 Empty Message 
  Header: (T=CON)

S -> H: Code=0.00 Empty Message
  Header: (T=RESET)

```

## 参数设置命令

通过此接口可以查询和修改蓝牙主机的配置参数

### 查询

** 请求 **

> config

这个命令没有参数

** 应答 **

- 2.05 表示查询成功, 并返回当前设备的配置参数表
- 5.00 表示设备内部发生错误

具体有哪些参数请参考 "系统配置参数表" 一节

** 示例 **

```sh

S -> H: GET 
  Header:  GET (T=CON) 
  Options: Uri-Path: "config"

H -> S: Response 2.05
  Header: 2.05 Content (T=ACK)
  Options: Content-Format: "text/plain"
  Payload: 

  mac=AA1122334455
  version=3
  server_host=127.0.0.1
  server_port=1111

```


### 修改

** 请求 **

> config

请求类型为 POST

这个命令的参数为想要修改的参数名称和值

具体有哪些参数请参考 "系统配置参数表" 一节

** 应答 **

- 2.04 表示修改成功
- 4.00 表示上传的数据格式不正确, 未指定参数名称或值等
- 4.03 表示被禁止访问这个接口
- 4.15 表示上传的内容类型不是 application/plain
- 5.00 表示设备内部发生错误

** 示例 **

```sh

S -> H: POST 
  Header:  POST (T=CON) 
  Options: Uri-Path: "config"
     Content-Format: "text/plain"
  Payload: 
        
  expired=3600
  heartbeat=60

H -> S: Response 2.04
  Header: 2.04 (T=ACK)

```


## 控制命令

云服务器可以向主机发送控制命令

由云服务器发送给蓝牙主机

请求类型为 POST

### reboot

重启蓝牙主机

** 请求 **

> reboot

这个命令没有参数

** 应答 **

- 2.04 表示操作成功
- 4.03 表示被禁止访问这个接口
- 5.00 表示设备内部发生错误


蓝牙主机收到这个请求后将延时数秒之后再重启, 以便服务器能收到应答消息

** 示例 **

```sh

S -> H: POST 
  Header:  POST (T=CON) 
  Options: Uri-Path: "reboot"

H -> S: Response 2.04
  Header: 2.04 (T=ACK)

```


### upgrade

通知蓝牙主机立即更新固件

** 请求 **

> upgrade

这个命令没有参数

** 应答 **

- 2.04 表示操作成功
- 4.03 表示被禁止访问这个接口
- 5.00 表示设备内部发生错误

蓝牙主机收到这个请求后将切换到升级模式, 从服务器下载并更新固件.

注意: 蓝牙主机收到这个请求后需要延时数十秒之后再切换到升级模式并下载更新固件, 这个延时时间需要是随机的, 以免所有主机同时从服务器下载固件.


** 示例 **

```sh

S -> H: POST 
  Header:  POST (T=CON) 
  Options: Uri-Path: "upgrade"

H -> S: Response 2.04
  Header: 2.04 (T=ACK)

```


### 安全考虑

出于安全考虑, 蓝牙主机应当只接受来自服务器的远程控制请求


## 下载固件

主机向服务器下载最新的固件文件

由蓝牙主机发送请求给云服务器

因为固件文件比较大，需要用到 CoAP 的数据块传输方式, 请参考 RFC 7959.

** 请求 **

> firmware

| 参数          | 必须  | 说明
| ---           | ---  | ---
| mac           | 否    | 网口的 MAC 地址
| version       | 是    | 主机的软件版本, 整数值，数值越大版本越新
| model         | 是    | 表示硬件的型号和版本

服务器收到请求后, 将根据设备固件版本和硬件型号来决定如何分片发送以及发送哪个固件文件

** 应答 **

- 2.05 表示操作成功, 并分片下载
- 4.00 表示请求格式不正确, 如缺少 version 等必须的参数
- 4.04 表示没有找到和设备匹配的固件文件
- 5.00 表示服务器内部发生错误

分片返回固件文件内容

**蓝牙主机收到固件内容后, 应当验证是否是匹配的固件, 并且在固件升级中碰到断电,网络中断而升级失败不能使设备损坏无法使用, 应当可以在重启后重新进入升级模式, 直到升级成功为止**

** 示例 **

```sh

H -> S: GET 
  Header:  GET (T=CON) 
  Options: Uri-Path: "firmware"
          Uri-Query: mac=AA1122334455&version=3&model=P1101-v3

H -> S: Response 2.05
  Header: 2.05 Content (T=ACK)
  Options: 10:0/1/1024
  Payload: 

  [firmware data]

...

```

