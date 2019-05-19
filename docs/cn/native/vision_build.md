# 构建指南

## 目录

- bin       可执行文件
- build     CMake 临时构建目录
- deps      主程序依赖的 C 模块
- docs      文档
- libs      第三方扩展模块, 可根据需求选择是否编译
- lua       Lua 核心库源代码
- src       lnode 主程序 C 语言源代码
- tests     测试用例

### 根目录文件

- CMakeLists.txt CMake 配置文件
- install.bat   Windows 下运行 install.lua 的批处理文件
- install.lua   Windows 下开发和运行环境安装脚本
- make.bat      Windows 下运行 CMake 的批处理文件
- Makefile      非 Windows 下 Makefile
- README.md     本说明文件

### bin: 可执行文件

- lpm           Lua Package Manager 主执行程序
- lpm.bat       在 Windows 下执行 lpm 的批处理文件

### deps: 依赖项目

Node.lua 主程序由 C 语言实现, 并且包含了 lua, libuv, miniz 等核心库:

- (libuv) libuv 1.11 以上
- (lua) PUC lua 5.3 以上
- (luajson) cjson JSON 编解码器, 在 Lua 中可通过 require("cjson") 调用
- (luautils) 实现 buffer, hex, http parser, md5 等功能, 在 Lua 中可通过 require("lutils") 调用
- (luauv) 主要用于将 libuv 绑定到 Lua. 在 Lua 中可通过 require('luv') 调用
- (luazip) miniz ZIP 压缩解压库, 在 Lua 中可通过 require("miniz") 调用

相关依赖库源代码下载地址：

- http://www.lua.org/ftp/
- https://github.com/libuv/libuv
- https://github.com/richgel999/miniz
- https://github.com/mpx/lua-cjson
- https://github.com/luvit/luv

注意: 因为 lua 5.3 和 luajit 2 差别较大, 暂时不提供对 luajit 2 的支持.

### docs: 文档

API 说明文档

### lua: Lua 核心库

node.lua 核心库，主要实现了和 node.js 相似的核心库，调用方法同样可以参考 node.js 的文档

### src: lnode 主程序

lnode 主程序入口函数代码

### tests: 测试用例

用于单元测试

## 构建主程序

### 概述

本节主要描述在下载到源代码到本地后如何对其进行开发和编译

主程序源代码主要由 C 语言组成, 源文件目录为 `/src/`, 主函数所在文件是 `/src/main.c`, 其他模块都位于 `/deps/` 目录下. 

主要采用 CMake 实现跨平台构建和编译代码, 编译前需先安装 CMake 相关软件

### Linux 下编译

先安装 CMake, gcc 和 Make 等, 然后直接在项目根目录执行 make 即可.

### MacOS 下编译

先安装 CMake 等.

安装 CMake 后可执行如下的命令安装 CMake 命令行工具.

    sudo mkdir -p /usr/local/bin
    sudo /Applications/CMake.app/Contents/bin/cmake-gui --install=/usr/local/bin

### Windows 下编译

先安装 CMake 和 Visual Studio C++, 然后运行 make.bat


## Lua 开发和调试

编译完成之后需要安装相关的 Lua 运行程序到操作系统才能执行 Lua 文件。

本节主要描述在编译好 lnode 主程序后如何开发和调试 lua 脚本。

### Windows 下开发和调试

完成主程序构建之后可执行文件将复制到 `node.lua\bin\` 目录.

接着运行 `node.lua\install.bat`, 会将当前开发目录的 `node.lua\bin\` 和 `node.lua\lua\` 会注册到系统环境变量中.

打开一个新的 cmd 窗口，执行 `lpm`, 如果运行成功则表示安装正确.

### Linux 下开发和调试

完成主程序构建之后在当前目录下运行:

> make install

安装内容主要有:

- 复制 lnode 主程序, 以及 lpm 等执行文件到系统目录, 并添加相应的执行权限.
- 关联 lua 目录到 lnode 主程序的 Lua 模块搜索路径, 否则会提示找不到相关模块. 

安装完成后在系统命令行提示下执行: `lpm`, 如果有显示 lpm 的帮助信息, 则表示 Node.lua 开发环境安装成功
