# 进程 (process)

[TOC]

process 对象是一个全局对象，可以在任何地方访问到它。它是 EventEmitter 的一个实例。

## 事件: 'exit'

当进程将要退出时触发。这是一个在固定时间检查模块状态（如单元测试）的好时机。需要注意的是 'exit' 的回调结束后，主事件循环将不再运行，所以计时器也会失效。

监听 exit 事件的例子：

```lua
process:on('exit', function() 
  -- 设置一个延迟执行
  setTimeout(0, function()
    print('主事件循环已停止，所以不会执行')
  end)
  print('退出前执行')
end)
```


## Signal Events

当进程接收到信号时触发。信号列表详见 POSIX 标准的 sigaction（2）如 SIGINT、SIGUSR1 等。

监听 SIGINT 信号的示例：

```lua
-- 设置 'SIGINT' 信号触发事件
process:on('SIGINT', function() 
  print('收到 SIGINT 信号。退出请使用 Ctrl + D ')
end)
```

在大多数终端下，一个发送 SIGINT 信号的简单方法是按下 ctrl + c 。


## process.abort

    process.abort()

这将导致 Node 触发一个 abort 事件，这会导致 Node 退出并且创建一个核心文件。


## process.arch

返回当前 CPU 处理器的架构：'arm'、'ia32' 或者 'x64'.


## process.argv

一个包含命令行参数的数组。第一个元素会是 'node'， 第二个元素将是 .Js 文件的名称。接下来的元素依次是命令行传入的参数。


## process.chdir

    process.chdir(directory)

改变进程的当前进程的工作目录，若操作失败则抛出异常。


## process.cwd

    process.cwd()

返回进程当前的工作目录。


## process.env

一个包括用户环境的对象。详细参见 environ(7)。


## process.execPath

开启当前进程的这个可执行文件的绝对路径。

实例：

    /usr/local/bin/lnode 


## process.exit

    process.exit([code])

终止当前进程并返回给定的 code。如果省略了 code，退出是会默认返回成功的状态码('success' code) 也就是 0。

退出并返回失败的状态 ('failure' code):

    process.exit(1)

执行上述代码，用来执行 node 的 shell 就能收到值为 1 的 exit code


## process.exitCode

当进程既正常退出，或者通过未指定 code 的 process.exit() 退出时，这个属性中所存储的数字将会成为进程退出的错误码 (exit code)。

如果指名了 process.exit(code) 中退出的错误码 (code)，则会覆盖掉 process.exitCode 的设置。


## process.getgid

    process.getgid()

注意： 该函数仅适用于遵循 POSIX 标准的系统平台如 Unix、Linux等 而 Windows、 Android 等则不适用。

获取进程的群组标识（详见getgid(2)）。获取到的是群组的数字ID，不是群组名称。


## process.getuid

    process.getuid()

注意： 该函数仅适用于遵循 POSIX 标准的系统平台如 Unix、Linux等 而 Windows、 Android 等则不适用。

获取执行进程的用户ID（详见getgid(2)）。这是用户的数字ID，不是用户名。


## process.hrtime

    process.hrtime()

返回当前的高分辨时间，单位为 1/1000000000 秒。它是相对于在过去的任意时间。该值与日期无关，因此不受时钟漂移的影响。主要用途是可以通过精确的时间间隔，来衡量程序的性能。

你可以将前一个 process.hrtime() 的结果传递给当前的 process.hrtime() 函数，结果会返回一个比较值，用于基准和衡量时间间隔。


## process.kill

    process.kill(pid, [signal])

向进程发送一个信号。 pid 是进程的 id 而 signal 则是描述信号的字符串名称。信号的名称都形似 'SIGINT' 或者 'SIGUSR1'。如果没有指定参数则会默认发送 'SIGTERM' 信号，更多信息请查看 kill(2) 。

值得注意的是，这个函数的名称虽然是 process.kill， 但就像 kill 系统调用（详见《Unix高级编程》）一样，它仅仅只是一个信号发送器。而信号的发送不仅仅只是用来杀死（kill）目标进程。

向当前进程发送信号的示例：

    process.kill(process.pid, 'SIGHUP'); 


## process.memoryUsage

    process.memoryUsage()

返回一个对象，它描述了 Node 进程的内存使用情况单位是 bytes。


## process.nextTick

    process.nextTick(callback)

- callback {Function}

在事件循环的下一次循环中调用 callback 回调函数。


## process.pid

当前进程的 PID


## process.platform

返回当前进程运行的平台：'darwin', 'freebsd', 'linux', 'sunos' 或者 'win32'


## process.setgid

    process.setgid(id)

注意： 该函数仅适用于遵循 POSIX 标准的系统平台如 Unix、Linux等 而 Windows、 Android 等则不适用。

设置进程的群组标识（详见getgid(2)）。参数可以是一个数字 ID 或者群组名字符串。如果指定了一个群组名，这个方法会阻塞等待将群组名解析为数字 ID。


## process.setuid

    process.setuid(id)

注意： 该函数仅适用于遵循 POSIX 标准的系统平台如 Unix、Linux等 而 Windows、 Android 等则不适用。

设置执行进程的用户ID（详见getgid(2)）。参数可以使一个数字 ID 或者用户名字符串。如果指定了一个用户名，那么该方法会阻塞等待将用户名解析为数字ID。


## process.stderr

一个指向标准错误流(stderr)的 可写的流(Writable Stream)。

process.stderr 和 process.stdout 不像 Node 中其他的流(Streams) 那样，他们通常是阻塞式的写入。当其引用指向 普通文件 或者 TTY文件描述符 时他们就是阻塞的（注：TTY 可以理解为终端的一种，可联想 PuTTY，详见百科）。当他们引用指向管道(pipes)时，他们就同其他的流(Streams)一样是非阻塞的。


## process.stdin

一个指向 标准输入流(stdin) 的可读流(Readable Stream)。标准输入流默认是暂停 (pause) 的，所以必须要调用 process.stdin.resume() 来恢复 (resume) 接收。

打开标准输入流，并监听两个事件的示例：

```lua
process.stdin:on('end', function()
  process.stdout:write('end')
end)


// gets 函数的简单实现
function gets(cb) {
  process.stdin:resume()

  process.stdin:on('data', function(chunk) 
     process.stdin:pause()
     cb(chunk)
  end)
end

gets(function(reuslt)
  print("["+reuslt+"]");
end);
```

## process.stdout

一个指向标准输出流(stdout)的 可写的流(Writable Stream)。

举例: print 的实现

```lua
print = function(d) {
  process.stdout:write(d + '\n');
}; 
```

process.stderr 和 process.stdout 不像 Node 中其他的流(Streams) 那样，他们通常是阻塞式的写入。当其引用指向 普通文件 或者 TTY文件描述符 时他们就是阻塞的（注：TTY 可以理解为终端的一种，可联想 PuTTY，详见百科）。当他们引用指向管道(pipes)时，他们就同其他的流(Streams)一样是非阻塞的。


## process.umask

    process.umask([mask])

设置或者读取进程的文件模式的创建掩码。子进程从父进程中继承这个掩码。如果设定了参数 mask 那么返回旧的掩码，否则返回当前的掩码。


## process.uptime

    process.uptime()

返回当前 Node 进程已运行的秒数。


## process.version

返回 Node.lua 的版本的字符串


## process.versions

返回一个对象类型，包含 Node 以及其依赖的包的版本信息。

输出的信息大概如下:

```lua
{
  node: '1.1.1',
  uv: '1.3.0'
}
```

