# Media.lua 简单系统媒体层 (SML: Simple system media layer) C 语言扩展库

> - 编写：成真
> - 版本：2.0

## 概述

本项目主要包含了 Node.lua 和操作系统或开发板相关媒体层的 C 语言扩展库.

本项目将生成 `lmedia.so` 等 Lua 扩展库格式的动态链接库文件, 可以在 Lua 语言中通过 `local lmedia = require('lmedia')` 等方法引入和使用。

lmedia 主要封装了外围硬件访问接口以及媒体层等，并提供相应 Lua API 接口。

本项目主要使用 CMake 构建系统, 请先安装相关的开发工具.

## 目录说明

- build    CMake 临时构建目录 
- src      平台通用的 C 语言源代码
- targets  和目标板有关的代码和配置文件等
- tests    测试用例

### 目标板目录简介

- targets/hi3516a hi3516a 开发板适配库
- targets/hi3518 hi3518 开发板适配库
- targets/mock 模拟测试库
- targets/linux UVC 摄像头适配库

更多信息请参考 targets/README.md 

## 构建方法

### Windows:  

Windows 下可直接运行 make.bat 编译当前项目。编译成功能会自动复制一份 lmedia.dll 动态库到 `node/node.lua/bin/` 目录下。

目前 Windows 平台暂时还不能开发如 USB Camera, Bluetooth，声卡等功能

### Linux:

在当前目录下运行 `make local` 来编译当前项目。

#### 安装依赖的系统库

如果需要用到 ALSA 模块，需先安装相应的开发包:

```
sudo apt install -y libasound2-dev
```


如果需要用到蓝牙模块，需先安装相应的开发包:

```
sudo apt install -y libbluetooth-dev
```


如果需要用到 USB 摄像头模块且需要 JPEG 压缩，需先安装相应的开发包:

```
sudo apt install -y libjpeg-dev
```

### 交叉编译

在当前目录下运行 `make <开发板名称>` 来编译当前项目 (仅限于已配置和支持的开发板)。

下载或自行提供需要的库，如 hi3516a：

http://node.sae-sz.com/download/?dir=dist/hi3516a/libs/

请先从上述的地址下载相应版本的 libmpp.so 文件到 media.lua/targets/hi3516a/lib/ 目录下.

如编译 Hi3516a 目标板文件:
 
    $ make hi3516a <回车>

## 操作系统动态库差异

因为本子项目生成的是动态库，而 Windows, Linux 和 macOS 对动态库的支持差别极大，
所以不同的操作系统平台将采用完全不同的文件依赖模式：

### Windows:  

Windows 下 Lua 虚拟机必须编译为动态模块. 如果将 Lua 编译为静态库并只生成单一执行文件则无法实现动态加载模块插件, 因 lmedia.dll 也要依赖于 Lua，这样将无法实现动态加载 lmedia 模块。

所以我们会生成下面 3 个二进制文件，其中 lmedia 是可动态加载的。

lnode.exe => lmedia.dll => lua53.dll

这 3 个文件都统一放置在 `/<base>/node/bin` 目录下.

### Linux

Linux 没有同 Windows 一样的限制，可以只编译一个单一可执行文件 lnode. 而且 lmedia 可编译成模块且可以动态加载。

lmedia.so 应放置在 `/<base>/node/bin` 目录下，不要放到系统 lib 目录下

### Hi3518/Hi3516a...

海思开发板基本同 Linux, 但是使用视频采集等功能需要调用海思 SDK，所以需要添加对 mpi, isp 等海思 SDK 动态库的链接。

lmedia => libmpp.so

lmedia.so 应放置在 `/<base>/node/bin` 目录下，不要放到系统 lib 目录下

### macOS

MacOS 下为了方便, 将只生成一个单一的可执行文件.

