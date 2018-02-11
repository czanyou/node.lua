# Node.lua

> - 编写：成真
> - 版本：5.0

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
| modules    | Lua 扩展库，主要包括 SSDP 等 Lua 实现的扩展库。
| node.lua   | 核心项目，包括 lnode 主程序, lpm 工具以及 Lua 核心库。
| targets    | 编译平台配置文件

## 构建 - Build

Node.lua SDK 可以被编译到多个平台, 并只需要很少的依赖项:

Node.lua was designed to build seamlessly with minimal dependencies on most platforms:

- 所有平台 (For all platforms): CMake >= 2.8
- Windows: CMake, MSVC++
- MacOS: CMake, XCode
- Linux: CMake, Make, GCC

```sh
# 编译 C 语言源文件并生成主程序以及扩展模块 
$ make local

# 安装 Lua 语言运行环境
$ make install

```

## 打包 - Package

将生成的目标文件打包为 SDK.

```sh
# 打包 SDK 
$ make sdk

```

## 安装 - Install

### Windows 

解压 `nodelua-win-sdk.zip` 这个文件，并执行目录中的 install.bat.

安装后打开一个新的 cmd 窗口，执行 `lpm`, 如果打印出版本号等信息则表示安装成功.

### Linux and macOS

解压 `nodelua-xxxxx-sdk.zip` 这个文件，并执行目录中的 install.sh.

在命令行提示下执行 `lpm`, 如果打印出版本号等信息则表示安装成功

## 文档 - Documents

更多详细的文档请访问下面的网址:

[http://node.sae-sz.com/](http://node.sae-sz.com/)
