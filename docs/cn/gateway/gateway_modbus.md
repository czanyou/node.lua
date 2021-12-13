# Modbus

## 概述

## Modbus RTU

## 工具类方法

### combineReadQueue

> combineReadQueue()

### encodePropertyValue

> encodePropertyValue(property, value)

### getActionConfig

> getActionConfig()

### getModbusCommonConfig

> getModbusCommonConfig()

### getModbusConfig

> getModbusConfig()

### getPropertyConfig

> getPropertyConfig()

### parsePropertyValue

> parsePropertyValue(property, buffer, offset)

### parsePropertyValues

> parsePropertyValues(properties, buffer, options)

解析属性值

## Modbus Master

Modbus Master 设备用来和 Modbus 从机通信，主要是用来读取寄存器数据或者将数据写入寄存器

### ModbusCommonConfig

Modbus 公共配置参数

- address `integer` 从机地址
- device `integer` 相关的串口设备 ID
- interval `integer` 数据采集间隔
- timeout `integer` Modbus 超时时间

### ModbusOptions

Modbus 读写选项

- common `ModbusCommonConfig` 公共选项
- properties `table<string,MobusProperty>` 属性项

### MobusProperty

Modbus 属性配置参数

### 类ModbusMaster

Modbus Master 设备

#### close

> master:close()

#### connect

> master:connect()

#### readBits

> master:readBits(register, quantity)

- register `integer`
- quantity `integer`

#### readRegisters

> master:readRegisters(code, register, quantity)

- register `integer`
- quantity `integer`

#### setSlave

> master:setSlave(address)

- address `integer` 从机地址

#### writeBit

> master:writeBit(register, value)

- register `integer`
- value `integer`

#### writeRegister

> master:writeRegister(register, value)

- register `integer`
- value `integer`

#### writeRegisters

> master:writeRegisters(register, quantity, data)

- register `integer`
- quantity `integer`
- data `string`

### 公共方法

#### closeDevice

> closeDevice()

关闭 Modbus Master 设备

#### openDevice

> openDevice(options)

打开并返回相关的 Modbus Master 设备

- options `ModbusCommonConfig`
- 返回 `ModbusMaster`

#### readPropertyValues

> readPropertyValues(options)

读属性值, 将根据属性配置来读取相应的寄存器的内容，然后返回解析后的值

- options `ModbusOptions`
- 返回 table {code, error, values} 返回读取到的属性值或者错误信息

#### writePropertyValues

> writePropertyValues(options)

写属性值，将根据属性配置将要写入的值进行编码并写入相应的寄存器

- options `ModbusOptions`
- 返回 table<string,table {code,error,value}> 返回写入的属性值或者错误信息

### 错误信息

- 不存在的属性
- 属性配置参数错误
- 响应超时

## modbus

### things

> modbus.things

### isDataReady

> modbus.isDataReady()

指出是否有采集到数据

- 返回 `boolean`

### start

> modbus.start()

初始化这个模块

- 创建相关的 Modbus 事物
- 打开 Modbus Master 设备
- 设置定时器，定期采集相关的属性值
- 注册相关的 Action 处理函数

### 内部方法

#### createThing

> modbus.createThing(options)

创建一个事物

- options `ThingOptions`

### 类 modbusDevice

#### onDeviceActions

> onDeviceActions(webThing, input)

#### onConfigActions

> onConfigActions(webThing, input)

#### onReadAction

> onReadAction(webThing, input)

- input `table<string>`  要读取的属性名，未指定则读取所有属性
- 返回 `ActionResult`

#### onWriteAction

> onWriteAction(webThing, input)

- input `table<string,any>` 要写入的属性名和属性值
- 返回 `ActionResult`

#### setActionHandlers

> setActionHandlers(webThing)

注册 Action 操作处理方法

#### sendStream

> sendStream(webThing, data)

发送 Stream 数据

- webThing `ExposedThing`
- data `table`

#### startReadProperties

> startReadProperties(webThing)

开始定时读取属性

#### stopReadProperties

> stopReadProperties(webThing)

停止读取属性

#### setModbusConfig

> setActionHandlers(webThing, config)

设置配置参数

- webThing
- config

