# Linux GPIO

[TOC]

在 Linux 下应用程序调用 GPIO 其实非常简单

在 Linux 下可以通过 sys 文件系统直接控制 GPIO: /sys/class/gpio

## /sys/class/gpio

/sys/class/gpio 目录下有一些子目录或者文件用来配置或者调用 GPIO:

| -   | -   |
| --- | --- | ---
| /sys/class/gpio           | GPIO 目录     |
| /sys/class/gpio/export    | 只写, 用于导出一个 GPIO 口
| /sys/class/gpio/gpio{number} | 用于配置和读写指定 GPIO 的子目录
| /sys/class/gpio/gpio{number}/direction | 可读写, 支持的值为 in 或 out
| /sys/class/gpio/gpio{number}/value | 可读写, 支持的值为 0 或 1


默认情况下 GPIO 还不能被应用程序使用, 在使用之前首先需要把它"导出"到用户空间.

```sh
# 这段脚本将导出 pin 脚为 22 的 GPIO, 并在 /sys/class/gpio 目录下出一个名为 gpio22 的子目录
$ echo 22 > /sys/class/gpio/export
```

然后要配置这个 I/O 口为输入或者输出模式

```sh
# 这段脚本将 GPIO 22 配置为输入模式
$ echo in > /sys/class/gpio/gpio22/direction

# 这段脚本将 GPIO 22 配置为输出模式
$ echo out > /sys/class/gpio/gpio22/direction
```

通过 value 文件读写 GPIO 口

```sh 
# 将 GPIO 22 输出设置为高电平
$ echo 1 > /sys/class/gpio/gpio22/value

# 显示 GPIO 22 当前电平值
$ cat /sys/class/gpio/gpio22/value

```

## Node.lua GPIO 驱动

导入 GPIO 模块: `/vision/device/gpio`

写 GPIO:

```lua
local gpio = require('/vision/device/gpio')

local pin = 22
local value = 1 -- or 0

local gpio22 = gpio(pin)

gpio22:open(function()
    gpio22:direction('out', function()
        gpio22:write(value, function()
            gpio22:close()
        end
    end
end

```

读 GPIO:

```lua
local gpio = require('/vision/device/gpio')

local pin = 22

-- callback(value), value is 0 or 1
function gpio_read(pin, callback)
    local gpio22 = gpio(pin)

    gpio22:open(function()
        gpio22:direction('in', function()
            gpio22:read(function(value)
                gpio22:close()

                callback(value)
            end
        end
    end
end

gpio_read(pin, function(value)
    print("GPIO " .. pin .. " is: ", value)
end)

```