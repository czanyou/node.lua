# 嵌入式 Linux 开发基础

[TOC]

## 嵌入式 Linux 镜像

嵌入式 Linux 镜像文件主要由 3 部分组成:

- boot
- 内核
- 根文件系统

## uboot

开机时首先被加载和执行, 可以按任意键进入 uboot 控制台.

uboot 完成后会读取并解压 linux 内核到内存中, 并开始运行 linux 内核.

## linux 内核

Linux 内核包含操作系统核心模块以及驱动程序. Linux 内核采用的是模块化的设计, 
支持裁减和动态加载. 即部分内核功能可编译成动态模块并保存在文件系统中, 
可在系统启动后需要的时候再加载到内核中.

嵌入式 Linux 内核启动后第一个被执行的进程通常是 init, 它的 pid 是 1. 其他进程都是由
init 再直接或间隔启动的.议

## 根文件系统

Linux 只支持单一树结构的文件系统, 不支持 Windows 类似的盘符方式.

根文件系统表示挂接在 '/' 目录的文件系统.

其他分区或存储器通常挂接在 /mnt 或 /media 目录下

嵌入式 Linux 文件系统主要分为只读和可读写两种, 采用只读的文件系统可以更节省空间以及防止程序被篡改.

通常嵌入式 Linux 只考虑 Flash 存储介质, 所有一般也常使用 romfs 以及 jffs 等 Flash 专用文件系统.

当使用外接 SD 卡或 U 盘时, 会用到 fat32 以及 ext3 等类型的文件系统.

### 特殊文件系统

嵌入式 Linux 还包含一些常用的特殊文件系统:

- devfs 设备文件系统, 挂接在目录 /dev, 用来访问设备以及驱动程序, 如鼠标键盘, 显卡, 摄像头等等...
- tmpfs 使用内存作为文件系统, 通常挂接在 /tmp 等目录下, 用来存放系统运行时的临时文件, 断电后会丢失.
- proc 这个是内核和应用程序通信的接口, 常可以用来读取很多系统信息
- sysfs 这是另一个内核和应用程序通信的接口, 如 gpio 驱动

### 常见的文件夹

- /bin 系统级别所有用户可以调用的可执行文件
- /sbin 系统级别专供超级管理员调用的可执行文件, 主要是一些系统配置工具
- /usr/bin 所有用户可以调用的可执行文件
- /usr/sbin 专供超级管理员调用的可执行文件, 主要是一些系统配置工具
- /boot 启动文件目录, 嵌入式 linux 一般用不到, 因为 uboot 和内核不放在文件系统中
- /lib 动态链接库文件
- /usr/lib 动态链接库文件
- /tmp/ 临时文件
- /proc proc 文件系统
- /dev 设备文件系统
- /sysfs sysfs 文件系统
- /home 用户主目录, 嵌入式 linux 一般用不到
- /root 根用户主目录, 嵌入式 linux 一般也不放内容
- /mnt 挂接目录
- /media 同上
- /var 可变数据目录, 如网页文件等
- /var/run 正在运行的进程的信息, 如 pid 文件
- /etc 系统配置文件
- /etc/init.d 系统初始化脚本目录 
- /

## 用户和组

嵌入式 Linux 默认通常使用 root 账号

可以通过 passwd 修改登录密码

## 本地终端

嵌入式 Linux 通常使用 debug 口访问本地终端

## 远程终端

比较精简的嵌入式 Linux 通常使用 telnet 协议和 telnetd 服务器程序实现远程终端服务

直接在开发板运行 telnetd 即可, 客户端通过 telnet 协议连接.

比较好的系统会支持 ssh 协议

## minicom



## shell

- ash
- bash
- csh
- dash
- ...

/bin/sh 

## busybox

瑞士军刀

## route 命令

route 用来维护嵌入式 Linux 路由表, 在一些非常精简的 linux 系统中经常用到.

删除指定的默认网关, 一般只能有一个默认网关存在, 否则会导致上网问题.

`route del default gw 0.0.0.0 dev {facename}`

`route add default gw 192.168.1.1 dev eth0 metric 1`

## DNS 服务

## 常用命令

查看内存占用

$ free

实时查看占用 CPU 和内存最高的进程

$ top

查看所有进程

$ ps -A 

在当前会话执行指定的 shell 脚本, 否则会创建一个子会话来运行, 这样脚本可以用来修改当前会话的环境变量.

$ source shell.sh

查看或修改环境变量

$ export 
$ export KEY=VALUE

查看指定的可执行文件所在的目录

$ whereis command

创建文件链接, 非常好用的功能

$ ln -s /target /name

查看当前目录文件详细信息

$ ls -l 

复制指定的文件夹或文件, 包含子目录

$ cp -rf /path /dest

强制删除指定的文件夹

$ rm -rf /path

创建指定的目录, 包含不存在的上级目录

$ mkdir -p /path

查看剩余空间:

$ df -h

查看当前目录下文件和子目录占用空间

$ du -d 1

查找指定名称的文

$ find

查看当前所在的目录

$ pwd

## samba fs 文件共享

安装软件

$ sudo apt-get update
$ sudo apt-get -y install samba samba-common

创建共享

$ sudo gedit /etc/samba/smb.conf

```
[main]
   comment = Main
   path = /home
   browseable = yes
   writable = yes
   guest ok = no

```

创建用户

$ sudo useradd samba
$ sudo smbpasswd -a samba
$ sudo service smbd restart

这个时候就可以使用 samba/samba 访问了

## gdb


| 命令          | 解释  | 示例
| ---           | --- | ---
| file <文件名> | 加载被调试的可执行程序文件。因为一般都在被调试程序所在目录下执行 GDB，因而文本名不需要带路径。 |  (gdb) file gdb-sample
| r             | Run 的简写，运行被调试的程序。如果此前没有下过断点，则执行完整个程序；如果有断点，则程序暂停在第一个可用断点处。  |  (gdb) r
| c             | Continue 的简写，继续执行被调试程序，直至下一个断点或程序结束。 | (gdb) c
| b <行号><br/> b <函数名称><br/> b \*<函数名称><br/> b \*<代码地址><br/> d [编号] | b: Breakpoint的简写，设置断点。两可以使用“行号”“函数名称”“执行地址”等方式指定断点位置。其中在函数名称前面加“*”符号表示将断点设置在“由编译器生成的prolog代码处”。如果不了解汇编，可以不予理会此用法。d: Delete breakpoint的简写，删除指定编号的某个断点，或删除所有断点。断点编号从 1 开始递增。| (gdb) b 8<br/> (gdb) b main<br/> (gdb) b *main<br/> (gdb) b *0x804835c<br/> (gdb) d
| s, n          | s: 执行一行源程序代码，如果此行代码中有函数调用，则进入该函数；n: 执行一行源程序代码，此行代码中的函数调用也一并执行。s 相当于其它调试器中的“Step Into (单步跟踪进入)”；n 相当于其它调试器中的“Step Over (单步跟踪)”。这两个命令必须在有源代码调试信息的情况下才可以使用（GCC编译时使用“-g”参数）。| (gdb) s (gdb) n
| si, ni        | si命令类似于s命令，ni命令类似于n命令。所不同的是，这两个命令（si/ni）所针对的是汇编指令，而s/n针对的是源代码。  | (gdb) si (gdb) ni
| p <变量名称>   | Print的简写，显示指定变量（临时变量或全局变量）的值。   | (gdb) p i (gdb) p nGlobalVar
| display ... undisplay <编号> | display，设置程序中断后欲显示的数据及其格式。例如，如果希望每次程序中断后可以看到即将被执行的下一条汇编指令，可以使用命令 “display /i $pc” 其中 $pc 代表当前汇编指令，/i 表示以十六进行显示。当需要关心汇编代码时，此命令相当有用。undispaly，取消先前的display设置，编号从1开始递增。| (gdb) display /i $pc (gdb) undisplay 1
| i            | Info 的简写，用于显示各类信息，详情请查阅“help i”。 | (gdb) i r
| q            | Quit 的简写，退出 GDB 调试环境。  | (gdb) q
| help [命令名称] | GDB 帮助命令，提供对GDB名种命令的解释说明。如果指定了“命令名称”参数，则显示该命令的详细说明；如果没有指定参数，则分类显示所有GDB命令，供用户进一步浏览和查询。    | (gdb) help display


- bt 显示当前堆栈
- info threads 所有线程
- info types 显示所有类型
- info scope 


