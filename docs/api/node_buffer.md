# 缓存区 (buffer)

[TOC]

> 未稳定: 这个模块的方法还在调整中


## 类: Buffer

Buffer 类用来直接处理2进制数据的。 它能够使用多种方式构建。

通过 require('buffer') 调用

虽然在 Lua 中 String 就可以处理二进制数字, 但不同于 String, Buffer 的内容数据是可以修改的,
所以 Buffer 可以代替 String 用在对性能有要求的地方.

Buffer 类包含了一个内部缓存区以及两个指针, position 指针表示有效数据开始的位置，limit 表示有效数据结束的位置。

    1 <= position <= length
    1 <= limit <= (length + 1)
    (position < limit) or (position == limit == 1)

### Buffer.concat(list)

- list {Buffer Array} 要连接的 Buffer 列表

TODO: 暂未实现

### Buffer.compare(buf1, buf2)

比较两个 Buffer 的大小, 在排序的时候很有用

TODO: 暂未实现


### Buffer:new(size)

    Buffer:new(size)
    Buffer:new(str)
    Buffer:new(buffer)    

分配一个新的 buffer 大小是 size 的 8 位字节.

- size {Number} 要创建的 Buffer 内部缓存区大小。
- str {String} 复制 str 字符串的内容到新创建的 Buffer.
- buffer {Buffer Object} 复制 buffer 的内容到新创建的 Buffer.

### buffer:compress

    buffer:compress()

压缩缓存区开始位置空闲空间，即如果 position 的值大于 1，则将有效数据移到位置为 1 的地方，并同时移动 position 和 limit 指针的值。

```lua

local buf = Buffer:new(32)
        
--asserts.equal(buf:limit(), 1)
--asserts.equal(buf:position(), 1)

buf:fill(68, 1, 32)   
buf:fill(69, 9, 32) 

buf:expand(32)
buf:skip(4)

--asserts.equal(buf:limit(), 33)
--asserts.equal(buf:position(), 5)

buf:compress()

--asserts.equal(buf:limit(), 29)
--asserts.equal(buf:position(), 1)

```

### buffer:copy

    buffer:copy(targetBuffer, targetStart, sourceStart, sourceEnd)

将当前缓存区指定范围的数据复制到目标缓存区的指定位置, 内部使用 memcpy 实现.

注意只有满足条件才会被全部复制，不会只复制部分数据。

- targetBuffer {Buffer} 目标缓存区
- targetStart {Number} 目标缓存区开始复制到的位置
- sourceStart {Number} 源缓存区开始复制的位置
- sourceEnd {Number} 源缓存区结束复制的位置

返回 1 表示复制成功，否则表示复制失败且目标缓存区不会被改变

```lua

local buf1 = Buffer:new(32)
buf1:fill(68, 1, 32)   
buf1:fill(70, 8, 32) 
buf1:expand(32)

local buf2 = Buffer:new(32)
buf2:fill(69, 1, 32)  
buf2:expand(32)

local ret = buf1:copy(buf2, 3, 4, 11)
print('ret', ret) -- 1

ret = buf1:copy(buf2, 1, 1, 34)
print('ret', ret) -- -1

print(buf1:toString()) -- DDDDDDDFFFFFFFFFFFFFFFFFFFFFFFFF
print(buf2:toString()) -- EEDDDDFFFFEEEEEEEEEEEEEEEEEEEEEE

```

### buffer:expand

    buffer:expand(size)

移动 limit 指针的值。

- size {Number} 要移动的大小, 不能超出缓存区的上限.

返回实际移动的大小，如果失败则返回 0。


### buffer:fill

    buffer:fill(value, offset, endPos)

使用指定的值来填充这个 buffer。如果 offset (默认是 1) 并且 end (默认是 buffer.length) 没有明确给出，
就会填充整个buffer。（buffer.fill 调用的是 C 语言的 memset 函数, 非常高效）

- value {Number} 要填入的值
- offset {Number} 可选参数，没有指定则为 1.
- endPos {Number} 可选参数，没有指定则为 buffer.length


### buffer:inspect

    buffer:inspect()


### buffer:isEmpty

    buffer:isEmpty()

指出这个缓存区是否为空


### buffer:limit

    buffer:limit([limit])

指定 limit 指针的大小。

- limit {Number} 要修改为的指针值，没是指定则不修改只读取。1 <= limit <= (length + 1)

返回修改后的 limit 指针的值。


### buffer:position

    buffer:position([position])

指定 position 指针的值。

- position {Number} 要修改为的指针值，没是指定则不修改只读取。1 <= position <= length

返回修改后的 position 指针的值。


### buffer:put

    buffer:put(offset, value)


将指定的字符写入缓存区指定的位置。

- offset {Number} 要写入的缓存区的偏移位置。
- value {Number} 要写入的字符。

如果写入成功则返回 1，否则表示写入失败。


### buffer:putBytes

    buffer:putBytes(offset, data, [startPos], [endPos])

将指定的数据的某部分写入缓存区指定的位置。

- offset {Number} 要写入的缓存区的偏移位置。
- data {String} 要写入的数据内容。
- startPos {Number} 要写入的数据的开始位置，未指定则默认为 1。
- endPos {Number} 要写入的数据的结束位置，未指定则默认为数据的结尾位置。

如果写入成功则返回 1，否则表示写入失败。


### buffer:read
### buffer:readInt8
### buffer:readInt16BE
### buffer:readInt16LE
### buffer:readInt32BE
### buffer:readInt32LE
### buffer:readUInt8
### buffer:readUInt16BE
### buffer:readUInt16LE
### buffer:readUInt32BE
### buffer:readUInt32LE

    read(offset)

- offset {Number} 要开始读取的位置。

从指定的偏移位置读取一个整数。


### buffer:size

    buffer:size()

返回当前缓存区中有效数据的长度。


### buffer:skip

    buffer:skip(size)

移动 position 指针。

- size {Number} 要移动的大小。

返回实际移动的大小，如果失败则返回 0 。


### buffer:toString

    buffer:toString(startPos, endPos)

返回这个缓存区指定的范围的数据。

- startPos {Number} 开始的位置，从 1 开始。
- endPos {Number} 结束的位置，大于等于 startPos，小于等于 length。

返回相关的字符串值，如果失败则返回 nil。


### buffer:write

    buffer:write(data, offset, length)

将参数 data 数据写入缓存区当前位置，这个方法不会出现写入部分字符。

- data {String} 要写入的数据内容
- offset {Number} 要写入的数据内容偏移位置, 从 1 开始
- length {Number} 总共要写入的数据的长度，单位为字节，不能大于从 offset 开始剩余的数据长度。

如果写入成功则返回 1，否则表示写入失败。


