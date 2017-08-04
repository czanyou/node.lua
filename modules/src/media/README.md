# 多媒体接口

## common - 公共代码

- base_types.h 和平台有关的数据类型定义, 头文件包含等, 所有源文件都会包含这个文件
- media_comm.c 公共的媒体相关的数据结构定义, 公共的方法等.

## hardware - 通用硬件 I/O 接口

- gpio_lua.c GPIO 口控制模块 Lua 封装层
- i2c.c I2C 总线控制模块
- i2c_lua.c I2C 总线控制模块 Lua 封装层

## sml - 简单媒体层

- audio_in_lua.c 音频输入模块 Lua 封装层
- audio_out_lua.c 音频输出模块 Lua 封装层
- media_lua.c 媒体层一些基本或公共的方法的 Lua 封装层
- video_encoder_lua.c 视频编码模块 Lua 封装层
- video_in_lua.c 视频输入模块 Lua 封装层

## ts - TS 传输流解析和打包

- ts_reader.c TS 流解析器
- ts_reader_lua.c TS 流解析器 Lua 封装层
- ts_writer.c TS 流打包器
- ts_writer_lua.c TS 流打包器 Lua 封装层

## 入口模块

- lmedia.c 入口模块






