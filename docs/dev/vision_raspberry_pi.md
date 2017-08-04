# 树莓派开发指南

[TOC]

## 概述

默认登录名: pi, 密码: raspiberry

可修改如下：

默认登录名: pi, 密码: 66668888

## I2C

### 温度传感器连接方式

Raspiberry PI IO 口排列如下:

```
3.3V    1  |  2    5V     | --> 板边缘
SDA     3  |  4    5V
SCL     5  |  6    GND
GPIO7   7  |  8    TX
GND     9  |  10   RX
GPIO0  11  |  12   GPIO1
GPIO2  13  |  14   GND
GIPO3  15  |  16   GPIO4
3.3V   17  |  18   GPIO5
MOSI   19  |  20   GND
MISO   21  |  22   GPIO6
SCLK   23  |  24   CE0
GND    25  |  26   CE1
```

传感器可使用 3.3V 供电，所以接线如下：

Vss 接 IO 1
scl 接 IO 5
sdl 接 IO 3
gnd 接 IO 9

### I2C 驱动

启用 I2C 驱动的方法：

运行 `sudo raspi-config`, 在高级设置一项上，启用 SSH, I2C 等，然后重启

Raspberry PI 2 I2C 设备名为 `/dev/i2c-1`

#### 安装 I2C 工具：

    sudo apt-get install i2c-tools

#### 扫描 I2C 设备的方法:

通过 `i2cdetect -l` 指令可以查看树莓派上的 I2C 总线，从返回的结果来看树莓派含有两个 I2C 总线，通过阅读相关的资料，树莓派1代使用 I2C0，而树莓派 2 代使用 I2C1。

```
pi@raspberrypi:~$ i2cdetect -l  
i2c-0   i2c             bcm2708_i2c.0                           I2C adapter  
i2c-1   i2c             bcm2708_i2c.1                           I2C adapter  
```

#### I2C设备查询

若总线上挂载 I2C 从设备，可通过 i2cdetect 扫描某个 I2C 总线上的所有设备。可通过控制台输入 `i2cdetect -y 1`，结果如下所示。

```
pi@raspberrypi:~$ i2cdetect -y 1  
     0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f  
00:          -- -- -- -- -- -- -- -- -- -- -- -- --   
10: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --   
20: 20 -- -- -- -- -- -- -- -- -- -- -- -- -- -- --   
30: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --   
40: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --   
50: 50 51 -- -- -- -- -- -- -- -- -- -- -- -- -- --   
60: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --   
70: -- -- -- -- -- -- -- --    
```

说明1：-y 为一个可选参数，如果有 -y 参数的存在则会有一个用户交互过程，意思是希望用户停止使用该 I2C 总线。如果写入该参数，则没有这个交互过程，一般该参数在脚本中使用。

说明2：此处I2C总线共挂载两个设备—— PCF8574 和 AT24C04，从机地址 0x20 为 PCF8574，从机地址 0x50 和 0x51 为 AT24C04，请注意 AT24C04 具备两个 I2C 地址，

#### 寄存器内容导出

通过 i2cdump 指令可导出 I2C 设备中的所有寄存器内容，例如输入 `i2cdump -y 1 0x51`，可获得以下内容:

```
pi@raspberrypi:~$ i2cdump -y 1 0x51  
No size specified (using byte-data access)  
     0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f    0123456789abcdef  
00: ff ff ff ff ff ff ff ff ff ff ff ff ff ff ff ff    ................  
10: ff ff ff ff ff ff ff ff ff ff ff ff ff ff ff ff    ................  
20: ff ff ff ff ff ff ff ff ff ff ff ff ff ff ff ff    ................  
30: ff ff ff ff ff ff ff ff ff ff ff ff ff ff ff ff    ................  
40: ff ff ff ff ff ff ff ff ff ff ff ff ff ff ff ff    ................  
50: ff ff ff ff ff ff ff ff ff ff ff ff ff ff ff ff    ................  
60: ff ff ff ff ff ff ff ff ff ff ff ff ff ff ff ff    ................  
70: ff ff ff ff ff ff ff ff ff ff ff ff ff ff ff ff    ................  
80: ff ff ff ff ff ff ff ff ff ff ff ff ff ff ff ff    ................  
90: ff ff ff ff ff ff ff ff ff ff ff ff ff ff ff ff    ................  
a0: ff ff ff ff ff ff ff ff ff ff ff ff ff ff ff ff    ................  
b0: ff ff ff ff ff ff ff ff ff ff ff ff ff ff ff ff    ................  
c0: ff ff ff ff ff ff ff ff ff ff ff ff ff ff ff ff    ................  
d0: ff ff ff ff ff ff ff ff ff ff ff ff ff ff ff ff    ................  
e0: ff ff ff ff ff ff ff ff ff ff ff ff ff ff ff ff    ................  
f0: ff ff ff ff ff ff ff ff ff ff ff ff ff ff ff ff    ................  
```

`i2cdump -y 1 0x51` 指令中:

- -y        代表取消用户交互过程，直接执行指令；
- 1         代表 I2C 总线编号；
- 0x51      代表 I2C 设备从机地址，此处选择 AT24C04 的高 256 字节内容。

在该 AT24C04 的高 256 字节尚处于出厂默认状态，所有的存储地址中的内容均为 0XFF。

#### 寄存器内容写入

如果向 I2C 设备中写入某字节，可输入指令 `i2cset -y 1 0x50 0x00 0x13`

- -y      代表曲线用户交互过程，直接执行指令
- 1       代表 I2C 总线编号
- 0x50    代表 I2C 设备地址，此处选择 AT24C04 的低 256 字节内容
- 0x00    代表存储器地址
- 0x13    代表存储器地址中的具体内容

#### 寄存器内容读出

```
pi@raspberrypi:~$ i2cget -y 1 0x50 0x00  
0x13  
```

如果从 I2C 从设备中读出某字节，可输入执行i2cget -y 1 0x50 0x00，可得到以下反馈结果

- -y      代表曲线用户交互过程，直接执行指令
- 1       代表I2C总线编号
- 0x50    代表I2C设备地址，此处选择AT24C04的低256字节内容
- 0x00    代表存储器地址

http://www.lm-sensors.org/wiki/i2cToolsDocumentation

### I2C 设备文件 

    /dev/i2c-1

可以用文件方式打开

    int fd = open('/dev/i2c-1');

设置 I2C 从设备地址:

    ioctl(fd, I2C_SLAVE, address);

写一个字节:

    write(fd, buf, 1);

写二个字节:

    write(fd, buf, 2);

读多个字节:

    read(fd, buf, 3);

关闭设备:

    close(fd);

可见读写 I2C 还是挺简单的.

### 绑定到 Lua

Demo:

```lua
local lmedia = require('lmedia')

local I2C_BUS     = '/dev/i2c-1'
local I2C_SLAVE   = 1795
local I2C_ADDRESS = 0x40 -- SHT21 Address
local i2c = lmedia.new_i2c(I2C_BUS, I2C_SLAVE, I2C_ADDRESS)

i2c:write(string.char(0xFE)) -- SOFT RESET
i2c:delay(50, 0)  -- 需要 50ms 完成复位

i2c:write(string.char(0xF3)) -- READ Temperature
i2c:delay(260, 0) -- 需要 260ms 测出温度

local ret = i2c:read(3)
utils.printBuffer(ret)

-- 计算温度:
local val = ret:byte(1)
val = val << 8
val = val + ret:byte(2)
val = val & 0xfffc

-- 浮点算法
local temperature = -46.85 + 175.72 * val / 65535

-- 定点算法 (Lua 无效)
--local temperature = (val * 512) / 9548
--temperature  = (temperature  - 937) / 2

print('temperature', temperature)

i2c:close()

run_loop()
```

## SAMBA

    sudo apt-get install samba
    sudo apt-get install samba-common-bin

安装完成后，我们在/ect/samba/文件夹中找到这个文件smb.conf，它是用来对samba服务配置用的，用nano文件编辑器打开后发现里面很是复杂，没关系，我们只需要一个简单smb.conf。先将smb.conf重命名为smb.conf.backup。然后用下面的smb.conf替换原来的smb.conf

```
[global]
        log file = /var/log/samba/log.%m
[tmp]
        comment = Temporary file space
        path = /tmp
        read only = no
        public = yes
```

保存完毕后输入命令：

    sudo /etc/init.d/samba retsart

这条命令是重启samba服务，为使刚刚重新设置的配置文件生效。
这时打开电脑上的网上邻居（要保证你的电脑和树莓派在同一局域网内），你就会看到名为RASPBERRYPI这个主机了，尝试打开，发现需要用户名与密码，但是现在无论输入什么用户名与密码都进不去，因为我们还没有设置呢！O(∩_∩)O，那下面就来创建用户吧。

由于创建的samba用户需要是系统内已经存在的用户，而系统默认是只有root和pi这两个用户的，如果想使用其他的用户名怎么办，新建一个呗（假设我们要新建一个用户名为aaa的用户）

输入命令：

    sudo useradd aaa

这时系统就新建了一个名为aaa的用户，但不是我们 samba 还没有设置呢，别急，看下面

在/etc/samba/文件夹下建立smbpasswd文件，命令为：

    sudo touch /etc/samba/smbpasswd

再给samba添加用户名为aaa的用户：

    sudo smbpasswd -a aaa 

会让你输入密码的，自己设一个，设完了会显示：Added user aaa

到这里就搞定了，再打开网上邻居，输入刚刚设好的用户名与密码，这时就进去了，会发现一个tmp的文件夹，可以在这个文件夹内自由地读写数据了，比如说传电影，考电影，传歌，考歌等等，反正你懂得啦。贴张图：


