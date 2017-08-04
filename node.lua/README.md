#Node.lua

> - Write: ChengZhen
> - Version: 2.0

## Overview

Node.lua is a Lua runtime environment similar to Node.js.

The purpose of Node.lua is not to replace Node.js, but rather to use Node.js-like development and runtime environments on less-expensive hardware such as embedded devices.

Compared to Node.js, Node.lua requires less memory, runs faster, and is easier to mix with C/C ++, and provides a useful API, such as coroutines, multithreading, and more.

The main drawback is the relative Javascript, the use of Lua language is relatively small, but fortunately, Lua and Javascript are very similar, familiar with the development is not very different.

## Directory Definitions

- bin The executable directory
- build CMake Temporary build directory
- deps The C module directory on which the main program depends
- docs The documentation directory
- Lua core library source code directory
- src main program C language source code directory
Test cases directory

### The root directory file

- CMakeLists.txt CMake configuration file
- install.bat Batch file to run install.lua under Windows
- install.lua Windows development and runtime environment installation script
- make.bat CMake the batch file to run under Windows
- Makefile Compile the batch file under Linux
- package.json lnode Lua core library metadata configuration file
- README.md This document

### bin: Executable directory

- lpm Lua Package Manager main executable program
- lpm.bat lpm in the implementation of the Windows batch file

### deps: Dependencies

Node.lua main program by the C language, and contains the lua, libuv, miniz core library:

- (libuv) libuv 1.9.0 or more
- (Lua) PUC Luua 5.3.2 above
- (luajson) cjson JSON codec, in Lua by require ("cjson") call
- (luassl) krypton SSL implementation of the library, in the Lua can require ("ssl") call
- (luautils) to achieve buffer, hex, http parser, md5 other functions, in Lua by require ("lutils") call
- (luauv) is mainly used to bind libuv to Lua. In Lua, it can be called by require ("uv")
- (luazip) miniz ZIP compression decompression library, in Lua by require ("miniz") call

Dependency library source code download address:

- http://www.lua.org/ftp/
- https://github.com/libuv/libuv
- https://github.com/richgel999/miniz
- https://github.com/mpx/lua-cjson
- https://github.com/luvit/luv

Note: Because lua 5.3 and luajit 2 vary widely, temporarily do not provide support for luajit 2.

### lua: The Lua core library for class node.js

Node.lua core library, and the main node.js similar to the core library, call the same method can refer to the document node.js

## Build the main program

### Overview

This section describes how to develop and compile the source code after downloading it to the local source

The main program source code is mainly composed of C language, the source file directory is `/src/`, the main function file is `/src/main.c`, and the other modules are located in`/deps/`directory.

Mainly used to achieve cross-platform cmake build and compile the code, the compiler must be installed cmake related software

### Compiler under Linux

Direct implementation of the project root directory can be made.

### Compiled under MacOS

Install CMake first.

CMake can be installed after the implementation of the following command to install CMake command line tool.

    Sudo mkdir -p/usr/local/bin
    Sudo /Applications/CMake.app/Contents/bin/cmake-gui --install =/usr/local/bin

### Compile under Windows

Install cmake and visual studio first, and then run make.bat, will be generated into build/win32 directory

### Cross-compilation

Cross-compiler hi3518, first install the cmake and hi3518 Linux tool chain, and then run make hi3518, will be generated into build/hi3518 directory

#### Other platforms cross compiler:

Modify the location code below CMakeLists.txt to add the new platform type and toolchain name

```
# Cross-compile option, through the BOARD_TYPE parameter to determine the compiler tool chain
MESSAGE (STATUS "Build: BOARD_TYPE = $ {BOARD_TYPE}")
If (BOARD_TYPE STREQUAL hi3518)
  MESSAGE (STATUS "Build: use arm-hisiv100nptl-linux-gcc")
  Set (CMAKE_C_COMPILER "arm-hisiv100nptl-linux-gcc")
Else (BOARD_TYPE STREQUAL hi3518)

Endif (BOARD_TYPE STREQUAL hi3518)
```

Modify the Makefile, refer to hi3518 add other platform compiler command

```Sh
Hi3518:
# Cross-compilation
    Cmake -H. -Bbuild/hi3518 -DBOARD_TYPE = hi3518
    Cmake --build build/hi3518 --config Debug
```

among them

- build/hi3518 represents the intermediate file and target file generation directory
- BOARD_TYPE = hi3518 Indicates the platform type configured in CMakeLists

If you do not specify the development environment will be the default environment and tools

### Makefile

Eventually, the lnode executable will be generated, along with the required dynamic-link libraries:

- Linux: `bin/lnode`.

- MacOS: `bin/lnode`.

- Under Windows: `bin/lnode.exe` and` bin/lua53.dll`.

# # Lua development and debugging

This section describes how to develop and debug lua scripts after compiling the lnode main program.

### Windows development and debugging

After the main program is built, the executable is copied to the `node.lua\bin \` directory.

Then run `node.lua\install.bat`, the current development directory will be ` node.lua\bin\` and `node.lua\lua\`will be registered to the system environment variable.

Open a new cmd window, execute `lpm`, and if it runs successfully, it means the installation is correct.

### Linux development and debugging

Installation content are:

- Copy the lnode main program, and lpm and other executable files to the system directory, and add the appropriate execution permissions.
- To call a module in the lua directory, you must associate the lua directory to the Lua module search path of the lnode main program. Otherwise, you will not be able to find the relevant module.

After the completion of the main program to build in the current directory to run:

> Make install

The above script will copy the above generated executable file to the system directory and add the required environment variables

At the system command line prompt, execute: `lpm`, if there is help to display lpm, it means that Node.lua development environment installed successfully

## Release

Node.lua can not be released separately, it is only Node.lua core project, to publish the complete Node.lua SDK, please refer to node.lua on a directory `README.md`.