# 定时器 (timers)

[TOC]

通过 require('timer') 调用

## clearImmediate

    clearImmediate(immediateObject)

停止一个 immediate 的触发。   


## clearInterval

    clearInterval(intervalObject)

停止一个 interval 的触发。


## clearTimeout

    clearTimeout(timeoutObject)

阻止一个 timeout 被触发。


## ref 

     ref() 

如果您之前 unref() 了一个定时器，您可以调用 ref() 来明确要求定时器让程序保持运行。
如果定时器已被 ref 那么再次调用 ref 不会产生其它影响。


## setImmediate

    setImmediate(callback[, arg][, ...])

调度在所有 I/O 事件回调之后、setTimeout 和 setInterval 之前“立即”执行 callback。
返回一个可能被 clearImmediate() 用到的 immediateId。可选地，您还能给回调传入参数。


immediate 的回调以它们创建的顺序被加入队列。整个回调队列会在每个事件循环迭代中被处理。
如果您在一个正被执行的回调中添加 immediate，那么这个 immediate 在下一个事件循环迭代之前都不会被触发。


## setInterval

    setInterval(delay, callback[, arg][, ...])

调度每隔 delay 毫秒执行一次的 callback。返回一个可能被 clearInterval() 用到的 intervalId。
可选地，您还能给回调传入参数。


## setTimeout

    setTimeout(delay, callback[, arg][, ...])

调度 delay 毫秒后的一次 callback 执行。返回一个可能被 clearTimeout() 用到的 timeoutId。
可选地，您还能给回调传入参数。


请务必注意，您的回调有可能不会在准确的 delay 毫秒后被调用。Node
不保证回调被触发的精确时间和顺序。回调会在尽可能接近所指定时间上被调用。


## unref

    unref()

setTimeout 和 setInterval 所返回的值同时具有 timer.unref() 方法，允许您创建一个活动的、
但当它是事件循环中仅剩的项目时不会保持程序运行的定时器。如果定时器已被 unref，再次调用 
unref 不会产生其它影响。

在 setTimeout 的情景中当您 unref 您会创建另一个定时器，并唤醒事件循环。
创建太多这种定时器可能会影响事件循环的性能，慎用。

