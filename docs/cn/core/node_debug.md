# 调试器 (Debugger)

Lua 提供了 debug 库用于提供创建我们自定义调试器的功能。

Lua 中 debug 库包含以下函数：

## 调试器方法

### debug

> debug()

进入一个用户交互模式，运行用户输入的每个字符串。 使用简单的命令以及其它调试设置，用户可以检阅全局变量和局部变量， 改变变量的值，计算一些表达式，等等。 输入一行仅包含 cont 的字符串将结束这个函数， 这样调用者就可以继续向下运行。 

### gethook

> gethook([thread])

返回三个表示线程钩子设置的值： 当前钩子函数，当前钩子掩码，当前钩子计数 

- thread

### getinfo

> getinfo ([thread,] f [, what])

返回关于一个函数信息的表。 你可以直接提供该函数， 也可以用一个数字 f 表示该函数。 数字 f 表示运行在指定线程的调用栈对应层次上的函数： 0 层表示当前函数（getinfo 自身）； 1 层表示调用 getinfo 的函数 （除非是尾调用，这种情况不计入栈）；等等。 如果 f 是一个比活动函数数量还大的数字， getinfo 返回 nil。 

- thread
- f
- what

### getlocal

> getlocal ([thread,] f, local)

此函数返回在栈的 f 层处函数的索引为 local 的局部变量 的名字和值。 这个函数不仅用于访问显式定义的局部变量，也包括形参、临时变量等。 

- thread
- f
- local

### getmetatable

> getmetatable(value)

把给定索引指向的值的元表压入堆栈。如果索引无效，或是这个值没有元表，函数将返回 0 并且不会向栈上压任何东西。 

- value

### getregistry

> getregistry()

返回注册表，这是一个预定义出来的表， 可以用来保存任何 C 代码想保存的 Lua 值。 

### getupvalue

> getupvalue (f, up)

此函数返回函数 f 的第 up 个上值的名字和值。 如果该函数没有那个上值，返回 nil 。 以 '(' （开括号）打头的变量名表示没有名字的变量 （去除了调试信息的代码块）。 

- f
- up

### sethook

> sethook ([thread,] hook, mask [, count])

将一个函数作为钩子函数设入。 字符串 mask 以及数字 count 决定了钩子将在何时调用。 掩码是由下列字符组合成的字符串，每个字符有其含义：**'`c`':** 每当 Lua 调用一个函数时，调用钩子；**'`r`':** 每当 Lua 从一个函数内返回时，调用钩子；**'`l`':** 每当 Lua 进入新的一行时，调用钩子。 

- thread
- hook
- mask
- count

### setlocal

> setlocal ([thread,] level, local, value)

这个函数将 value 赋给 栈上第 level 层函数的第 local 个局部变量。 如果没有那个变量，函数返回 nil 。 如果 level 越界，抛出一个错误。 

- thread
- level
- local
- value

### setmetatable

> setmetatable (value, table)

将 value 的元表设为 table （可以是 nil）。 返回 value。 

- value
- table

### setupvalue

> setupvalue (f, up, value)

这个函数将 value 设为函数 f 的第 up 个上值。 如果函数没有那个上值，返回 nil 否则，返回该上值的名字。 

- f
- up
- value

### traceback

> traceback ([thread,] [message [, level]])

如果 message 有，且不是字符串或 nil， 函数不做任何处理直接返回 message。 否则，它返回调用栈的栈回溯信息。 字符串可选项 message 被添加在栈回溯信息的开头。 数字可选项 level 指明从栈的哪一层开始回溯 （默认为 1 ，即调用 traceback 的那里）。 

- thread
- message
- level