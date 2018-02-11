# GPIO 通用输入输出

[TOC]

GPIO 口用于读写开关量信号, 即可以用于控制类似 LED 灯之类的简单设备, 也可以用于读取按钮或类似设备的开关状态

通过 `require('device/gpio')` 调用。

## gpio

    gpio(pin)

## gpio:close

    gpio:close(callback)

所其他所有方法之后调用, 用来关闭打开或导出的 GPIO 文件 (不会影响 GPIO 口的状态)

## gpio:open

    gpio:open(callback)

必须在其他方法前调用

- callback {Function} 打开完成后被调用

## gpio:direction

    gpio:direction(direction, callback)

设置或读取当前 GPIO 的输入输出方向

- direction {'in'|'out'|nil} GPIO 输入输出方向, 只接受 'in' 或者 'out', 如果为 nil 则表示不修改 direction 
- callback {Function} callback(direction) 返回最后读取的 GPIO 输入输出方向

## gpio:read

    gpio:read(callback)

读取 GPIO 当前电平状态, 返回 0 或者 1

- callback {Function} callback(value) 返回最后读取的 GPIO 的输入输出电平

## gpio:write

    gpio:write(value, callback)

设置 GPIO 输出电平

- value {Number} 只接受 0 或 1.

- callback {Function} 设置完成后被调用
