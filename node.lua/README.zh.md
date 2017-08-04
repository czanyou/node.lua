# Node.lua

> - 编写：成真
> - 版本：3.0

## 概述

A framework for Internet of Things

Node.lua 是一个和 Node.js 类似的 Lua 运行环境. 

Node.lua 的目的不是为了替代 Node.js, 而是为了在嵌入式设备等性能较低的硬件上也能使用类似 Node.js 的开发和运行环境.

相比 Node.js, Node.lua 对内存等要求更低, 运行更快，和 C/C++ 混合开发更容易, 并且还能提供协程, 多线程等实用的 API.

主要缺点是相对 Javascript, 使用 Lua 语言的人比较少, 但好在 Lua 和 Javascript 非常相似, 熟悉后开发起来差别不大.


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
- (luauv) 主要用于将 libuv 绑定到 Lua. 在 Lua 中可通过 require("uv") 调用
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


### libs: 第三方扩展库

- sqlite sqlite3 模块, 实现本地数据库操作
- mbedtls TLS 模块, 用于实现 TLS/HTTPS 协议


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

### 编译扩展库

修改 CMakeLists.txt 文件，设置 BUILD_MBED_TLS 和 BUILD_SQLITE 的值为 ON 或 OFF 即可选择是否编译 lmbedtls 和 lsqlite 库。

### Linux 下编译

直接在项目根目录执行 make 即可.

输出文件：

- build/local/lnode
- build/local/lmbedtls.so
- build/local/lsqlte.so

### MacOS 下编译

先安装 CMake 等.

安装 CMake 后可执行如下的命令安装 CMake 命令行工具.

    sudo mkdir -p /usr/local/bin
    sudo /Applications/CMake.app/Contents/bin/cmake-gui --install=/usr/local/bin

输出文件：

- build/macos/lnode

### Windows 下编译

先安装 cmake 和 visual studio, 然后运行 make.bat, 将成生成 build/win32 目录 

输出文件：

- bin/lnode.exe
- bin/lua53.dll
- bin/lmbedtls.dll
- bin/lsqlte.dll

### 交叉编译

交叉编译 hi3518，先在 Linux 下安装 cmake 和 hi3518 工具链，然后运行 make hi3518, 将成生成 build/hi3518 目录 

输出文件：

- build/hi3518/lnode
- build/hi3518/lmbedtls.so
- build/hi3518/lsqlte.so

#### 其他平台交叉编译办法:

修改 CMakeLists.txt 下面位置代码, 添加新的平台类型和工具链名称

```
# 交叉编译选项, 通过 BOARD_TYPE 参数确定编译工具链
MESSAGE(STATUS "Build: BOARD_TYPE=${BOARD_TYPE}  ")
if (BOARD_TYPE STREQUAL hi3518)
  MESSAGE(STATUS "Build: use arm-hisiv100nptl-linux-gcc")
  set(CMAKE_C_COMPILER "arm-hisiv100nptl-linux-gcc")
else (BOARD_TYPE STREQUAL hi3518)

endif (BOARD_TYPE STREQUAL hi3518)
```

修改 Makefile, 参考 hi3518 添加其他平台编译命令

```sh
hi3518:
#   交叉编译
    $(call cmake_build,$@)

```

其中 cmake_build

```sh
define cmake_build
    cmake -H. -Bbuild/$1 -DBOARD_TYPE=$1
    cmake --build build/$1 --config Release
endef
```

- build/$1 表示中间文件和目标文件生成目录 
- BOARD_TYPE=$1 表示CMakeLists中配置的平台类型

如果未指定将默认采用开发机的编译环境和工具


### 生成文件

最终将生成 lnode 可执行文件以及所需的动态链接库：

- Linux 下: `bin/lnode`.

- MacOS 下: `bin/lnode`.

- Windows 下: `bin/lnode.exe` 以及 `bin/lua53.dll`.



## Lua 开发和调试

本节主要描述在编译好 lnode 主程序后如何开发和调试 lua 脚本。


### Windows 下开发和调试

完成主程序构建之后可执行文件将复制到 `node.lua\bin\` 目录.

接着运行 `node.lua\install.bat`, 会将当前开发目录的 `node.lua\bin\` 和 `node.lua\lua\` 会注册到系统环境变量中.

打开一个新的 cmd 窗口，执行 `lpm`, 如果运行成功则表示安装正确.


### Linux 下开发和调试

安装内容主要有:

- 复制 lnode 主程序, 以及 lpm 等执行文件到系统目录, 并添加相应的执行权限.
- 要调用 lua 目录下的模块, 必须关联 lua 目录到 lnode 主程序的 Lua 模块搜索路径, 否则会提示找不到相关模块. 

完成主程序构建之后在当前目录下运行:

> make install

上述脚本将复制上面生成的可执行文件到系统目录并添加需要的环境变量

在系统命令行提示下执行: `lpm`, 如果有显示 lpm 的帮助信息, 则表示 Node.lua 开发环境安装成功


## 发布

node.lua 不能单独发布, 它只是 Node.lua 的核心项目，要发布完整的 Node.lua SDK 请参考 node.lua 上一级目录 `README.md`.













