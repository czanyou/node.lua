# 异步模型

## 概述

Node.lua 集成了 libuv 核心库

## libuv 

> http://docs.libuv.org

### 概述

libuv 是一个专注于异步 I/O 编程的多平台支持库. 目前主要是开发给 Node.js 使用.

### 主要特性

- 事件循环
- 异步 TCP 和 UDP 套接字
- 异步 DNS 方案
- 异步文件和文件系统操作
- 文件系统事件
- 进程间通信 (基于 Unix 套接字或有名管道)
- 子进程
- 线程池
- 信号处理
- 高精度时钟
- 线程和同步

## 异步模型

Node.lua 和 Node.js 一样, 隐藏了事件循环的相关调用代码, 而是在执行 Lua 脚本时默认就进入了事件循环, 直到所有的工作或回调函数都执行完后就自动退出进程. 这个和浏览器的执行环境很相似.

### 组塞

当执行组塞的方法时, Node.lua 进程必须等到这个方法完成, 这样的话事件循环就无法继续运行其他 Lua 代码.

Node.lua 使用 libuv 实现的所有 I/O 方法都默认提供异步的方法, 并且接受回调函数. 但是一些方方法通常也有同步的版本, 它们一般以 Sync 结尾.

下面的代码是同步的代码:

```js
const fs = require('fs');
const data = fs.readFileSync('/file.md'); // 一直组塞在这里直到读取完成
console.log(data);
// moreWork(); 将在 console.log 后执行
```

下面的代码是异步的代码:

```js
const fs = require('fs');
fs.readFile('/file.md', (err, data) => {
  if (err) throw err;
  console.log(data);
});
// moreWork(); 将在 console.log 前执行
```

在上面的例子中, 因为 `readFile` 是非组塞的, 所以会继续马上执行 `moreWork` 方法, 而不需要等待读取文件的完成.

Node.lua 在一个单线程中执行 Lua 代码, 回调函数会在完成当前所有工作后, 在下一个事件循环后被执行, 所以它的并发工作模式和其他基于多线程的模式是很不一样的. 所以需要尽量选择异步方法而不是同步方法, 这样才能最大限度利用 CPU.

同时在异步编程中也要注意代码的执行顺序以免发生运行错误.

