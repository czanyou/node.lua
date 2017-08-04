# 线程 (thread)

[TOC]

## 多线程

Node.lua 支持多线程, 但是各个线程是属于不同的虚拟机, 变量不能相互访问, 但可以通过消息等相互通信.

通过 require('thread') 调用

### thread.equals

    thread.equals(thread1, thread2)

指出两个线程是否相等。

### thread.join

    thead.join(thread)

等待指定的线程结束。

### thread.queue

    thread.queue(worker, ...)

把指定的 Worker 放入线程池工作队列。这个 Worker 会在线程池中被依次执行

等同于 `worker:queue(...)`

- worker thread.Worker

```lua

local work = thread.work(
  function(n)
    local thread = require('thread')
    local self = tostring(thread.self())
    return self, n, n * n
  end,
  function(threadId, n, result)
    print(threadId, n, result)
    print('worker result callback', threadId, n * n == result)
  end
)

thread.queue(work, 2)

```

### thread.self

    thread.self()

返回当前线程自身的引用。

### thread.sleep

    thread.sleep(timeout)

当前线程休眠指定的时间

- timeout {Number} 要休眠的时间

### thread.start

    thread.start(thread_func, ...)

这个方法启动一个新的线程，并返回相关的线程对象。

- thread_func {Function} 线程过程函数, 注意这个函数会在一个新的虚拟机中运行，所以不能直接访问父线程的变量，但可以通过消息和父线程通信

```lua
function thread_func(param1, param2)
    print(param1 + param2)
end

local theThread = thread.start(thread_func, 2, 3)
theThread:join()

```

### thread.work

    thread.work(thread_func, notify_entry)

创建一个新的 thead.Worker 类的实例。

- thread_func {Function} 这个 Worker 的过程函数
- notify_entry {Function} 当这个 Worker 执行完成后会调用这个函数

### 类 thread.Worker

可被线程池执行的一个 Worker 类

#### work:queue

    work:queue(...)

把这个 Worker 放入线程池工作队列。这个 Worker 会在线程池中被依次执行

## 协程

关于协程的操作作为基础库的一个子库， 被放在一个独立表 coroutine 中。 

这是内置的模块, 可以直接调用

### coroutine.create

    coroutine.create (f)

创建一个主体函数为 f 的新协程。 f 必须是一个 Lua 的函数。 返回这个新协程，它是一个类型为 "thread" 的对象。

### coroutine.isyieldable 

    coroutine.isyieldable()

如果正在运行的协程可以让出，则返回真。

不在主线程中或不在一个无法让出的 C 函数中时，当前协程是可让出的。

### coroutine.resume 

    coroutine.resume(co [, val1, ···])

开始或继续协程 co 的运行。 当你第一次延续一个协程，它会从主体函数处开始运行。 val1, ... 这些值会以参数形式传入主体函数。 如果该协程被让出，resume 会重新启动它； val1, ... 这些参数会作为让出点的返回值。

如果协程运行起来没有错误， resume 返回 true 加上传给 yield 的所有值 （当协程让出）， 或是主体函数的所有返回值（当协程中止）。 如果有任何错误发生， resume 返回 false 以及错误消息。

### coroutine.running 

    coroutine.running()

返回当前正在运行的协程以及一个布尔量。如果当前运行的协程是主线程，其布尔量为真。

### coroutine.status

    coroutine.status(co)

以字符串形式返回协程 co 的状态: 当协程正在运行（它就是调用 status 的那个），返回 "running"; 如果协程调用 yield 挂起或是还没有开始运行，返回 "suspended"; 如果协程是活动的，都并不在运行（即它正在延续其它协程），返回 "normal"; 如果协程运行完主体函数或因错误停止，返回 "dead"。

### coroutine.wrap

    coroutine.wrap(f)

创建一个主体函数为 f 的新协程。 f 必须是一个 Lua 的函数。 返回一个函数， 每次调用该函数都会延续该协程。 传给这个函数的参数都会作为 resume 的额外参数。 和 resume 返回相同的值， 只是没有第一个布尔量。 如果发生任何错误，抛出这个错误。

### coroutine.yield

    coroutine.yield(···)

挂起正在调用的协程的执行。 传递给 yield 的参数都会转为 resume 的额外返回值。




