# Hi3516A 开发指南

[TOC]

## 名词解析

- VI        视频输入 
- AI        音频输入 
- VPSS      视频预处理
- VENC      视频编码
- VDEC      视频解码
- VO        视频输出
- VDA       视频侦测分析
- AO        音频输出
- AENC      音频编码
- REGION    区域管理

### 准备工作

- hi3516a 开发板一块
- USB 转 ttl 模块一块
- TTL 转接线
- DC 12V 电源
- 网线一根
- 路由器或交换机一台(可选)
- Ubuntu 32/64位虚拟 PC 机 (可选物理机, 其他 Linux 开发会略有差异)
- Windows 版 Shell 终端软件 (推荐 XShell)
- Windows FTP 客户端软件 (可选, 推荐 FileZilla Client)
- Hi3516a SDK v1.0.5 (编写此文档时最新版本, 如果只用于开发应用程序可只下载编译工具和 mpp 包)

### 网络配置

下面的配置仅供参考, 请根据自己的条件配:

- 路由器地址为 192.168.77.1, 可以上外网
- 开发用的 Ubuntu 绑定 IP 为 192.168.77.108, (这里用的是物理机, 使用固件 IP 是为开发方便)
- Windows 机器 IP 地址自动分配
- 开发机和开发板通过网线连接到同一路由器

### 搭建开发环境

这里创建了一个 `/system/main` 作为项目的主目录, 也可以放在其他目录，为了开发方便不建议放在太深的目录。

```sh

# 安装 arm-hisiv300-linux 交叉编译工具。
$ ... 可以从海思的 SDK 中找到交叉编译工具。

# 安装 SVN,CMake 等开发工具:
$ sudo apt install -y subversion cmake

# 创建工程目录 (可以选择其他目录):
$ sudo mkdir -p /system/main
$ sudo chmod 777 /system/main

# 下载源代码
$ svn checkout svn:10.10.2.158/iot/node /system/main

# 编译本地代码并安装生成的命令行工具
$ cd /system/main
$ make local 
$ make install

# 编译目标板代码并生成 SDK 包
$ cd /system/main
$ make hi3516a
$ make sdk

```

#### 查看依赖的共享库文件

交叉编译方式下查看依赖的共享库文件:

```lua
arm-hisiv300-linux-readelf build/hi3516a/bin/lmedia.so -d
```

在 linux 下可使用 ldd 查看依赖的共享库文件


#### 配置 NFS

通过 NFS 服务能更方便地共享文件而不必反复上传下载, 非常利于程序的调试.

首先在开发用的 Linux 服务器上安装和配置 NFS 服务端:

安装相关组件 (以 Ubuntu 为例):

```sh
$ sudo apt install -y nfs-kernel-server
```

编辑 NFS 相关配置文件:

```sh
$ sudo nano /etc/exports
```

配置文件内容如下:

```sh
/system *(rw,sync,no_root_squash,no_subtree_check)
```

最后重启相关的服务让配置生效:

```sh
$ sudo /etc/init.d/rpcbind restart 
$ sudo /etc/init.d/nfs-kernel-server restart 
```

查看当前导出的文件系统

```sh
$ sudo exportfs
```

在开发板上可如下方式挂接服务器共享的 NFS 目录:

```sh
$ mount -t nfs -o nolock 192.168.77.125:/system/main/node /nfsroot
```

## 初始化开发环境

打包时不会打包此文件, 需在开发前复制此文件到开发目录 `/build/hi3516a/` 目录下

这个脚本只在开发板通过 nfs 挂接了服务器项目目录后执行
用来将开发项目目录添加到系统 PATH 目录中, 以便在线开发和调试

将 /nfsroot/build/hi3516a/bin 目录添加到 PATH 目录
在开发机上项目根目录执行 `make hi3516a` 可以生成此目录 

```sh

$ export PATH=/nfsroot/build/hi3516a/bin:/usr/bin:/usr/sbin:/bin:/sbin

```


### MAC

```sh
$ ifconfig eth0 hw ether 00:0C:18:EF:FF:ED
```

## media.lua/targets/hi3516a/ 目录下文件说明

- bin/init.sh Shell 脚本, 安装到目标板 `/usr/local/lnode/bin`, 在操作系统启动时被调用.
- conf/lpm.cof 参数配置文件, 安装到目标板 `/usr/local/lnode/conf`, lpm 的配置文件.
- include 海思 mpp 库的头文件，在编译时需要
- ko 海思 mpp 库 linux 内核模块，在运行时需要，请复制到开发板 /ko 目录下
- lib/libmpp.so 海思 mpp 库动态/静态库模块，在编译时/运行时都需要
- lib/static_to_dylib.sh 因为 mpp 库模块很多，这个脚本用于将所有静态库打包成一个单一的动态库
- src 音视频采集模块源代码
- install.sh Shell 脚本, 随 SDK 一起打包, 但只在安装时使用, 用于将 SDK 文件安装到目标板文件系统.
- package.json 元数据文件
- S88debug Shell 脚本, 只在开发阶段使用, 不随 SDK 一起打包, 安装到 `/etc/init.d/`, 在操作系统启动时被调用. 这个脚本启动了多个方便调度开发的服务.
- S89node Shell 脚本, 在发布阶段使用，不随 SDK 一起打包, 安装到 `/etc/init.d/`, 在操作系统启动时被调用. 这个脚本启动了基本的服务，但不会开启和调试有关的服务.
- sml.cmake 编译脚本

## 首次安装说明

假设是 HI3516a + imx178 的开发板, 已经烧录了 SDK 中自带的 u-boot, 内核以及根文件系统.

### 安装 Hi3516a SDK

根文件系统默认没有安装多媒体处理系统相关文件, 请按以下方法安装:

```sh
# 给开发板插上网线和 TTL 线，并上电

# 配置 IP 地址 (假设当前用的是 192.168.77.x 网段)
$ ifconfig eth0 192.168.77.113

# 测试网络 (假设开发服务器地址为 192.168.77.108, 如果超时请检查服务器 IP 以及网络连接等)
$ ping 192.168.77.108

# 挂接 nfs 网络文件系统：(假设开发服务器项目目录为 /system/main/node)
$ mount -t nfs -o nolock 192.168.77.108:/system/main/node /nfsroot

# 查询挂接状态：(此时应能列出服务器上 /system/main/node 目录下的文件)
$ ls /nfsroot

# 复制 HI3516a SDK 的 mpp 包中的 ko 目录到目标板根目录下: 
# 这里的文件是摄像机视频采集等核心驱动模块
$ cp -rf /nfsroot/media.lua/targets/hi3516a/ko /ko
$ chmod -R 777 /ko

# 复制目标目录 lib 目录下面的 libmpp.so 文件到目标板的 `/usr/lib` 目录下
# libmpp.so 不是 SDK 自带, 而是由 SDK 中所有 .a 的静态库打包而来的, 合并为一个文件主要是为了管理方便
$ cp -rf /nfsroot/media.lua/targets/hi3516a/lib/libmpp.so /usr/lib/

# 复制目标目录 S88debug 到 `/etc/init.d` 目录下并添加可执行权限: 
# 这个文件主要是初始化开发板调试环境
$ cp -rf /nfsroot/media.lua/targets/hi3516a/S88debug /etc/init.d/
$ chmod 777 /etc/init.d/S88debug

```

**重启开发板让配置生效!**

### 安装 Node.lua 开发环境

主要是方便通过 nfs 方式开发和调试

```sh

# 链接开发目录或文件到开发板
# 可以将这段代码添加到 /etc/profile 文件中，这样开机的时候，就可以使用 lpm 
$ export PATH=/nfsroot/build/hi3516a/bin:/usr/bin:/usr/sbin:/bin:/sbin

# 运行 lpm, 看到帮助信息则表示 Node.lua 安装成功:
$ lpm list

```

### 安装 Node.lua 

将 Node.lua SDK 所有文件都安装到开发板上, 主要用于运行, 不用于开发.

```sh
# 安装 Node.lua: (这是先前编译 Node.lua 时生成的 Node.lua SDK)
$ /nfsroot/bin/nodelua-hi3516a-sdk/install.sh

# 运行 lpm, 看到帮助信息则表示 Node.lua 安装成功:
$ lpm

```

## 测试

### 配置网络

配置静态 IP 地址:

```sh

# 设置固定 IP 地址为 192.168.77.113
lpm set eth.mode static
lpm set eth.ip 192.168.77.113
lpm set eth.netmask 255.255.255.0
lpm set eth.gateway 192.168.77.1
lpm set eth.dns "192.168.77.1 8.8.4.4"

# 立即应用上述设置
lpm netd update

```

配置动态 IP 地址模式:

```sh

# 设置通过 DHCP 自动获取 IP 地址
lpm set eth.mode dhcp

# 启动网络后台守护程序并启动 DHCP 客户端
lpm start netd 

```

### 启动 SSDP 服务器

在后台运行 SSDP 服务, 在开发 PC 上可以通过 `lpm scan` 即可找到这台设备, 在手机上也可以自动发现 

```sh
lpm start ssdp 
```

### 启动嵌入式 WEB 服务

在后台运行 WEB 服务, 在 PC 上可以通过 `http://192.168.77.113/` 即可访问.

默认登录密码是 `888888`, 在后台可以查看 APP 信息, 以及设置设备参数等

```sh
lpm start httpd
```

### 视频采集测试

更多详情可以参考 camera.app 应用使用说明

#### 测试视频抓拍:

下面的脚本可以在 /tmp 下, 每隔 10 秒抓拍一张图片

```
$ cd /tmp
$ lpm camera snapshot 1

```

如果抓拍成功会打印如下信息：

```
/tmp # lpm camera snapshot 1
set lvds phy attr successful!
linear mode
-------Sony IMX178 Sensor 1080p60fps Initial OK!-------
Snapshoting...
0967#VideoEncodeOpen: ch=1, type=1, size=(960x540) (media_video:217)
0967#VideoEncodeOpenJpeg: ret=0, size=960x540 (media_video:197)
Saved: snaphost_19700118_082244.jpg (size:27475)
```

#### 测试视频录像:

下面的脚本可以在 /tmp 下, 录制一段长 10 秒的视频

```
$ cd /tmp
$ lpm camera record 1 test.ts 10
```

如果录制成功会打印如下信息：

```
/tmp # lpm camera record 1 test.ts 10
set lvds phy attr successful!
linear mode
-------Sony IMX178 Sensor 1080p60fps Initial OK!-------
test.ts
0055#VideoEncodeOpen: ch=0, type=0, size=(960x540) (media_video:217)
0055#VideoEncodeOpenH264: 0 (960x540) (media_video:149)
total bytes: 0
total bytes: 52264
total bytes: 116560
total bytes: 363404
total bytes: 488988
total bytes: 642396
total bytes: 783584
total bytes: 948272
total bytes: 1068216
```

并且在当前目录下生成 test.ts 文件

#### 测试视频直播:

可以在 PC 上用 VLC 打开 `rtsp://192.168.77.113:554/live.mp4` 打开网络串流来查看视频直播 

```
$ cd /tmp
$ lpm camera rtsp 554
```

如果运行成功则显示如下

```
/tmp # lpm camera rtsp 554
set lvds phy attr successful!
linear mode
-------Sony IMX178 Sensor 1080p60fps Initial OK!-------
0148#VideoEncodeOpen: ch=0, type=0, size=(960x540) (media_video:217)
0148#VideoEncodeOpenH264: 0 (960x540) (media_video:149)
RTSP server listening at (554) ...
  use rtsp://localhost:554/live.mp4 to view video streaming.
+--------+------------+------------+--------+------------+
| index  | ts         | bitrate    | fps    | interval   | 
+--------+------------+------------+--------+------------+
| 1      | 3.334      | 116026     | 30     | 3330       | 
| 2      | 6.668      | 133951     | 30     | 3340       | 
```

可以在 PC 上用 VLC 打开 'rtsp://l192.168.77.113:554/live.mp4'


#### 测试 HTTP 视频直播:

可以在 PC 上用 VLC 打开 `http://192.168.77.113:554/live/live.m3u8` 打开网络串流来查看视频直播 

```
$ cd /tmp
$ lpm camera hls
```



#### 设置参数

```sh
- camera.main.bitrate   [default: 1024]
- camera.main.width     [default: 640]
- camera.main.heigh     [default: 360]
- camera.main.framerate [default: 25]
```


#### 后台运行

通过下面的命令可以让摄像机应用一直在后台运行，提供抓拍，RTSP 等服务。

```
$ lpm start camera
```


## 注意事项

目前 Node.lua 不兼容 hi3516a 在线模式, 必须用离线模式加载内核驱动:

    ./load3516a -a -sensor imx178 -osmem 64 -offline

## 辅助开发工具

### 板载 FTP

对于内置了 busybox 的开发板板载 FTP 启动方式:

```sh
$ tcpsvd 0 21 ftpd -w / &
```

启动一个匿名 FTP 服务器, 使用开源的 FileZilla 客户端就可以很方便在开发板上上传和下载文件了.

### 板载 tmpfs

    # mount -t tmpfs none /tmp -o size=3m

## Sensor 开发

在目标板上测试能过 I2C 读取 IMX178 寄存器的值:

    i2c_read 0x0 0x34 0x3000 0x302d 2 1 1
