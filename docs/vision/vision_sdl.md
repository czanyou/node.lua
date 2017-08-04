# SDL - 简单设备访问层

[TOC]

简单设备访问层

通过 `require('lsdl')` 调用。

### lsdl.nanosleep

    lsdl.nanosleep(delay, mode)

- delay {Number} 要延时的时间
- mode {Number} 0 表示 delay 单位为 ms, 1 表示 delay 单位 us

内部使用 nanosleep 实现

