# 开发入门

[TOC]

## 准备开发环境

Node.lua 支持常见的 PC 操作系统 (包括 Windows, Linux, macOS 等系统), 可以在 PC 上直接开发, 编译和运行.

目前测试可用的系统有:

- Microsoft Windows 7/10
- Ubuntu 16.04
- macOS 10.12

## 准备开发板

Node.lua 也支持树莓派等常见的开发板, 可以在开发板上运行 Node.lua.

目前官方支持的开发板有:

- 树莓派 Raspberry Pi 2/3
- NanoPi NEO (Air)
- Hi3516a
- Hi3518a
- MT7688

## 下载 SDK

请在 **SDK 下载** 页面下载所需的 SDK 。

## 安装 SDK

SDK 需要安装并配置相关环境变量才能工作。

SDK 下包含了 `lnode` 和 `lpm` 两个可执行文件，`lnode` 是 Lua 虚拟机运行时主程序，
lpm 为包管理工具。


### Windows 下安装

假设我们想安装最新开发版的 SDK

下载 http://node.sae-sz.com/download/dist/win/nodelua-win-sdk.dev.zip 

解压到指定的目录, 比如:

`D:\nodelua-win-sdk\`

双击运行 `D:\nodelua-win-sdk\install.bat` 即可自动配置相关环境变量

安装之后打开一个新的命令行并执行 `lpm` 验证配置是否成功。


### Linux 下安装

假设我们想安装最新开发版的 SDK 在 `/usr/local/lnode` 目录下

```sh
$ cd /tmp
$ wget http://node.sae-sz.com/download/dist/linux/nodelua-linux-sdk.dev.zip
$ upzip nodelua-linux-sdk.zip -d node
$ cd /tmp/node
$ chmod 777 install.sh
$ ./install.sh

```

安装之后在命令行下执行 `lpm` 验证配置是否成功。


## 编写脚本

在任意目录下生成一个新的文本文件: `test.lua`

编辑 `test.lua`，输入测试代码:

```lua
print('Hello Node.lua')

```

在当前目录命令行下执行

```sh
lnode test.lua
```

命令行就会打印出:

```sh
Hello Node.lua
```

