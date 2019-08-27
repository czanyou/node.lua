# lmedia - 简单媒体访问层

Lua API 将分两层, 底层 API 为直接封装 media_comm.h 中定议的 C API

通过 `require('lmedia')` 调用。

> 状态: 开发中

当前 API 还在开发中, 随时可能被修改

## lmedia 模块

### 常量 VERSION

    lmedia.VERSION

- {String} 返回当前媒体处理系统版本

### 常量 TYPE

    lmedia.TYPE

- {String} 返回当前媒体处理的类型

### lmedia.init

    lmedia.init()

初始化媒体处理系统环境, 在所有其他 API 之前调用

### lmedia.release

    lmedia.release()

关闭媒体处理系统, 释放相关资源, 在程序关闭前以及所有的媒体相关的 API 调用后执行.
