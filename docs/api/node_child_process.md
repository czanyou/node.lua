# 子进程 (child process)

[TOC]

Node 通过 child_process 模块提供了类似 popen(3) 的处理三向数据流 (stdin/stdout/stderr) 的功能. 

通过 require('child_process') 调用

它能够以完全非阻塞的方式与子进程的 stdin、stdout 和 stderr 以流式传递数据.  (请注意, 某些程序在内部使用行缓冲 I/O. 这不会影响到 node, 但您发送到子进程的数据不会被立即消费. ) 

## 类: ChildProcess

ChildProcess 是一个 EventEmitter. 

子进程有三个与之关联的流: child.stdin、child.stdout 和 child.stderr. 它们可能会共享父进程的 stdio 流, 也可以作为独立的被导流的流对象. 

ChildProcess 类不能直接被使用, 使用 spawn(), exec() 等方法创建 ChildProcess 类的实例. 

### 事件: 'close'

- code {Number} 假如进程正常退出, 则为它的退出代码. 
- signal {String} 假如是被父进程终止, 则为所传入的终止子进程的信号. 

这个事件会在一个子进程的所有 stdio 流被终止时触发, 这和'exit'事件有明显的不同, 因为多进程有时候会共享同一个 stdio 流

### 事件: 'disconnect'

在子进程或父进程中使用使用 `.disconnect()` 方法后, 这个事件会被触发, 在断开之后, 就不可能再相互发送信息了. 可以通过检查子进程的 child.connected 属性是否为 true 去检查是否可以发送信息

### 事件: 'error'

- err {Error Object} 错误. 

发生于: 

- 进程不能被创建, 或者
- 进程不能被终止掉, 或者
- 由任何原因引起的数据发送到子进程失败.

### 事件: 'exit'

- code {Number} 假如进程正常退出, 则为它的退出代码. 
- signal {String} 假如是被父进程终止, 则为所传入的终止子进程的信号. 

这个事件是在子进程被结束的时候触发的. 假如进程被正常结束, 'code' 就是退出进程的指令代码, 否则为 'null'. 假如进程是由于接受到 signal 结束的, signal 就代表着信号的名称, 否则为 null.

注意子进程的 stdio 流可能仍为开启状态. 

参阅 waitpid(2).

### 事件: 'message'

TODO: 暂未实现

- message {Object} 一个已解析的 JSON 对象或者原始类型值
- sendHandle {Handle object} 一个socket 或者 server对象

通过 .send() 发送的信息可以通过监听 'message' 事件获取到

### 属性: child.pid

{Number} 子进程的PID

### 属性: child.stderr

{Stream Object} 子进程的 stderr 是一个可读流

假如子进程的 stdio 流与父进程共享, 这个 child.stderr 不会被设置

### 属性: child.stdin

{Stream Object} 子进程的 'stdin' 是一个 '可写流' , 通过 end() 方法关闭该可写流可以终止子进程, 

假如子进程的 stdio 流与父进程共享, 这个 child.stdin 不会被设置

### 属性: child.stdout

{Stream Object} 子进程的 stdout 是个可读流.

假如子进程的 stdio 流与父进程共享, 这个 child.stdout 不会被设置

### child.disconnect

    child.disconnect()

使用 child.disconnect() 方法关闭父进程与子进程的 IPC 连接. 他让子进程非常优雅的退出, 因为已经没有活跃的 IPC 信道. 当调用这个方法,  'disconnect' 事件将会同时在父进程和子进程内被触发, 'connected' 的标签将会被设置成 'flase', 请注意, 你也可以在子进程中调用 'process.disconnect()' 

### child.kill

    child.kill([signal])

发送一个信号给子线程. 假如没有给参数, 将会发送 'SIGTERM'. 参阅 signal(7) 查看所有可用的 signals 列表

当一个 signal 不能被传递的时候, 会触发一个 'error' 事件,  发送一个信号到已终止的子线程不会发生错误, 但是可能引起不可预见的后果,  假如该子进程的 ID 已经重新分配给了其他进程, signal 将会被发送到其他进程上面, 大家可以猜想到这发生什么后果. 

注意, 当函数调用 'kill', 传递给子进程的信号不会去终结子进程, 'kill' 实际上只是发送一个信号到进程而已. 

### child.send

    child.send(message, [sendHandle])

TODO: 暂未实现

当使用 child_process.fork() 你可以使用 child.send(message, [sendHandle])向子进程写数据, 数据将通过子进程上的 'message' 事件接受.

## child_process.exec

    child_process.exec(command, [options], callback)

- command {String} 将要执行的命令, 用空格分隔参数
- options {Object}
    + cwd {String} 子进程的当前工作目录
    + env {Object} 环境变量键值对
    + shell {String} 运行命令的 shell (UNIX 上缺省为 '/bin/sh', Windows 上缺省为 'cmd.exe'. 该 shell 在 UNIX 上应当接受 -c 开关, 在 Windows 上应当接受 /s /c 开关. 在 Windows 中, 命令行解析应当兼容 cmd.exe. ) 
    + timeout {Number} 超时 (缺省为 0) 
    + maxBuffer {Number} 最大缓冲 (缺省为 200*1024) 
    + killSignal {String} 结束信号 (缺省为 'SIGTERM') 
- callback {Function} 进程结束时回调并带上输出
    + error {Error}
    + stdout {String}
    + stderr {String}
- 返回: ChildProcess 对象

在 shell 中执行一个命令并缓冲输出. 

回调参数为 (error, stdout, stderr). 当成功时, error 会是 nil. 当遇到错误时, error 会是一个 Error 实例, 并且 err.code 会是子进程的退出代码, 同时 err.signal 会被设置为结束进程的信号名. 

第二个可选的参数用于指定一些选项.

如果 timeout 大于 0, 则当进程运行超过 timeout 毫秒后会被终止. 子进程使用 killSignal 信号结束 (缺省为 'SIGTERM') . maxBuffer 指定了 stdout 或 stderr 所允许的最大数据量, 如果超出这个值则子进程会被终止. 

## child_process.execFile

    child_process.execFile(file, args, options, callback)

- file {String} 要运行的程序的文件名
- args {Array} 字符串参数列表
- options {Object}
    + cwd {String} 子进程的当前工作目录
    + env {Object} 环境变量键值对
    + timeout {Number} 超时 (缺省为 0) 
    + maxBuffer {Number} 最大缓冲 (缺省为 200*1024) 
    + killSignal {String} 结束信号 (缺省为 'SIGTERM') 
- callback {Function} 进程结束时回调并带上输出
    + error {Error}
    + stdout {Buffer}
    + stderr {Buffer}
- 返回: ChildProcess 对象

该方法类似于 child_process.exec(), 但是它不会执行一个子 shell, 而是直接执行指定的文件. 因此它稍微比 child_process.exec 精简, 参数与之一致. 

## child_process.fork

TODO: 暂未实现

    child_process.fork(modulePath, [args], [options])

- modulePath {String} 子进程中运行的模块
- args {Array} 字符串参数列表
- options {Object}
    + cwd {String} 子进程的当前工作目录
    + env {Object} 环境变量键值对
    + execPath {String} 创建子进程的可执行文件
- 返回: ChildProcess 对象

该方法是 spawn() 的特殊情景, 用于派生 Node 进程. 除了普通 ChildProcess 实例所具有的所有方法, 所返回的对象还具有内建的通讯通道. 详见 `child.send(message, [sendHandle])`. 

缺省情况下所派生的 Node 进程的 stdout、stderr 会关联到父进程. 要更改该行为, 可将 options 对象中的 `silent` 属性设置为 true. 

子进程运行完成时并不会自动退出, 您需要明确地调用 `process.exit()`. 该限制可能会在未来版本里接触. 

这些子 Node 是全新的实例, 假设每个新的 Node 需要至少 30 毫秒的启动时间和 10MB 内存, 就是说您不能创建成百上千个这样的实例. 

options 对象中的 execPath 属性可以用非当前 node 可执行文件来创建子进程. 这需要小心使用, 并且缺省情况下会使用子进程上的 NODE_CHANNEL_FD 环境变量所指定的文件描述符来通讯. 该文件描述符的输入和输出假定为以行分割的 JSON 对象. 

## child_process.spawn

    child_process.spawn(command, [args], [options])

- command {String} 要运行的命令
- args {Array} 字符串参数列表
- options {Object}
    + cwd {String} 子进程的当前的工作目录
    + stdio {Array|String} 子进程 stdio 配置. (参阅下文)
    + env {Object} 环境变量的键值对
    + detached {Boolean} 子进程将会变成一个进程组的领导者. (参阅下文)
    + uid {Number} 设置用户进程的 ID. (See setuid(2))
    + gid {Number} 设置进程组的 ID. (See setgid(2))
- 返回: {ChildProcess} 对象

用给定的命令发布一个子进程, 带有 'args' 命令行参数, 如果省略的话,  'args' 默认为一个空数组

第三个参数被用来指定额外的设置

cwd 允许你从被创建的子进程中指定一个工作目录. 使用 env 去指定在新进程中可用的环境变量.

如果 detached 选项被设置, 则子进程会被作为新进程组的 leader. 这使得子进程可以在父进程退出后继续运行. 

缺省情况下, 父进程会等待脱离了的子进程退出. 要阻止父进程等待一个给出的子进程 child, 使用 child.unref() 方法, 则父进程的事件循环引用计数中将不会包含这个子进程. 

当使用 detached 选项来启动一个长时间运行的进程, 该进程不会在后台保持运行, 除非向它提供了一个不连接到父进程的 stdio 配置. 如果继承了父进程的 stdio, 则子进程会继续附着在控制终端. 





