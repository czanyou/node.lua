# lutils

[TOC]

## base64_encode

    base64_encode(data)

Base64 编码

## base64_decode

    base64_decode(data)

Base64 解码

## hex_encode

    hex_encode(data)

HEX 编码

## hex_decode

    hex_decode(data)

HEX 解码

## md5

    md5(data)

计算 MD5 Hash 值

## new_buffer

    new_buffer(size)

创建一个新的缓存区

### buffer:close

    buffer:close()

关闭这个缓存区

### buffer:copy

    buffer:copy(position, buffer, offset, length)

从另一个缓存区复制数据到当前缓存区中

### buffer:fill

    buffer:fill(value, position, length)

以指定的值填充当前缓存区

### buffer:get_byte

    buffer:get_byte(position)

返回缓存区指定位置的字节的值

### buffer:get_bytes

    buffer:get_bytes(position, length)

返回缓存区指定范围的字节的值

### buffer:limit

    buffer:limit(limit)

查询或修改 limit 指针的值

### buffer:move

    buffer:move(position, source, length)

在缓存区内移动数据块的位置

### buffer:position

    buffer:position(position)

查询或修改 position 指针的值    

### buffer:put_byte

    buffer:put_byte(position, value)

写入数据到当前缓存区指定位置

### buffer:put_bytes

    buffer:put_bytes(position, data, offset, length)

写入数据到当前缓存区指定位置

### buffer:length

    buffer:length()

返回当前缓存区的长度

### buffer:to_string

    buffer:to_string()

## os_arch

    os_arch()

返回操作系统 CPU 架构，可能的值有 "x64"、"arm" 和 "ia32"

## os_platform
 
     os_platform()

操作系统平台名称
