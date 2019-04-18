# lnode 命令行工具

## 概述

lnode 是 Node.lua 的主程序, 是执行所有 Lua 脚本的命令, 并且内置了核心的 Node.lua 扩展库

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
