# README

硬件相关开发指南

## DT02

DT02 物联网关开发指南

### 串口线

- 绿: TX
- 白: RX
- 黑: GNG
- 波特率: 115200,8,N,1

### 启动参数

根据 DT02 具体硬件配置修改 uboot 启动参数

- Flash 总共 16MB
  - UBoot 1MB
  - 内核 1MB
  - 根文件系统 12MB
- 内存总共 64MB
  - 操作系统总共 48MB
  - MMZ 总共 16MB

```shell
$ setenv bootargs 'mem=48M console=ttyAMA0,115200 root=/dev/mtdblock2 rw rootfstype=jffs2 mtdparts=hi_sfc:1M(boot),3M(kernel),12M(rootfs)'
$ setenv bootcmd 'sf probe 0;sf read 0x82000000 0x100000 0x400000;bootm 0x82000000'
$ setenv slave_autostart 0
$ save
```

### 文件系统

添加 Node.lua 相关的系统初始化脚本

- /etc/init.d/S88lnode

安装 DHCP 客户端脚本

- /usr/share/udhcpc/default.script 

建议通过 `passwd` 命令修改 root 密码

#### inittab

::askfirst:-/bin/login

#### NFS

```shell
# 
$ mount -t nfs -o nolock 192.168.1.38:/mnt/nfs /mnt/nfs

```

### GPIO 工具

安装 himm GPIO 工具

> /bin/btools
> /bin/himm

himm 工具可以用来配置寄存器等

### 硬件看门狗

从 SDK 复制硬件看门狗所需要的驱动:

> sys_config.ko, hi_osal.ko, hi3516cv300_wdt.ko

```shell
# 加载 watchdog 驱动程序
insmod /ko/sys_config.ko
insmod /ko/hi_osal.ko mmz=anonymous,0,0x83000000,16M anony=1
insmod /ko/hi3516cv300_wdt.ko
```

成功后会出现如下的设备:

> /dev/watchdog

### 4G 拨号

添加 EC20 拨号脚本

> /etc/ppp/peers

更换 chat 程序

> /usr/bin/chat

更换 pppd 程序

> /usr/bin/pppd

电阻跳线至内置 USB

成功后，会出现如下的设备:

> /dev/ttyUSB0
> /dev/ttyUSB1
> /dev/ttyUSB2

## deploy

1、运行./deploy.sh

2、手动创建 /etc/resolv.conf 

写入dns 
nameserver 114.114.114.114
nameserver 192.168.8.1
