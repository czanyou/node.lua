# 定时器 (timers)

通过 require('timer') 调用

## 取消定时器

### clearImmediate

> clearImmediate(immediate)

取消由 setImmediate() 创建的 Immediate 对象。

- `immediate` {Immediate} setImmediate() 返回的 Immediate 对象。


### clearInterval

> clearInterval(timeout)

取消由 setInterval() 创建的 Timeout 对象。

- `timeout` {Timeout} setInterval() 返回的 Timeout 对象。

### clearTimeout

> clearTimeout(timeout)

取消由 setTimeout() 创建的 Timeout 对象。

- `timeout` {Timeout} setTimeout() 返回的 Timeout 对象。

## 设置定时器

### setImmediate

> setImmediate(callback[, args][, ...])

预定在 I/O 事件的回调之后立即执行的 callback。

- `callback` {function} 在当前回合的 Node 事件循环结束时调用的函数。
- `...args` {any} 当调用 callback 时传入的可选参数。
- `返回`: {Immediate} 用于 clearImmediate()。

当多次调用 setImmediate() 时， callback 函数将按照创建它们的顺序排队等待执行。 每次事件循环迭代都会处理整个回调队列。 如果立即定时器是从正在执行的回调排入队列，则直到下一次事件循环迭代才会触发。


### setInterval

> setInterval(delay, callback[, arg][, ...])

预定每隔 delay 毫秒重复执行 callback。

- `callback` {function} 当定时器到点时调用的函数。
- `delay` {number} 调用 callback 之前等待的毫秒数。
- `...args` {any} 当调用 callback 时传入的可选参数。
- `返回`: {Timeout} 用于 clearInterval()。


### setTimeout

> setTimeout(delay, callback[, arg][, ...])

预定在 delay 毫秒之后执行一次性的 callback。

- `callback` {function} 当定时器到点时调用的函数。
- `delay` {number} 调用 callback 之前等待的毫秒数。
- `...args` {any} 当调用 callback 时传入的可选参数。
- `返回`: {Timeout} 用于 clearTimeout()。

可能不会精确地在 delay 毫秒时调用 callback。 Node 不保证回调被触发的确切时间，也不保证它们的顺序。 回调会在尽可能接近指定的时间调用。

