# Global - 全局对象

[TOC]

Node.lua 提供了一些有用的全局方法, 这里也同时列出了一些常用的 Lua 核心方法以便查阅.

## assert

    assert (v [, message])

如果其参数 v 的值为假（nil 或 false）， 它就调用 error； 否则，返回所有的参数。 在错误情况时， message 指那个错误对象； 如果不提供这个参数，参数默认为 "assertion failed!" 。

## clearImmediate

    clearImmediate(timeoutObject)

停止一个 immediate 的触发。

## clearInterval

    clearInterval(intervalObject)

停止一个 interval 的触发。

## clearTimeout

    clearTimeout(timeoutObject)

阻止一个 timeout 被触发。

## error

    error (message [, level])

中止上一次保护函数调用， 将错误对象 message 返回。 函数 error 永远不会返回。
当 message 是一个字符串时，通常 error 会把一些有关出错位置的信息附加在消息的前头。 level 参数指明了怎样获得出错位置。 对于 level 1 （默认值），出错位置指 error 函数调用的位置。 Level 2 将出错位置指向调用 error的函数的函数；以此类推。 传入 level 0 可以避免在消息前添加出错位置信息。

## getmetatable

    getmetatable (object)

如果 object 不包含元表，返回 nil 。 否则，如果在该对象的元表中有 "__metatable" 域时返回其关联值， 没有时返回该对象的元表。

## ipairs

    ipairs (t)

返回三个值（迭代函数、表 t 以及 0 ）， 如此，以下代码

     for i,v in ipairs(t) do body end

将迭代键值对（1,t[1]) ，(2,t[2])， ... ，直到第一个空值。

## pairs

    pairs (t)

如果 t 有元方法 __pairs， 以 t 为参数调用它，并返回其返回的前三个值。

否则，返回三个值：next 函数， 表 t，以及 nil。 因此以下代码

     for k,v in pairs(t) do body end

能迭代表 t 中的所有键值对。

## print

    print (···)

接收任意数量的参数，并将它们的值打印到 stdout。 它用 tostring 函数将每个参数都转换为字符串。 print 不用于做格式化输出。仅作为看一下某个值的快捷方式。 多用于调试。 完整的对输出的控制，请使用 string.format 以及 io.write。

## require

    require (modname)

Node.lua 对这个方法进行了增强, 可以使用相对目录: require('./foo') 表示导入当前目录下的 foo 模块, require('../bar') 表示引入上一级目录的 bar 模块。 

加载一个模块。 这个函数首先查找 package.loaded 表， 检测 modname 是否被加载过。 如果被加载过，require 返回 package.loaded[modname] 中保存的值。 否则，它试着为模块寻找 加载器 。

require 遵循 package.searchers 序列的指引来查找加载器。 如果改变这个序列，我们可以改变 require 如何查找一个模块。 下列说明基于 package.searchers 的默认配置。

首先 require 查找 package.preload[modname] 。 如果这里有一个值，这个值（必须是一个函数）就是那个加载器。 否则 require 使用 Lua 加载器去查找 package.path 的路径。 如果查找失败，接着使用 C 加载器去查找 package.cpath 的路径。 如果都失败了，再尝试 一体化 加载器 （参见 package.searchers）。

每次找到一个加载器，require 都用两个参数调用加载器： modname 和一个在获取加载器过程中得到的参数。 （如果通过查找文件得到的加载器，这个额外参数是文件名。） 如果加载器返回非空值， require 将这个值赋给 package.loaded[modname]。 如果加载器没能返回一个非空值用于赋给 package.loaded[modname]， require 会在那里设入 true 。 无论是什么情况，require 都会返回 package.loaded[modname] 的最终值。

如果在加载或运行模块时有错误， 或是无法为模块找到加载器， require 都会抛出错误。

## runLoop

    runLoop(mode)

表示进入事件循环

## setImmediate

    setImmediate(callback, ...)

同 `timer.setImmediate(callback, ...)`

## setInterval

    setInterval(delay, callback, ...)

同 `timer.setInterval(delay, callback, ...)`

## setTimeout

    setTimeout(delay, callback, ...)

同 `timer.setTimeout(delay, callback, ...)`

## setmetatable 

    setmetatable(table, metatable)

给指定表设置元表。（你不能在 Lua 中改变其它类型值的元表，那些只能在 C 里做。） 如果 metatable 是 nil， 将指定表的元表移除。 如果原来那张元表有 "__metatable" 域，抛出一个错误。

这个函数返回 table。

## tonumber 

tonumber (e [, base])

如果调用的时候没有 base， tonumber 尝试把参数转换为一个数字。 如果参数已经是一个数字，或是一个可以转换为数字的字符串， tonumber 就返回这个数字； 否则返回 nil。

字符串的转换结果可能是整数也可能是浮点数， 这取决于 Lua 的转换文法。 （字符串可以有前置和后置的空格，可以带符号。）

当传入 base 调用它时， e 必须是一个以该进制表示的整数字符串。 进制可以是 2 到 36 （包含 2 和 36）之间的任何整数。 大于 10 进制时，字母 'A' （大小写均可）表示 10 ， 'B' 表示 11，依次到 'Z' 表示 35 。 如果字符串 e 不是该进制下的合法数字， 函数返回 nil。

## tostring

    tostring (v)

可以接收任何类型，它将其转换为人可阅读的字符串形式。 浮点数总被转换为浮点数的表现形式（小数点形式或是指数形式）。 （如果想完全控制数字如何被转换，可以使用 string.format。）
如果 v 有 "__tostring" 域的元表， tostring 会以 v 为参数调用它。 并用它的结果作为返回值。

## type

    type (v)

将参数的类型编码为一个字符串返回。 函数可能的返回值有 "nil" （一个字符串，而不是 nil 值）， "number"， "string"， "boolean"， "table"， "function"， "thread"， "userdata"。
