# 承诺 (promise)

Promise 对象用于表示一个异步操作的最终状态（完成或失败），以及其返回的值

## 状态

Promise 有以下三种状态:

- pending: 初始状态，既不是成功，也不是失败状态 , ( 等待中 , 或者进行中 , 表示还没有得到结果 )

- fulfilled: 意味着操作成功。

- rejected: 意味着操作失败。

Promise 有两种状态改变的方式，而且状态只能从 pending 改变为 resolved 或者 rejected，并且不可逆。当状态发生变化，Promise.next 绑定的函数就会被调用。

## 类 Promise

### promise:next

> promise:next(onFulfilled, [onRejected])

next() 方法执行后会返回一个新的 Promise 实例。

- onFulfilled `{function(value:any)}` 操作成功完成时要运行的履行处理程序函数。且返回值将作为参数传入这个新 Promise 的 resolve 函数。
- onRejected `function(reason:any)` 操作被拒绝时要运行的错误处理程序函数。

它有两个参数，分别为：Promise 从 pending 变为 fulfilled 和 rejected 时的回调函数（第二个参数非必选）。这两个函数都接受 Promise 对象传出的值(data)作为参数。

- 如果 next 没有传入处理函数，那么会返回一个继承了上一个处理状态的 Promise 对象
- 如果 next 传入处理函数，那么默认返回一个 fulfilled/resolved 状态的 Promise 对象
- 如果 next 传入处理函数，通过处理函数显式地 return 了一个新的 Promise，那么返回这个显式的 Promise 对象

### promise:catch

> promise:catch(onRejected)

处理 rejected 的情况，与 next 的第二个参数 onRejected 相同

- onRejected `function(reason:any)`

注意:

- .catch 与 .next 中的 onRejected 函数冲突，如果前面 .next 中出行了 onRejected 函数，.catch 将不会执行。
- .catch 执行后会返回一个 Promise 对象，且状态默认为 fulfilled/resolved（与.next相似）

### promise:resolve

> promise:resolve(value)

进入 aresolved 状态

- value Promise|any 执行结果

### promise:reject

> promise:reject(reason)

进入 rejected 状态

- reason 错误原因

## promise.new

> promise.new(function(resolve, reject) end)

Promise接受一个「函数」作为参数，该函数的两个参数分别是 resolve 和 reject。这两个函数就是就是「回调函数」

- resolve `{function(value:any)}` 函数的作用：在异步操作成功时调用，并将异步操作的结果，作为参数传递出去； 
- reject `function(reason:any)` 函数的作用：在异步操作失败时调用，并将异步操作报出的错误，作为参数传递出去。

## promise.all

> promise.all(...)

需要等待所有 promise 执行完成

## promise.race

> promise.race(...)

只需要等待任意一个 promise 执行完成