# Modbus 工业总线

## 概述

实现 Modbus 协议

可以通过 `local lmodbus = require('lmodbus')` 引入这个模块

## lmodbus

### lmodbus.version

> local version = lmodbus.version()

返回 libmodbus 的版本号

### lmodbus.new

> local devcie = lmodbus.new(host, port)
> local devcie = lmodbus.new(name, baudrate, parity, dataBits, stopBits)

打开一个新的 ModbusDevice 设备

- host `{string}` IP 地址
- port `{integer}` 端口
- name `{string}` 串口设备名称
- baudrate `{integer}` 波特率
- parity `{integer}` 校验方式
- dataBits `{integer}` 数据位
- stopBits `{integer}` 停止位

## ModbusDevice 类

### close

> device:close()

关闭这个设备

### connect

> device:connect()

开始连接

### getFD

> local fd = device:getFD()

返回打开的 UART 设备的文件描述符

### listen

> device:listen()

开始侦听请求

### newMapping

> device:newMapping(address, count)

创建新的映射寄存器

- address `{integer}` 开始的地址
- count `{integer}` 总共的寄存器数量

### read

> local values = device:read(addresses)

读取多个寄存器

- addresses `{array of integer}`

### readRegisters

> local values = device:readRegisters(address, count)

读多个寄存器

- address `{integer}` 开始读取的地址
- count `{integer}` 总共读取的数量

### readBits

> local values device:readBits(address, count)

读取多位

- address `{integer}` 开始读取的地址
- count `{integer}` 总共读取的位数

### receive

> device:receive()

接收客户端请求并返回应答

### setMappingValue

> device:setMappingValue(type, address, value)

设置映射寄存器的值

- type `{integer}` 寄存器类型
- address `{integer}` 寄存器地址
- value `{integer}` 要写入的值

### setSlave

> device:setSlave(slave)

设置从机地址

- slave `{integer}` 从机地址

### write

> device:write(values)

写入多个值

- values 要写入的值

### writeBit

> device:writeBit(address, value)

写入一位

- address `{integer}` 开始写入的地址
- value `{integer}` 要写入的值

### writeRegister

> device:writeRegister(address, value)

写寄存器

- address `{integer}` 开始写入的地址
- value `{integer}` 要写入的值

## modbus/common

### common.combineReadQueue

> common.combineReadQueue(properties)

合并连续的 Modbus 属性读操作

- properties`ModbusProperty[]` 要读取的 Modbus 属性
- 返回 `ModbusReadItem[]` 返回合并后的读序列

### common.encodePropertyValue

> common.encodePropertyValue(property)

编码指定的属性值

- property `ModbusProperty` Modbus 属性
- 返回 `string` 返回编码后的数据

### common.getActionConfig

Modbus 操作配置参数

### common.getModbusCommonConfig

Modbus 公共配置参数

### common.getModbusConfig

Modbus 配置参数

### common.getPropertyConfig

Modbus 属性配置参数

### common.parseNumberValue

> parseNumberValue(value, property)

解析数据类属性值

### common.parsePropertyValue

> common.parsePropertyValue(property, buffer)

解析指定的属性的值

- property `ModbusProperty` Modbus 属性
- buffer `string` Modbus 寄存器数据
- 返回 `number|integer` 解析后的数值

### common.parsePropertyValues

> common.parsePropertyValues(properties, buffer, params)

解析多个属性的值

- properties`ModbusProperty[]` Modbus 属性
- buffer `string` Modbus 寄存器数据
- 返回 `table<string, number>` 解析后的数值

## modbus/master

### master.openDevice

> master.openDevice(options)

打开 Modbus 设备

### master.closeDevice

> master.closeDevice()

关闭 Modbus 设备 

### master.readRegisters

> master.readRegisters(register, quantity)

读取多个连续的 Modbus 寄存器的值

### master.readPropertyValue

> master.readPropertyValue(property, commonConfig)

读取单个 Modbus 寄存器的值

### master.readConterminousPropertyValues

> master.readConterminousPropertyValues(readOptions, properties, commonConfig)

读取多个连续的属性的值

### master.readPropertyValues

> master.readPropertyValues(options)

读取多个属性的值

### master.writeRegister

> master.writeRegister(register, value)

写单个 Modbus 寄存器的值

### master.writeRegisters

> master.writeRegisters(register, quantity, value)

写多个连续的 Modbus 寄存器的值

### master.writePropertyValue

> master.writePropertyValue(property, commonConfig)

写单个属性的值

- property 属性
- commonConfig 公共参数

### master.writePropertyValues

> master.writePropertyValues(options)

写多个属性的值

- options 选项
  - common 公共参数
  - properties 属性列表

### master.start

> master.start()

初始化这个模块

## modbus
