# 终端 (TTY)

`tty` 模块提供 `tty.ReadStream` 和 `tty.WriteStream` 类。 在大多数情况下，没有必要或可能直接使用此模块。

当 Node 检测到它附加了文本终端（TTY）时，默认情况下，[`process.stdin`](http://nodejs.cn/s/gagmJq) 将被初始化为 `tty.ReadStream` 的一个实例，[`process.stdout`](http://nodejs.cn/s/tQWUzG) 和 [`process.stderr`](http://nodejs.cn/s/wPv5zY) 将被初始化为 `tty.WriteStream` 的实例。 判断 Node 是否在 TTY 上下文中运行的首选方法是检查 `process.stdout.isTTY` 属性的值是否为 `true`：