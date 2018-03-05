# Node.lua

> - Author：ChengZhen
> - Version：3.2

Platform for Internet of Things with Lua.
Modern IoT device embedded software development platform.

> Node.lua is a framework for "Internet of Things" built on lightweight Lua interpreter and libuv for event driven (non-blocking I/O model) similar to node.js.

## 特色 -  Features

- 使用纯 C 语言实现，移植方便，性能优越，灵活小巧
- 使用成熟的 libuv, sqlite 等框架，成熟稳定
- 使用简洁易用的 Lua 做为应用开发语言
- 使用和 Node.js 一致的核心 API，上手容易
- 应用程序无需编译，直接运行，一键部署
- 提供常用的扩展库，并且容易自行扩展
- 专门针对嵌入式优化，运行速度快，占用空间少，集成功能多

- using pure C language, easy to transplant, superior performance, flexible and compact.
- using mature libuv, sqlite and other frameworks, mature and stable.
- use the simple and easy-to-use Lua as the application development language, using the core API consistent with node.js, easy to use.
- the application does not need to compile, run directly, and deploy one key.
- provides a complete built-in library and API, and is easy to extend.
- specific to embedded optimization, fast running speed, less space, more integration, compared to node.js requires very little memory space.

### 快速开发 - Rapid Development

提供全平台的 SDK，广泛支持 Windows，Linux，MacOS, iOS 等平台，不同的平台提供一样的应用程序运行环境，在 PC 开发的应用程序可以直接在开发板上运行.

Provide full platform SDK, broad support for Windows, Linux, MacOS, iOS platform, such as different platform provides the same application running environment, in the development of the PC application can run directly on the development board.

### 快速迭代 - Fast Iterative

使用动态语言开发嵌入式应用程序，可以将注意力集中在应用逻辑，快速响应急速变化的需求，实现更快的功能迭代。

Using dynamic languages to develop embedded applications, you can focus on application logic, quickly respond to rapidly changing requirements, and implement faster functional iterations.

## 简介

### 概述

- 提供一个主程序: lnode, 相当于 lua 程序解释器
- 提供一个命令行工具: lpm, 用于辅助开发和运行
- 支持 lua 扩展库格式插件功能
- 提供一个简单的 APP 应用程序框架

### 目录结构

| 目录       | 描述
| ---        | ---
| app        | 应用程序
| docs       | 项目开发文档，包含文档首页，样式表，js 脚本等资源文件等等。
| modules    | Lua 扩展库，主要包括 SSDP 等 Lua 实现的扩展库。
| node.lua   | 核心项目，包括 lnode 主程序, lpm 工具以及 Lua 核心库。

## 构建 - How to Build

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

Package the generated target file as the SDK.

```sh
# 打包 SDK 
$ make sdk

```

## SDK 安装 - Install SDK

### Windows 

解压 `nodelua-win-sdk.zip` 这个文件，并执行目录中的 install.bat.

安装后打开一个新的 cmd 窗口，执行 `lpm`, 如果打印出版本号等信息则表示安装成功.

### Linux and macOS

解压 `nodelua-xxxxx-sdk.zip` 这个文件，并执行目录中的 install.sh.

在命令行提示下执行 `lpm`, 如果打印出版本号等信息则表示安装成功

## 文档 - Documents

[更多详细的文档请访问下面的网址](tree/master/docs/index.md)

## License

Node.lua is Open Source software under the Apache 2.0 license. Complete license and copyright information can be found within the code.
