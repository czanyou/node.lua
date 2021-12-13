# 控制台 (console)

用于向 stdout 和 stderr 打印字符。类似于大部分 Web 浏览器提供的 console 对象，在这里则是输出到 stdout 或 stderr。

这是一个全局的模块, 可以直接调用.

## 打印

### console.printr

> utils.printr(...)

以更友好的方式打印指定的参数的值，方便调试


### console.printBuffer

>  utils.printBuffer(value)

以 16 进制数字型式打印指定的缓存区数据的值

- `value` {string} 缓存区

### console.error

> console.error(...)

同 console.log。

### console.info

> console.info(...)

同 console.log。

### console.log

> console.log(...)

向 stdout 打印并新起一行。这个函数可以接受多个参数，例如：

```lua

local count = 5
console.log('count: ', count)
  -- Prints: count: 5, to stdout

```

### console.warn

> console.warn(...)

同 console.log。


## console.dump

>  utils.dump(...)

返回指定的参数的字符串表示，方便调试


## console.time

> console.time(label)

标记一个时间点。

- `label` {string} 时间标记名称

## console.timeEnd

> console.timeEnd(label)

结束计时器，输出结果。

- `label` {string} 时间标记名称

例如：

```lua

console.time('100-elements')
for i = 1,100 do
  ;
end
console.timeEnd('100-elements')

```

## console.trace

> console.trace(message)

打印当前位置的函数栈到 stderr。

- `message` {string} 

## 参考

### ANSI控制码

```shell

\27[0m 关闭所有属性 
\27[01m 设置高亮度 
\27[04m 下划线 
\27[05m 闪烁 
\27[07m 反显 
\27[08m 消隐 
\27[30m -- \27[37m 设置前景色 
\27[40m -- \27[47m 设置背景色 
\27[nA 光标上移n行 
\27[nB 光标下移n行 
\27[nC 光标右移n行 
\27[nD 光标左移n行 
\27[y;xH设置光标位置 
\27[2J 清屏 
\27[K 清除从光标到行尾的内容 
\27[s 保存光标位置 
\27[u 恢复光标位置 
\27[?25l 隐藏光标 
\27[?25h 显示光标

```

