# Node.lua 核心 API

[TOC]

Node.lua 是一整套基于 lua/libuv 的动态开发环境和运行平台, 主要目的是简化嵌入式的开发, 但是因为 lua/libuv 极其良好的可移植性, 这一平台同时也可以用于 windows/linux 甚至 iOS/Android 平台的服务端软件或 APP 开发

核心库工程子目录为 /node/node.lua

包括了 node.lua 主程序 (lua + libuv + miniz + binding = lnode.exe) 和 lua 核心库

## lnode 运行参数

使用方式: `lnode [options] [ -e script | script.lua [arguments]]`

- `-d` 以后台模式 (daemon) 运行 
- `-e` 执行脚本字符串, 在这个参数后须指定要执行的脚本字符串内容
- `-l` 显示 Node.lua 根目录, package.path, package.cpath 等运行参数
- `-p` 执行脚本字符串并打印出执行结果
- `-r` 加载指定名称的模块
- `-v` 显示版本信息
- `-`  执行通过 stdin 输入的脚本字符串

### 示例

运行当前目录下的 test.lua 文件:

`$ lnode test.lua`

运行 lua 字符串:

`$ lnode -e "print('hello')"`

运行 Lua 字符串并打印执行结果:

`$ lnode -p "2 * 3 + 1"`








