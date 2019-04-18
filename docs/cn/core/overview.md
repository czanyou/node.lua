# Node.lua 核心 API

Node.lua 是一整套基于 lua/libuv 的动态开发环境和运行平台, 主要目的是简化嵌入式的开发, 但是因为 lua/libuv 极其良好的可移植性, 这一平台同时也可以用于 windows/linux 甚至 iOS/Android 平台的服务端软件或 APP 开发

核心库工程子目录为 /node/node.lua

包括了 node.lua 主程序 (lua + libuv + miniz + binding = lnode.exe) 和 lua 核心库

