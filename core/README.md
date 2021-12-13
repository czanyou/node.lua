# Node.lua

## Overview

A framework for Internet of Things

Node.lua is a Lua running environment similar to Node.js.

The goal of Node.lua is not to replace Node.js, but to use development and operating environments similar to Node.js on less capable hardware such as embedded devices.

Compared with Node.js, node.lua has lower requirements on memory, faster operation, easier to mix with C/C++ development, and can also provide useful apis such as coprocessing and multi-threading.

The main drawback is that compared to Javascript, few people use Lua language, but fortunately Lua and Javascript are very similar, after being familiar with the development of small differences.

## Directories

- deps      Dependent C module
- lua       The core library source code written in Lua language
- tests     Unit test cases

### Root files

- make.cmake    CMake configuration file
- README.md     This document

### deps: dependent projects

The main program of Node.lua is implemented by C language and contains core libraries such as Lua, libuv and miniz:

- (libuv) libuv 1.11 and above
- (lua) PUC lua 5.3 and above
- (luajson) cjson codec, which can be called in Lua via require("cjson")
- (luautils) implements buffer, hex, HTTP parser, md5 and other functions, which can be called in Lua by require("lutils")
- (luauv) is mainly used to bind libuv to lua. in Lua, it can be called via require('luv')
- (luazip) miniz ZIP decompression library, which can be called in Lua by require("miniz")
- (lnode) lnode main program entry function code

Related dependent library source code download URLs:

- http://www.lua.org/ftp/
- https://github.com/libuv/libuv
- https://github.com/richgel999/miniz
- https://github.com/mpx/lua-cjson
- https://github.com/luvit/luv

### lua: The lua core library

The core library of Node.lua implements similar to node.js

### tests: Unit test cases

All unit test cases are included
