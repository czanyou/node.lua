# Node.lua 开发文档

[TOC]

## Lua 语言参考

Node.lua 选用 Lua 作为上层应用开发语言, 可以访问下面的地址查看 Lua 语言官方手册:

[Lua 语言参考手册](lua/contents.html#index) 。

## Node.lua 简介

Node.lua 是一个和 Node.js 类似的 Lua 运行环境. 

Node.lua 的目的不是为了替代 Node.js, 而是为了在嵌入式设备等性能较低的硬件上也能使用类似 Node.js 的开发和运行环境.

相比 Node.js, Node.lua 对内存等要求更低, 运行更快，和 C/C++ 混合开发更容易, 并且还能提供协程, 多线程等实用的 API.

主要问题是相对 Javascript, 使用 Lua 语言的人比较少, 但好在 Lua 和 Javascript 非常相似, 熟悉后开发起来差别不大.


## 设计目的

- 能在嵌入式环境使用脚本语言快速开发
- 能方便和 C/C++ 混合开发, Lua 主要实现胶水功能, 模块用 C/C++ 实现
- 占用 Flash 特别小 (很多嵌入式系统只有 4 到 16 MBytes)
- 占用 CPU 要少, 启动速度要快
- 跨平台, 在 Windows, Linux, macOS 上都提供一致的脚本开发环境, 这样可以在 PC 开发和调试脚本, 无需修改即可部署到开发板上.
- 提供和 Node.js 一样的 API 和模块


