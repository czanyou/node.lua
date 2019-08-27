# Node.lua 核心 API

## 概述

Node.lua 是一整套基于 lua/libuv 的动态开发环境和运行平台, 主要目的是简化嵌入式的开发, 但是因为 lua/libuv 极其良好的可移植性, 这一平台同时也可以用于 windows/linux 甚至 iOS/Android 平台的服务端软件或 APP 开发

核心库工程子目录为 /node/node.lua

包括了 node.lua 主程序 (lua + libuv + miniz + binding = lnode.exe) 和 lua 核心库

## 核心库

- [Assert - 断言](node_assert.md)
- [Buffer - 缓存区](node_buffer.md)
- [Child Process - 子进程](node_child_process.md)
- [Core - 核心库](node_core.md)
- [Console - 控制台](node_console.md)
- [Global - 全局对象](node_global.md)
- [DNS - 域名解析](node_dns.md)
- [File System - 文件系统](node_fs.md)
- [HTTP - 超文本传输协议](node_http.md)
- [JSON - JavaScript 对象表示](node_json.md)
- [Math - 数学计算](node_math.md)
- [Network - 网络](node_net.md)
- [OS - 操作系统](node_os.md)
- [Path - 路径](node_path.md)
- [Process - 进程](node_process.md)
- [Query String - 查询字符串](node_querystring.md)
- [Request - HTTP 请求](node_http_request.md)
- [Stream - 流](node_stream.md)
- [String - 字符串](node_string.md)
- [Tap - 单元测试工具](node_ext_tap.md)
- [Thread - 线程](node_thread.md)
- [Timer - 定时器](node_timer.md)
- [UDP - 数据报](node_dgram.md)
- [URL - 统一资源定位地址](node_url.md)
- [Util - 工具](node_util.md)
