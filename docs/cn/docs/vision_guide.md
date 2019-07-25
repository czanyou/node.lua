# 开发入门

## 准备开发环境

Node.lua 支持常见的 PC 操作系统 (包括 Windows, Linux, macOS 等系统), 可以在 PC 上直接开发, 编译和运行.

目前测试可用的系统有:

- Microsoft Windows 10
- Ubuntu 16.04+
- macOS 10.12+

## 准备开发板

Node.lua 也支持树莓派等常见的开发板, 可以在开发板上运行 Node.lua.

目前官方支持的开发板有:

- 树莓派 Raspberry Pi 2/3
- NanoPi NEO (Air)
- MT7688

## 下载源代码

请使用 `git` 等客户端工具下载所需的源代码

## 安装编译工具

### CMake

Node.lua 使用 CMake 做为主要编译工具

> https://cmake.org/

CMake 是一个跨平台的编译工具，可以用简单的语句来描述所有平台的编译过程。他能够输出各种各样的makefile 或者 project 文件，能测试编译器所支持的 C++ 特性, 类似 UNIX 下的 automake,CMake 的配置文件名为 `CMakeLists.txt`。

CMake 并不直接建构出最终的软件，而是产生标准的建构档（如 Unix 的 Makefile 或 Windows Visual C++ 的 projects/workspaces），然后再依一般的建构方式使用。这使得熟悉某个集成开发环境（IDE）的开发者可以用标准的方式建构他的软件，这种可以使用各平台的原生建构系统的能力是 CMake 和其他类似系统的区别之处。

### Windows 下安装

首先需要安装 MS Visual C++, 建议安装 2015 以上版本.

> https://visualstudio.microsoft.com


### Linux 下安装

Ubuntu 默认只需要安装 CMake 即可

```
$ sudo apt install -y cmake
```

## 编译

在项目目录下执行下面的命令来编译和安装开发环境

```shell

# 编译 C 代码, 生成 lnode 可执行文件
$ make build

# 安装开发环境, 包括 Node.lua 的可执行文件和目录
$ sudo make install

# 执行 lpm 命令, 检查安装是否成功
$ lpm

```

### 常用编译选项

- build

编译和构建 Node.lua 中的二进制可执行文件

- install

安装开发环境, 包括注册可执行文件, 链接 Lua 脚本目录

脚本会在系统 /usr/local 创建名为 lnode 的目录, 并在这个目录下创建相关的链接指向当前源代码路径

- remove

删除安装的开发环境, 主要是删除相关链接文件

- clean

清除所有构建文件

- sdk

将构建后的文件打包成 SDK 包

- load

使用默认的脚本配置项目

```
make load board=<BOARD_TYPE>
```

`BOARD_TYPE` 表示要设置的开发板名称, 可以修改 config.mk 为不同的开发板设置不同的编译选项.

- local

相当于执行: `make load board=local`

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

