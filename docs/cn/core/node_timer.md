# 定时器 (timers)

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

