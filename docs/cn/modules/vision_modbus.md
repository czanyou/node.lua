# Modbus 工业总线

## 概述

实现 Modbus 协议

可以通过 `local lmodbus = require('lmodbus')` 引入这个模块

## lmodbus

### lmodbus.version

> lmodbus.version()

返回 libmodbus 的版本号

### lmodbus.new

> lmodbus.new(host, port)
> lmodbus.new(name, baudrate, parity, dataBits, stopBits)

打开一个新的 ModbusDevice 设备

- host `{string}` IP 地址
- port `{integer}` 端口
- name `{string}` 串口设备名称
- baudrate `{integer}` 波特率
- parity `{integer}` 校验方式
- dataBits `{integer}` 数据位
- stopBits `{integer}` 停止位

## ModbusDevice

### close

> close()

关闭这个设备

### connect

> connect()

开始连接

### getFD

> get_uart_fd()

返回打开的 UART 设备的文件描述符

### listen

> listen()

开始侦听请求

### newMapping

> newMapping(address, count)

创建新的映射寄存器

- address `{integer}` 开始的地址
- count `{integer}` 总共的寄存器数量

### read

> read(addresses)

读取多个寄存器

- addresses `{array of integer}`

### readRegisters

> readRegisters(address, count)

读多个寄存器

- address `{integer}` 开始读取的地址
- count `{integer}` 总共读取的数量

### readBits

> readBits(address, count)

读取多位

- address `{integer}` 开始读取的地址
- count `{integer}` 总共读取的位数

### receive

> receive()

接收客户端请求并返回应答

### setMappingValue

> setMappingValue(type, address, value)

设置映射寄存器的值

- type `{integer}` 寄存器类型
- address `{integer}` 寄存器地址
- value `{integer}` 要写入的值

### setSlave

> setSlave(slave)

设置从机地址

- slave `{integer}` 从机地址

### write

> write(values)

写入多个值

- values 要写入的值

### writeBit

> writeBit(address, value)

写入一位

- address `{integer}` 开始写入的地址
- value `{integer}` 要写入的值

### writeRegister

> writeRegister(address, value)

写寄存器

- address `{integer}` 开始写入的地址
- value `{integer}` 要写入的值
