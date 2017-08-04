# Node.lua 开发者指南

[TOC]

如果你对开发 Node.lua 本身有兴趣，请你仔细阅读以下的文档：

现代的 IoT 设备嵌入式软件开发平台.

Modern IoT device embedded software development platform.

## 简介 - Introduction

Node.lua 是一个 Lua 运行时，专为 IoT 设备设计而开发。Node.lua 对硬件进行了抽象，
使用了基于事件驱动，异步 I/O 模型，使 IoT 设备嵌入式软件开发变得轻量而高效。

Node.lua is a Lua runtime designed for IoT device development. Node.lua on the hardware was abstract,
Using the event-driven, asynchronous I/O model, so IoT device embedded software development becomes lightweight and efficient.

### 特色 -  Features

- 使用纯 C 语言实现，移植方便，性能优越，灵活小巧
- 使用成熟的 libuv, sqlite 等框架，成熟稳定
- 使用简洁易用的 Lua 做为应用开发语言，使用和 Node.js 一致的核心 API，上手容易
- 应用程序无需编译，直接运行，一键部署
- 提供完善的内置库和 API，并且容易扩展
- 专门针对嵌入式优化，运行速度快，占用空间少，集成功能多

#### 快速开发 - Rapid Development

提供全平台的 SDK，广泛支持 Windows，Linux，MacOS, iOS 等平台，不同的平台提供一样的应用程序运行环境，在 PC 开发的应用程序可以直接在开发板上运行.

#### 快速迭代 - Fast Iterative

使用动态语言开发嵌入式应用程序，可以将注意力集中在应用逻辑，快速响应急速变化的需求，实现更快的功能迭代。

#### 广泛支持 - Wide Support

支持常用的 I/O 接口和简洁易用的 API，可以支持各种传感器和外围器件，激发无限的创造力。

#### 像软件一样开发硬件 - Develop hardware like software

提供和 Node.js 极度类似的 API 接口，无需太多的学习，使 WEB 工程师也能轻松开发智能硬件


## 目录结构

| 目录       | 描述
| ---        | ---
| app        | 应用程序
| docs       | 项目开发文档，包含文档首页，样式表，js 脚本等资源文件等等。
| media.lua  | C 扩展库, 主要媒体抽象层, GPIO 等 C 语言实现的扩展接库。
| node.lua   | 核心项目，包括 lnode 主程序, lpm 工具以及 Lua 核心库。
| vision.lua | Lua 扩展库，主要包括 RTSP, SSDP 等 Lua 实现的扩展库。


## 构建 - Build

如果只需要开发应用程序，则只需下载相应的 SDK 安装包即可。

如果要自己构建和编译 SDK 项目，则需要下载并编译 SDK 源代码.

Node.lua SDK 可以被编译到多个平台, 并只需要很少的依赖项:

Node.lua was designed to build seamlessly with minimal dependencies on most platforms:

- 所有平台 (For all platforms): CMake >= 2.8
- Windows: CMake, MSVC++
- MacOS: CMake, XCode
- Linux: CMake, Make, GCC

### Windows，Linux and macOS PC platform

```sh
# 编译主程序以及扩展模块 
$ make local  

# 安装 Node.lua 开发和运行环境
$ make install

```

### 交叉编译

交叉编译之前需先按前一节编译和安装本地的 SDK

构建项目还需要相关交叉编译工具链，构建前请先安装。

在命令行下运行 `make <target>` 即可, target 表示目标板的名称

当前支持的目标板有：

- hi3518
- hi3516a
- mt7688

## 打包 - Package

将生成的目标文件发布为 SDK 包, 并可以安装到其他机器上运行.

```sh
# 打包 SDK 
$ make sdk

```


## 安装 - Install

### Windows 

复制 `nodelua-win-sdk.zip` 这个文件到其他电脑上，解压并执行目录中的 install.bat 即可安装.

安装后打开一个新的 cmd 窗口，执行 `lpm`, 如果运行成功且打印出版本号则表示安装正确.

### Linux and macOS

复制 `nodelua-xxxxx-sdk.zip` 这个文件到其他电脑上，解压并执行目录中的 install.sh 即可安装.

在系统命令行提示下执行 `lpm`, 如果运行成功且打印出版本号则表示安装正确

## 文档 - Documents

更多详细的文档请访问下面的网址:

[http://node.sae-sz.com/](http://node.sae-sz.com/)


## 常见问题解答 - FAQ

### 为什么不直接使用 Node.js - Why not use Node.js directly

Node.js 安装包非常大，在 20M 以上，不适合在较小的 SPI Flash 系统上运行. 很多嵌入式平台 Flash 总共都不超过 8M.

Node.js 在嵌入式平台上加载速度比较慢.

### 为什么不使用 Python - Why not use Python

Python 的核心库也比较大，而且 Python 运行效率也不太理想。

### 为什么使用 Lua 语言 - Why use Lua language

Lua 的虚拟机和核心库都非常小，所以特别适合嵌入式系统使用，对系统要求非常低。

Lua 特别容易集成到 C/C++ 程序中, 用 C 开发扩展库也非常容易。

Lua 语法和 JavaScript 很类似，很适合做为 JavaScript 在嵌入式下的替代语言。



