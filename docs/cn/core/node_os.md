# 系统 (os)

这是系统内置模块, 可以直接调用

## os.arch

> os.arch()

系统所在机器的体系类型, 如 `arm`,`x64` 等.

## os.cpus

> os.cpus()

系统所在机器 CPU 信息

## os.EOL

> os.EOL

系统行终止字符串

## os.freemem

> os.freemem()

系统当前空闲内存大小, 单位为字节

## os.getenv

> os.getenv (varname)

返回进程环境变量 varname 的值， 如果该变量未定义，返回 nil 。

## os.homedir

> os.homedir()

系统当前用户主目录

## os.loadavg

> os.loadavg()

系统当前负载

## os.networkInterfaces

> os.networkInterfaces()

系统网络接口信息

## os.platform

> os.platform()

系统平台类型, 如 `linux`,`darwin`,`windows` 等

## os.tmpdir

> os.tmpdir

返回临时目录名

## os.tmpname

> os.tmpname()

返回一个可用于临时文件的文件名字符串。 这个文件在使用前必须显式打开，不再使用时需要显式删除。

在 POSIX 系统上， 这个函数会以此文件名创建一个文件以回避安全风险。 （别人可能未经允许在获取到这个文件名到创建该文件之间的时刻创建此文件。） 你依旧需要在使用它的时候先打开，并最后删除（即使你没使用到）。

只有有可能，你更应该使用 io.tmpfile， 因为该文件可以在程序结束时自动删除。

## os.totalmem

> os.totalmem()

系统当前总共内存大小, 单位为字节

## os.type

> os.type()

系统类型, 同 platform

## 操作

### os.execute

> os.execute ([command])

这个函数等价于 ISO C 函数 system。 它调用系统解释器执行 command。 如果命令成功运行完毕，第一个返回值就是 true， 否则是 nil otherwise。 在第一个返回值之后，函数返回一个字符串加一个数字。如下：

"exit": 命令正常结束； 接下来的数字是命令的退出状态码。
"signal": 命令被信号打断； 接下来的数字是打断该命令的信号。
如果不带参数调用， os.execute 在系统解释器存在的时候返回真。

### os.exit

> os.exit([code [, close]])

- code `{number}` 进程返回值

调用 ISO C 函数 exit 终止宿主程序。 如果 code 为 true， 返回的状态码是 EXIT_SUCCESS； 如果 code 为 false， 返回的状态码是 EXIT_FAILURE； 如果 code 是一个数字， 返回的状态码就是这个数字。 code 的默认值为 true。

如果第二个可选参数 close 为真， 在退出前关闭 Lua 状态机。

### os.remove

> os.remove(filename)

删除指定名字的文件（在 POSIX 系统上可以是一个空目录） 如果函数失败，返回 nil 加一个错误描述串及出错码。

### os.rename

> os.rename(oldname, newname)

重命令或移动文件

- oldname 旧文件名
- newname 新文件名

将名字为 oldname 的文件或目录更名为 newname。 如果函数失败，返回 nil 加一个错误描述串及出错码。

### os.setlocale

> os.setlocale (locale [, category])

设置程序的当前区域。 locale 是一个区域设置的系统相关字符串； category 是一个描述有改变哪个分类的可选字符串： "all"，"collate"， "ctype"， "monetary"， "numeric"， 或 "time"； 默认的分类为 "all"。 此函数返回新区域的名字。 如果请求未被获准，返回 nil 。

当 locale 是一个空串， 当前区域被设置为一个在实现中定义好的本地区域。 当 locale 为字符串 "C"， 当前区域被设置为标准 C 区域。

当第一个参数为 nil 时， 此函数仅返回当前区域指定分类的名字。

由于这个函数依赖 C 函数 setlocale， 它可能并非线程安全的。

## 时间

### os.clock

> os.clock()

返回程序使用的按秒计 CPU 时间的近似值。

### os.date

> os.date([format [, time]])

- format `{string}` 日期格式字符串, 如果为 '*t' 则返回一个表示时间的表格
- time `{number}` 要格式化的时间, 如果没有指定则为当前时间

返回一个包含日期及时刻的字符串或表。 格式化方法取决于所给字符串 format。

如果提供了 time 参数， 格式化这个时间 （这个值的含义参见 os.time 函数）。 否则，date 格式化当前时间。

如果 format 以 '!' 打头， 日期以协调世界时格式化。 在这个可选字符项之后， 如果 format 为字符串 "*t"， date 返回有后续域的表： year （四位数字），month （1–12），day （1–31）， hour （0–23），min （0–59），sec （0–61）， wday （星期几，星期天为 1 ）， yday （当年的第几天）， 以及 isdst （夏令时标记，一个布尔量）。 对于最后一个域，如果该信息不提供的话就不存在。

如果 format 并非 "*t"， date 以字符串形式返回， 格式化方法遵循 ISO C 函数 strftime 的规则。

如果不传参数调用， date 返回一个合理的日期时间串， 格式取决于宿主程序以及当前的区域设置 （即，os.date() 等价于 os.date("%c")）。

在非 POSIX 系统上， 由于这个函数依赖 C 函数 gmtime 和 localtime， 它可能并非线程安全的。

### os.difftime

> difftime(t1, t2)

返回以秒计算的时刻 t1 到 t2 的差值。 （这里的时刻是由 os.time 返回的值）。 在 POSIX，Windows，和其它一些系统中，这个值就等于 t2-t1。

### os.time

返回系统时间, 通常为从 1970-1-1 以来经过的秒数.

> os.time([table])

- table `{object}` 要换算的时间和日期, 如果没有指定则返回当前时间

当不传参数时，返回当前时刻。 如果传入一张表，就返回由这张表表示的时刻。 这张表必须包含域 year，month，及 day； 可以包含有　hour （默认为 12 ）， min （默认为 0）， sec （默认为 0），以及 isdst （默认为 nil）。 关于这些域的详细描述，参见 os.date 函数。

返回值是一个含义由你的系统决定的数字。 在 POSIX，Windows，和其它一些系统中， 这个数字统计了从指定时间（"epoch"）开始经历的秒数。 对于另外的系统，其含义未定义， 你只能把 time 的返回数字用于 os.date 和 os.difftime 的参数。

### os.uptime

> os.uptime()

系统启动时间, 从系统启动以来经过的秒数.
