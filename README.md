# Node.lua

> - Author：ChengZhen
> - Version：3.2

Platform for Internet of Things with Lua.
Modern IoT device embedded software development platform.

> Node.lua is a framework for "Internet of Things" built on lightweight Lua interpreter and libuv for event driven (non-blocking I/O model) similar to node.js.

Using dynamic languages to develop embedded applications, you can focus on application logic, quickly respond to rapidly changing requirements, and implement faster functional iterations.

## 特色 -  Features

- Use pure C language, easy to transplant, superior performance, flexible and compact
- Use mature frameworks like libuv
- Use simple and easy to use Lua as the application development language
- Use the same core API as Node.js
- provide a common extension of the library, and easy to expand on their own
- Specifically for embedded optimization, fast running, less space

### Supported platforms

Current supported platforms are Linux.

macOS & Windows as development host.

#### H/W boards

- Raspberry Pi
- Nano Pi
- MT7688
- Hi3516

### 目录结构

| Path       | Description
| ---        | ---
| app        | Applications
| docs       | Development documents
| modules    | Lua extension modules
| node.lua   | Core modules

## 构建 - How to Build

Node.lua was designed to build seamlessly with minimal dependencies on most platforms:

- All platforms: CMake >= 2.8
- Windows: MSVC++
- MacOS: XCode
- Linux: Make, GCC

```sh
# Build source code
$ make build

# Install to the current system
$ make install

```

## 文档 - Documentation

- [开始指南 - Getting Started](docs/README.md)
- [基本 API - Basic API Reference](docs/api/README.md)
- [扩展 API - Extended API Reference](docs/vision/README.md)

## 许可 - License

Node.lua is Open Source software under the Apache 2.0 license. Complete license and copyright information can be found within the code.
