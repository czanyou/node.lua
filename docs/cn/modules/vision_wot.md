# WoT - Web of Things

IoT 客户端模块

## DataSchema

数据类型定义

支持以下数据类型: `array`, `object`, `string`, `number`, `integer`, `boolean`, `null`

### new

> DataSchema:new(options)

- options 选项
  - type 类型
  - description 描述
  - title 标题
  - constant 是否是常量
  - readOnly 只读
  - writeOnly 只写
  - items (array) 数据项类型
  - minItems (array) 最小长度
  - maxItems (array) 最大长度
  - properties  (object) 属性列表
  - mandatory (object) 必需的属性
  - minimum (number) 最小值
  - maximum(number) 最大值
  - minimum (integer) 最小值
  - maximum(integer) 最大值
  - enumeration (string) 枚举列表

## ThingDiscover

### 属性

#### 属性 filter

#### 属性 active

#### 属性 done

#### 属性 error

### start

> ThingDiscover:start()

### stop

> ThingDiscover:start()

### next

> ThingDiscover:next()

## ThingInstance

### 属性

#### 属性 id

事物 ID

#### 属性 name

事物名

#### 属性 title

显示名称

#### 属性 description

方便人读的简介

#### 属性 properties

事物属性列表

#### 属性 actions

事物操作列表

#### 属性 events

事物事件列表

## ConsumedThing

### 属性 instance

### new

> ConsumedThing:new(thingInstance)

- thingInstance 事物描述

### readProperty

> ConsumedThing:readProperty(name)

读取并返回指定名称的属性的值

- name {string} 属性名

### readMultipleProperties

> ConsumedThing:readMultipleProperties(names)

读取并返回指定名称的属性的值

- names {string[]} 属性名

### readAllProperties

> ConsumedThing:readAllProperties()

读取并返回所有的属性的值

### writeProperty

> ConsumedThing:writeProperty(name, value)

修改指定名称的属性的值

- name {string} 属性名
- value{any} 属性值

### writeMultipleProperties

> ConsumedThing:writeMultipleProperties(values)

修改指定名称的属性的值

- values {object} 属性集合

### invokeAction

> ConsumedThing:invokeAction(name, params)

调用指定名称的操作

- name {string} 操作名
- params {object} 操作输入参数

### subscribeProperty

> ConsumedThing:subscribeProperty(name, listener)

订阅指定名称的属性

- name {string} 属性名
- listener {function} 处理函数

### unsubscribeProperty

> ConsumedThing:unsubscribeProperty(name)

取消阅指定名称的属性

- name {string} 属性名

### subscribeEvent

> ConsumedThing:subscribeEvent(name, listener)

订阅指定名称的事件

- name {string} 事件名
- listener {function} 处理函数

### unsubscribeEvent

> unsubscribeEvent(name)

取消阅指定名称的事件

- name {string} 事件名

## ExposedThing

继承自 ConsumedThing

### new

> ExposedThing:new(thingInstance)

- thingInstance {object|string} 事物描述

### setPropertyReadHandler

设置指定名称的属性的读取处理函数

> ExposedThing:setPropertyReadHandler(name, handler)

- name {string} 属性名
- handler {function} 处理函数

### setPropertyWriteHandler

设置指定名称的属性的写入处理函数

> ExposedThing:setPropertyWriteHandler(name, handler)

- name {string} 属性名
- handler  {function} 处理函数

### setActionHandler

设置指定名称的操作调用处理函数

> setActionHandler(name, handler)

- name {string} 操作名
- handler  {function} 处理函数

### emitEvent

> emitEvent(name, data)

发送事件

- name {string} 事件名
- data {any} 事件数据

### expose

> ExposedThing:expose()

导出这个事物

### destroy

> ExposedThing:destroy()

销毁这个事物

## wot 

### discover

用于发现事物

> wot.discover(filter)

- filter 过滤参数

### consume

消费指定的事物

> wot.consume(thingInstance)

- thingInstance `{ThingInstance}` 要消费的事物

### produce

发布指定的事物

> wot.produce(thingInstance)

- thingInstance `{ThingInstance}` 事物模型
