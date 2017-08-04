# 控制台 (console)

[TOC]

用于向 stdout 和 stderr 打印字符。类似于大部分 Web 浏览器提供的 console 对象，在这里则是输出到 stdout 或 stderr。

这是一个全局的模块, 可以直接调用.

## console.error

    console.error(...)

同 console.log。


## console.pprint

    utils.pprint(...)

以更友好的方式打印指定的参数的值，方便调试


## console.printBuffer

     utils.printBuffer(value)

以 16 进制打印指定的缓存区数据的值


## console.dump

     utils.dump(...)

返回指定的参数的字符串表示，方便调试


## console.info

    console.info(...)

同 console.log。

## console.log

    console.log(...)

向 stdout 打印并新起一行。这个函数可以像 printf() 那样接受多个参数，例如：

```lua

local count = 5
console.log('count: ', count)
  -- Prints: count: 5, to stdout

```

## console.time

    console.time(label)

标记一个时间点。

- label {String} 时间标记名称

## console.timeEnd

    console.timeEnd(label)

结束计时器，记录输出。例如：

- label {String} 时间标记名称

```lua

console.time('100-elements')
for i = 1,100 do
  ;
end
console.timeEnd('100-elements')

```

## console.trace

    console.trace(message)

打印当前位置的栈跟踪到 stderr。


## console.warn

    console.warn(...)

同 console.log。


## 特殊符号

```sh

ANSI控制码

\33[0m 关闭所有属性 
\33[01m 设置高亮度 
\33[04m 下划线 
\33[05m 闪烁 
\33[07m 反显 
\33[08m 消隐 
\33[30m -- \33[37m 设置前景色 
\33[40m -- \33[47m 设置背景色 
\33[nA 光标上移n行 
\33[nB 光标下移n行 
\33[nC 光标右移n行 
\33[nD 光标左移n行 
\33[y;xH设置光标位置 
\33[2J 清屏 
\33[K 清除从光标到行尾的内容 
\33[s 保存光标位置 
\33[u 恢复光标位置 
\33[?25l 隐藏光标 
\33[?25h 显示光标

```

