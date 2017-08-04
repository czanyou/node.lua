# lpm 后台服务管理原理

[TOC]

本文主要描述了 lpm 如何管理后台运行的 APP 程序.

因为我们的主要目的是在嵌入式 linux 下实现传感器数据采集的, PC 以及 MAC 只是做为开发平台, 
所以本文涉及到的后台应用管理的部分功能只在 linux 平台下有效.

## 相关的 lpm 命令

- lpm ps 打印当前正在运行的 Node.lua APP 进程
- lpm kill [name]  杀掉正在运行的指定名称的 APP 进程
- lpm daemon [name] 在后台启动指定名称应用的守护进程
- lpm stop [name] 停止在后台运行的 lhost 进程守护服务
- lpm lhost list 同 lpm ps
- lpm lhost kill 同 lpm kill
- lpm lhost stop 同 lpm stop

## 关于 Shell 会话

在 linux 下, 用户通过终端或 ssh 等登录的主机后, 会产生一个 shell 会话, 在这个会话下启动的
程序在用户退出 shell 会话时, 都会被系统中止运行.

如果想要一个程序一直在后台运行直到关机, 必须让它运行在 daemon 模式

lnode 已经内置支持 daemon 模式, 我们想要一个 lua 程序能在 daemon 模式运行, 需要在执行时
添加 `-d` 的运行参数

比如:

```lua
local utils = require('utils')

function daemon(mode)
    local filename = utils.filename()
    local cmdline  = "lnode -d " .. filename .. " start"
    print('daemon', cmdline)
    os.execute(cmdline)
end

```

这段脚本会以 daemon 的模式重新运行当前脚本, 这时当前进程可以退出, 而一个新的 daemon 进程会启动,
并一直会在后台运行直到关机.

## 在开机时自动运行

由于每个 linux 发行版都有差异, 所以没有一种统一的让程序在开机时自动运行的方法.

但总的来讲, linux 启动后都会调用 /etc/init.d/rcS 脚本, 由 rcS 再调用其他初始化脚本, 比如在 
Raspberry Pi 系统下的 /etc/rc.local 就会被调用, 可以用来在开机时自动运行一些程序

## daemon 模式原理

由于 linux 启动一个新进程时, 会自动绑定到当前用户和当前会话, 而要进入 daemon 模式, 就是要解除
这个绑定, 使进程和当前用户会话无关, 主要用到了 linux 的 fork 指令. 因为是类 linux 独有的 API,
所以 Windows 下不会有这个概念.

下面是实现细节:

```java
/** 让当前程序进入后台运行, Windows 下无效. */
LUALIB_API int lnode_run_as_deamon() {
#ifndef WIN32
  if (fork() != 0) {
    exit(1);
  }

  // 创建新的进程会话, 并脱离当前 Shell 终端, 使新的进程可以在后台独立运行.
  if (setsid() < 0) {
    exit(1);
  }

  if (fork() != 0) {
    exit(1);
  }

  umask(022);

  signal(SIGCHLD, SIG_IGN);
#endif

  return 0;
}
```

linux 下存进程树的概念, 在当前 shell 下启动的进程将都是它的子进程, 一旦 shell 本身退出, 所有
它的子孙进程都会自动关闭, 通过调用 setsid 方法可以解脱父子关闭, 使新的进程可以独产运行.

## lpm 查看正在运行的 APP 原理

因为所有 Lua 程序都是通过 lnode 运行的, 所以通过系统 ps 工具看不到到底是执行的哪个脚本, lpm 
会去查看 /proc/[pid]/cmdline 的内容, 从而了解到 lnode 实际是调用的哪个脚本

相关功能没有内置在 lpm 中, 而是通过 lhost.app 这个应用实现的:

```lua

local function getAppName(cmdline)
    local _, _, appName = cmdline:find('lnode.+/([%w]+).app/init.lua')

    if (not appName) then
        _, _, appName = cmdline:find('lnode.+/lpm%S([%w]+)%Sstart')
    end

    if (not appName) then
        _, _, appName = cmdline:find('lnode.+/lpm%Sstart%S([%w]+)')
    end

    return appName
end

function exports.list()
    local files = fs.readdirSync('/proc') or {}
    local count = 0
    for _, file in ipairs(files) do
        local pid = tonumber(file)
        if (not pid) then
            goto continue
        end

        local filename = path.join('/proc', tostring(pid), 'cmdline')
        if not fs.existsSync(filename) then
            goto continue
        end

        local cmdline = fs.readFileSync(filename) or ''
        local name = getAppName(cmdline)
        --print(cmdline)

        if (name) then
            count = count + 1
            print(name, pid)
        end

        ::continue::
    end

    if (count < 1) then
        print('no application process found!')
    end
end

```

如上所述, lpm 通过历遍所以 lnode 进程, 并通过它的启动参数来判断是运行的哪一个 app 程序.

## 如何让 APP 支持 daemon 模式

在 app 的 init.lua 中导出中实现 start 方法即可:

如 test.app/init.lua 中添加如下的代码:

```lua
function exports.start(...)
    -- 进入事件循环
end
```

在命令行下通过 `lpm daemon test` 就可以进入 daemon 模式运行

## 关于守护进程

上面的方法只会让程序在后台运行不会被自动关闭, 而如果是程序本身的问题意外退出, 则不会自动重启.

所以我们又实现了另外一种更复杂的后台运行机制:

首先运行 lhost 这个 APP, 再由 lhost 运行其他 APP, lhost 会监控其他进程并自动重启意外退出的进程.

lhost 还同时运行一个 IPC 服务器, lpm 可以通过 IPC 和它通信, 用来随时添加新的要监控的服务
或者退出并停止监控的指定的服务

你可以通过 `lpm daemon lhost` 在后台运行这个服务

然后通过 `lpm daemon [name]` 来启动新的服务

或者通过 `lpm stop [name]` 来停止这个服务

如果你通过 `lpm kill [name]` 杀死了这个服务, 还是会被 lhost 自动重启, 你必须用 stop 才能完全终止它.



