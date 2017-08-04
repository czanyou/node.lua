# Node.lua C language extension library

> - Write: ChengZhen
> - Version: 2.0

## Overview 

This project mainly includes the Node.lua related C language extension storehouse.

This project will generate dynamic link library files in the Lua extension library format, such as `lmedia.so`, which can be loaded and used directly in the Lua language by` local lmedia = require ('lmedia') `.

Lmedia mainly encapsulates the peripheral hardware access interface and media layer, and provides the relevant Lua API interface.

## Directory description

- build CMake Temporary build directory
- examples reference routines
- src C language source code
- targets and target-related code and configuration files
Test cases

### Introduction to the target board directory

- targets/common public file storage directory
Hi3516a development board adaptation library
Hi3518 development board adaptation library
- targets/mock simulation test library
- targets/linux UVC camera adapter library

## Build method

### Windows:

Windows can directly run make.bat compile the current project. Compile into a function will automatically copy a lmedia.dll dynamic library to `node/node.lua/bin /` directory.

### Linux:

Run `make local` in the current directory to compile the current project.

### Cross-compilation

Run `make <development board name>` in the current directory to compile the current project (only for configured and supported development boards).

Such as compiling the Hi3518 target board file:
 
    # Make hi3518 <enter>

## Operating System Dynamic Library Differences

Because this subproject generates a dynamic library, and Windows, Linux and macOS support for dynamic libraries vary widely,
So different operating system platforms will use a completely different file-dependent mode:

### Windows:

Lua virtual machine must be compiled into a dynamic module under Windows.If Lua is compiled into a static library and only generates a single executable file can not be achieved dynamic load module plugin, because lmedia.dll also depends on Lua, so will not be able to dynamically load lmedia module .

So we will generate the following three binary files, which lmedia is dynamically loaded.

Lnode.exe => lmedia.dll => lua53.dll

These three files are all placed in the `/<base>/node/bin` directory.

### Linux

Linux does not have the same limitations as Windows and can compile only a single executable lnode, and lmedia can be compiled into modules and can be loaded dynamically.

Lmedia.so should be placed in `/<base>/node/bin` directory, do not put the system lib directory

### Hi3518/Hi3516a ...

Heisi development board with the basic Linux, but the use of video capture and other functions need to call Heisi SDK, so the main program needs to add to the mpi, isp and other Heisi SDK dynamic library link.
Where lmedia is dynamically loadable.

Lnode => libmpi.so

Lmedia.so should be placed in `/<base>/node/bin` directory, do not put the system lib directory

### macOS

MacOS for the sake of convenience, will only generate a single executable file.