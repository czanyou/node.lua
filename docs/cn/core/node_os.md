# 系统 (os)



这是系统内置模块, 可以直接调用

## os.arch

系统所在机器的体系类型, 如 `arm`,`x64` 等.

## os.clock

当前程序使用的 CPU 时间, 单位为秒.

## os.cpus

系统所在机器 CPU 信息

## os.date

    os.date([format [, time]])

返回以字节符或表格型式表示的系统当前日期和时间

- format {String} 日期格式字符串, 如果为 '*t' 则返回一个表示时间的表格
- time {Number} 要格式化的时间, 如果没有指定则为当前时间

## os.difftime

    difftime(t1, t2)

返回当前时间的差值

## os.endianness


## os.EOL

系统行终止字符串

## os.execute

    os.execute ([command])

执行外部程序, 相当于 C 语言的 system, 能执行的命令依赖于所在的系统.


## os.exit

    os.exit(code)

退出当前进程

- code {Number} 进程返回值

相当于调用 C 语言的 exit 方法.

## os.freemem

系统当前空闲内存大小, 单位为字节

## os.getenv

返回指定名称的环境变量的值

## os.homedir

系统当前用户主目录

## os.loadavg

系统当前负载

## os.networkInterfaces

系统网络接口信息

## os.platform

系统平台类型, 如 `linux`,`darwin`,`windows` 等

## os.release


## os.remove

    os.remove(filename)

删除文件或空目录

- filename 要删除的文件名或目录名

如果失败则返回 nil 以及一个错误信息字符符


## os.rename

    os.rename(oldname, newname)

重命令或移动文件

- oldname 旧文件名
- newname 新文件名

如果失败则返回 nil 以及一个错误信息字符符

## os.setlocale

    os.setlocale (locale [, category])

设置程序的区域位置

## os.time

返回系统时间, 通常为从 1970-1-1 以来经过的秒数.

    os.time([table])

- table {Object} 要换算的时间和日期, 如果没有指定则返回当前时间

当指定了 table 参数时必须包含有 year, month 和 day 字段, 也可以选择包含 hour, min, sec, isdst 等字段. 

其他请参考 `os.date()` 方法

## os.tmpdir

返回临时目录名

## os.tmpname

返回一个随机的临时文件名

## os.totalmem

系统当前总共内存大小, 单位为字节

## os.type

系统类型, 同 platform

## os.uptime

系统启动时间, 从系统启动以来经过的秒数.
