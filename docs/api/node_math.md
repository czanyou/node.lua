# Math - 数学计算

[TOC]

这个库提供了基本的数学函数。 所以函数都放在表 math 中。 注解有 "integer/float" 的函数会对整数参数返回整数结果， 对浮点（或混合）参数返回浮点结果。 圆整函数（math.ceil, math.floor, math.modf） 在结果在整数范围内时返回整数，否则返回浮点数。

这是系统内置模块, 可以直接调用

## math.abs (x)

返回 x 的绝对值. (integer/float)

## math.acos (x)

返回 x 的反余弦值（用弧度表示）。

## math.asin (x)

返回 x 的反正弦值（用弧度表示）。

## math.atan (y [, x])

返回 y/x 的反正切值（用弧度表示）。 它会使用两个参数的符号来找到结果落在哪个象限中。 （即使 x 为零时，也可以正确的处理。）

默认的 x 是 1 ， 因此调用 math.atan(y) 将返回 y 的反正切值。

## math.ceil (x)

返回不小于 x 的最小整数值。

## math.cos (x)

返回 x 的余弦（假定参数是弧度）。

## math.deg (x)

将角 x 从弧度转换为角度。

## math.exp (x)

返回 ex 的值 （e 为自然对数的底）。

## math.floor (x)

返回不大于 x 的最大整数值。

## math.fmod (x, y)

返回 x 除以 y，将商向零圆整后的余数。 (integer/float)

## math.huge

浮点数 HUGE_VAL， 这个数比任何数字值都大。

## math.log (x [, base])

返回以指定底的 x 的对数。 默认的 base 是 e （因此此函数返回 x 的自然对数）。

## math.max (x, ···)

返回参数中最大的值， 大小由 Lua 操作 < 决定。 (integer/float)

## math.maxinteger

最大值的整数。

## math.min (x, ···)

返回参数中最小的值， 大小由 Lua 操作 < 决定。 (integer/float)

## math.mininteger

最小值的整数。

## math.modf (x)

返回 x 的整数部分和小数部分。 第二个结果一定是浮点数。

## math.pi

π 的值。

## math.rad (x)

将角 x 从角度转换为弧度。

## math.random ([m [, n]])

当不带参数调用时， 返回一个 [0,1) 区间内一致分布的浮点伪随机数。 当以两个整数 m 与 n 调用时， math.random 返回一个 [m, n] 区间 内一致分布的整数伪随机数。 （值 n-m 不能是负数，且必须在 Lua 整数的表示范围内。） 调用 math.random(n) 等价于 math.random(1,n)。

这个函数是对 C 提供的位随机数函数的封装。 对其统计属性不作担保。

## math.randomseed (x)

把 x 设为伪随机数发生器的“种子”： 相同的种子产生相同的随机数列。

## math.sin (x)

返回 x 的正弦值（假定参数是弧度）。

## math.sqrt (x)

返回 x 的平方根。 （你也可以使用乘方 x^0.5 来计算这个值。）

## math.tan (x)

返回 x 的正切值（假定参数是弧度）。

## math.tointeger (x)

如果 x 可以转换为一个整数， 返回该整数。 否则返回 nil。

## math.type (x)

如果 x 是整数，返回 "integer"， 如果它是浮点数，返回 "float"， 如果 x 不是数字，返回 nil。

## math.ult (m, n)

如果整数 m 和 n 以无符号整数形式比较， m 在 n 之下，返回布尔真, 否则返回假。
