# 核心 (Core)

[TOC]

## core.instanceof(obj, class)

判断指定的对象是否是指定的类的实例

- obj {Object} 对象
- class {Class} 类


## 对象 (Object)

大部分类的基类, 实现简单的面向对象机制


### Object:new

    Object:new(...)

创建一个类的实例


### Object:extend

    Object:extend()

创建一个子类


## 事件 (Events)

Node 里面的许多对象都会分发事件：一个 net.Server 对象会在每次有新连接时分发一个事件， 一个 fs.readStream 对象会在文件被打开的时候发出一个事件。 所有这些产生事件的对象都是 events.EventEmitter 的实例。

通常，事件名是驼峰命名 (camel-cased) 的字符串。不过也没有强制的要求，任何字符串都是可以使用的。

为了处理发出的事件，我们将函数 (Function) 关联到对象上。 我们把这些函数称为 监听器 (listeners)。 在监听函数中 this 指向当前监听函数所关联的 EventEmitter 对象。

## 类: EventEmitter

通过 require('core').EventEmitter 获取 EventEmitter 类。

当 EventEmitter 实例遇到错误，通常的处理方法是产生一个 'error' 事件，node 对错误事件做特殊处理。 如果程序没有监听错误事件，程序会按照默认行为在打印出 栈追踪信息 (stack trace) 后退出。

EventEmitter 会在添加 listener 时触发 'newListener' 事件，删除 listener 时触发 'removeListener' 事件

### 事件: 'newListener'

- event {String} 事件名
- listener {Function} 事件处理函数

在添加 listener 时会发生该事件。 此时无法确定 listener 是否在 emitter.listeners(event) 返回的列表中。

### 事件: 'removeListener'

- event {String} 事件名
- listener {Function} 事件处理函数

在移除 listener 时会发生该事件。此时无法确定 listener 是否在 emitter.listeners(event) 返回的列表中。

### emitter.addListener

emitter.on 方法别名


### emitter.emit

    emitter.emit(event, [arg1], [arg2], [...])

使用提供的参数按顺序执行指定事件的 listener

- event {String} 事件名

若事件有 listeners 则返回 true 否则返回 false。


### emitter.listeners

    emitter.listeners(event)

返回指定事件的 listener 数组

- event {Strin} 事件名

```lua
server:on('connection', function (stream) 
  print('someone connected!')
end);

print(server:listeners('connection')); -- [ [Function] ]
```


### emitter.on

    emitter.on(event, listener)

添加一个 listener 至特定事件的 listener 数组尾部。

- event {String} 事件名
- listener {Function} 事件处理函数

```lua
server:on('connection', function (stream) 
  print('someone connected!')
end);
```

返回 emitter，方便链式调用。


### emitter.once

    emitter.once(event, listener)

添加一个 一次性 listener，这个 listener 只会在下一次事件发生时被触发一次，触发完成后就被删除。

- event {String} 事件名
- listener {Function} 事件处理函数

```lua
server:once('connection', function (stream) 
  print('Ah, we have our first user!')
end)
```

返回 emitter，方便链式调用。


### emitter.removeListener

    emitter.removeListener(event, listener)

从一个事件的 listener 数组中删除一个 listener 注意：此操作会改变 listener 数组中在当前 listener 后的listener 的位置下标

- event {String} 事件名
- listener {Function} 事件处理函数

```lua
local callback = function(stream) 
  print('someone connected!')
end

server:on('connection', callback)

-- ...

server:removeListener('connection', callback)
```

返回 emitter，方便链式调用。


### emitter.removeAllListeners

    emitter.removeAllListeners([event])

删除所有 listener，或者删除某些事件 (event) 的 listener

- event {String} 事件名

返回 emitter，方便链式调用。


### emitter.setMaxListeners

    emitter.setMaxListeners(n)

在默认情况下，EventEmitter 会在多于 10 个 listener 监听某个事件的时候出现警告，此限制在寻找内存泄露时非常有用。 显然，也不是所有的 Emitter 事件都要被限制在 10 个 listener 以下，在这种情况下可以使用这个函数来改变这个限制。设置 0 这样可以没有限制。

返回 emitter，方便链式调用。


### emitter.listenerCount

    emitter.listenerCount(event)

返回指定事件的 listeners 个数

- event {String} 事件名
