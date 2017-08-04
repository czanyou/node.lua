# 媒体流队列

[TOC]

## 概述

媒体流是一组特殊的数据流, 它一般以帧为单位, 每一帧是不可分割的, 否则会导致图像显示不全.

其次像 H.264 这样的视频流还分为关键帧和非关键帧, 其中非关键帧依赖于关键帧和之前的非关键帧, 必须小心地按次序发送接收并解码才能显示出正确的图像.

这个队列是专用于处理媒体流的, 它总是按帧为单位缓存数据流, 并且能采取合适的丢帧微策略, 在下一级无法及时处理数据时(如网络发送时), 能丢掉合适的帧而不会引起马赛克等问题.

### queue.MAX_QUEUE_SIZE

    queue.MAX_QUEUE_SIZE = 10

默认队列缓存长度，单位为帧，当缓存的帧超过这个数量时会开始自动丢弃。


### queue.FLAG_IS_SYNC

    queue.FLAG_IS_SYNC = 0x01

同步点(关键帧)


### queue.FLAG_IS_END

    queue.FLAG_IS_END = 0x02

帧结束标记


### queue.newMediaQueue

    queue.newMediaQueue([maxQueueSize])

返回创建的 MediaQueue 对象

- maxQueueSize {Number} 这个队列的最大长度, 如果没有指定则为 10.

## 类 MediaQueue

MediaQueue 提供了一个队列，能够缓存，排序媒体帧，并自动丢弃过多的帧。

在媒体流的发送端和接收端都可以用到。

在发送端可以防止网络发送过慢时，堆积过多的数据

在接收到可以缓存收到的数据并等待客户端解码显示等处理。

### 属性 currentSample

{Object + Array} 当前正在拼接的帧, 直到等到 FLAG_IS_END 才表示收到完整的一帧.

### 属性 maxQueueSize

{Number} 指出当前队列最大缓存长度, 当队列中的帧超过此长度时, 队列中所有帧都会被丢弃.

这样可以保证缓存队列不会无限扩大.

### 属性 waitSync

{Boolean} 指出是否还在等待关键帧, 当 waitSync 为 true 的时候, 所有非关键帧都会被丢弃.


### MediaQueue:onSyncPoint

    MediaQueue:onSyncPoint()

内部方法, 应用程序不可以直接执行这个方法.

子类通过重载这个方法来实现不同的丢帧策略

默认的丢帧策略, 如果当前缓存列队中的帧数超过 maxQueueSize, 则全部丢弃.


### MediaQueue:pop

    MediaQueue:pop()

从队列中取出完整的一帧，如果没有则返回 nil

返回 {Array + Object} 有如下属性:

- sampleTime {Number} 当前帧时间戳, 源自 push 方法, 单位为 1 / 1,000,000 秒
- isSyncPoint {Boolean} 当前帧是否是同步点, 源自 push 方法


### MediaQueue:push

    MediaQueue:push(sampleData, sampleTime, flags)

往队列中写媒体数据

队列接收媒体数据流，每次只需写入流的分片，并自动合并成完整的帧。相当于零存整取。

需要合并成完整的帧的原因是为了方便丢帧处理，因为假如只丢掉帧的部分数据会导致传输和解码异常，出现马赛克甚至崩溃。

- sampleData {String} 字节数组，媒体数据，这个队列不关心数据内容和长度等
- sampleTime {Number} 整数, 媒体时间戳, 单位为 1 / 1,000,000 秒
- flags {Number} 整数, 媒体数据标记, 具体定义有为 FLAG_IS_SYNC: 同步点(关键帧), FLAG_IS_END: 帧结束标记

如果返回 true 表示拼接了完整的一帧并 push 到了队列中, 这时 currentSample 会变为 nil, 否则只是暂存到了 currentSample 中.
