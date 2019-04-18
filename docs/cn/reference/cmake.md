# CMake

## 概述

CMake是一个跨平台的安装（编译）工具，可以用简单的语句来描述所有平台的安装(编译过程)。

### 优势

CMake 是一个比 make 更高级的编译配置工具，它可以根据不同平台、不同的编译器，生成相应的Makefile 或者 vcproj 项目。通过编写 CMakeLists.txt，可以控制生成的 Makefile，从而控制编译过程。CMake 自动生成的 Makefile 不仅可以通过 make 命令构建项目生成目标文件，还支持安装（make install）、测试安装的程序是否能正确执行（make test，或者 ctest）、生成当前平台的安装包（make package）、生成源码包（make package_source）、产生 Dashboard 显示数据并上传等高级功能，只要在 CMakeLists.txt 中简单配置，就可以完成很多复杂的功能，包括写测试用例。如果有嵌套目录，子目录下可以有自己的 CMakeLists.txt。

## 安装

> https://cmake.org/download/

在 Ubuntu 下面安装:

> sudo apt install cmake -y

## 基本使用和语法

- cmake 由指令、注释和空白字符组成
- 以 `#` 开头，到行末尾的是注释
- 形如指令(参数1 参数2 参数3 ...)的是指令，参数间使用空格或者分号`;`隔开
- 指令不区分大小写，但参数是区分大小写的
- cmake 中可以设置变量，变量的引用方式为 `${变量名}`
- cmake 的构建指令为 "cmake path [参数选项]"；当前我们都使用的是“cmake .”，表示构建当前目录下的项目

基本语法:

> command (args ...)

command 是命令名，大小写无关（注意: 变量是大小写相关的）

args 是参数，参数如果有空格，应该用双引号括起来

变量:

变量引用用 ${VAR} 语法

获取系统环境变量方法:

> $ENV{VAR}

最简单的例子:

CMakeLists.txt文件

```cmake
# CMake最低版本要求，如果低于3.10.1版本，则构建过程会被终止
cmake_minimum_required(VERSION 3.10)

# 项目名称等信息
project(Hello)

# The version number.
set (Tutorial_VERSION_MAJOR 1)
set (Tutorial_VERSION_MINOR 0)

# should we use our own math functions?
option (USE_MYMATH  
        "Use tutorial provided math implementation" ON)

# configure a header file to pass some of the CMake settings
# to the source code
configure_file (
  "${PROJECT_SOURCE_DIR}/TutorialConfig.h.in"
  "${PROJECT_BINARY_DIR}/TutorialConfig.h"
  )

# 打印消息
message(STATUS "the BINARY dir is ${PROJECT_BINARY_DIR}")

# add the binary tree to the search path for include files
# so that we will find TutorialConfig.h
include_directories("${PROJECT_BINARY_DIR}")

# 添加一个库
add_library(MathFunctions mysqrt.cxx)

# 添加一个子目录
add_subdirectory(MathFunctions)

# add the executable
add_executable(Hello Hello.c)
target_link_libraries (Tutorial MathFunctions)
```

TutorialConfig.h.in:

```cmake
// the configured options and settings for Tutorial
#define Tutorial_VERSION_MAJOR @Tutorial_VERSION_MAJOR@
#define Tutorial_VERSION_MINOR @Tutorial_VERSION_MINOR@
```

## 常用命令

### message

```cmake
message([SEND_ERROR | STATUS | FATAL_ERROR] "message" ...)
```

第一个参数是消息类型，后面的参数是一条或多条要显示的消息。错误类型有 3 种: 

- SEND_ERROR: 表示产生错误信息
- STATUS: 表示一般的状态信息
- FATAL_ERROR: 严重错误信息，cmake 会立即停止执行

一条消息显示指令后可以跟上多条消息，它们会依次连在一起进行显示

## 常用变量

CMake 的常用变量:

- CMAKE_BINARY_DIR,PROJECT_BINARY_DIR,_BINARY_DIR: 这三个变量内容一致，如果是内部编译，就指的是工程的顶级目录，如果是外部编译，指的就是工程编译发生的目录。
- CMAKE_SOURCE_DIR,PROJECT_SOURCE_DIR,_SOURCE_DIR: 这三个变量内容一致，都指的是工程的顶级目录。
- CMAKE_CURRENT_BINARY_DIR: 外部编译时，指的是 target 目录，内部编译时，指的是顶级目录
- CMAKE_CURRENT_SOURCE_DIR: CMakeList.txt 所在的目录
- CMAKE_CURRENT_LIST_DIR: CMakeList.txt 的完整路径
- CMAKE_CURRENT_LIST_LINE: 当前所在的行
- CMAKE_MODULE_PATH: 如果工程复杂，可能需要编写一些 cmake 模块，这里通过SET指定这个变量
- LIBRARY_OUTPUT_DIR,BINARY_OUTPUT_DIR: 库和可执行的最终存放目录
- PROJECT_NAME: 项目名

系统信息:

1. CMAKE_MAJOR_VERSION,CMAKE 主版本号,比如 2.4.6 中的 2
2. CMAKE_MINOR_VERSION,CMAKE 次版本号,比如 2.4.6 中的 4
3. CMAKE_PATCH_VERSION,CMAKE 补丁等级,比如 2.4.6 中的 6
4. CMAKE_SYSTEM,系统名称,比如 Linux-2.6.22
5. CMAKE_SYSTEM_NAME,不包含版本的系统名,比如 Linux
6. CMAKE_SYSTEM_VERSION,系统版本,比如 2.6.22
7. CMAKE_SYSTEM_PROCESSOR,处理器名称,比如 i686.
8. UNIX,在所有的类 UNIX 平台为 TRUE,包括 OS X 和 cygwin
9. WIN32,在所有的 win32 平台为 TRUE,包括 cygwin

cmake 中调用环境变量

1. Using $ENV{NAME} : invoke system environment varible. We can use "SET(ENV{NAME} value)" as well. note that the "ENV" without "$".
2. CMAKE_INCLUDE_CURRENT_DIR equal to INCLUDE_DIRECTORY(${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_CURRENT_SOURCE_DIR})

其他的内置变量:

1. BUILD_SHARED_LIBS:set the default value when using ADD_LIBRARY()
   ON 或 OFF
2. CMAKE_C_FLAGS: set compiler for c language
3. CMAKE_CXX_FLAGS: set compiler for c++ language

指定编译 32bit 或 64bit 程序

SET(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -m32")
SET(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -m32")

## 控制指令

IF 指令,基本语法为:

```
IF(expression_r_r)
    # THEN section.
    COMMAND1(ARGS ...)
    COMMAND2(ARGS ...)
    ...
ELSE(expression_r_r)
    # ELSE section.
    COMMAND1(ARGS ...)
    COMMAND2(ARGS ...)
    ...
ENDIF(expression_r_r)
```

另外一个指令是 ELSEIF,总体把握一个原则,凡是出现 IF 的地方一定要有对应的ENDIF.出现 ELSEIF 的地方,ENDIF 是可选的。
表达式的使用方法如下:

```
IF(var),如果变量不是:空,0,N, NO, OFF, FALSE, NOTFOUND 或<var>_NOTFOUND 时,表达式为真。
IF(NOT var ),与上述条件相反。
IF(var1 AND var2),当两个变量都为真是为真。
IF(var1 OR var2),当两个变量其中一个为真时为真。
IF(COMMAND cmd),当给定的 cmd 确实是命令并可以调用是为真。
IF(EXISTS dir)或者 IF(EXISTS file),当目录名或者文件名存在时为真。
IF(file1 IS_NEWER_THAN file2),当 file1 比 file2 新,或者 file1/file2 其中有一个不存在时为真,文件名请使用完整路径。
```

```
IF(IS_DIRECTORY dirname),当 dirname 是目录时,为真。
IF(variable MATCHES regex)
IF(string MATCHES regex)
```

当给定的变量或者字符串能够匹配正则表达式 regex 时为真。比如:

```
IF("hello" MATCHES "ell")
MESSAGE("true")
ENDIF("hello" MATCHES "ell")
IF(variable LESS number)
IF(string LESS number)
IF(variable GREATER number)
IF(string GREATER number)
IF(variable EQUAL number)
IF(string EQUAL number)
```

数字比较表达式

```
IF(variable STRLESS string)
IF(string STRLESS string)
IF(variable STRGREATER string)
IF(string STRGREATER string)
IF(variable STREQUAL string)
IF(string STREQUAL string)
```


