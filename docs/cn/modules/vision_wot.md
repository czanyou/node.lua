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

## ThingAction

### new

> ThingAction:new(options)

- options 选项
  - title 标题
  - description 描述
  - input 输入参数
  - output 输出参数

### invoke

调用操作

> ThingAction:invoke(input)

- input输入参数

## ThingProperty

继承自 DataSchema

### new

> ThingProperty:new(options)

请参考 DataSchema:new(options)

- options 选项
  - observable 是否是可观察的

### subscribe

订阅属性变动事件

> ThingProperty:subscribe(callback, error, finished)

### read

读取属性值

> ThingProperty:read()

### write

修改属性值

> ThingProperty:write(value)

- value 要修改的属性值 

## ThingEvent

继承自 DataSchema

### new

> ThingEvent:new(options)

- options 选项, 请参考 DataSchema:new(options)

### emit

发布一个事件

> ThingEvent:emit(payload)

- payload 事件数据

## ThingDiscover

### subscribe

> ThingDiscover:subscribe(callback, error, finished)

## ThingInstance

### 属性 id

### 属性 name

### 属性 description

### 属性 properties

### 属性 actions

### 属性 events

### new

> ThingInstance:new(options)

- options 选项
  - id 事物 ID
  - name 名称
  - base 基地址
  - description 描述信息

### getDescription

返回事物描述字符串

> ThingInstance:getDescription()



## ConsumedThing

继承自 ThingInstance

### 属性 properties

### 属性 actions

### 属性 events

### new

> ConsumedThing:new(td)

- td 事物描述

## ExposedThing

继承自 ThingInstance

### new

> ExposedThing:new(model)

- model事物描述

### addProperty

添加一个属性

> ExposedThing:addProperty(name, property)

- name 属性名
- property 属性描述

### removeProperty

删除指定名称的属性

> ExposedThing:removeProperty(name)

- name 要删除的属性的名称

### setPropertyReadHandler

设置指定名称的属性的读取处理函数

> ExposedThing:setPropertyReadHandler(name, handler)

- name 属性名
- handler 处理函数

### setPropertyWriteHandler

设置指定名称的属性的写入处理函数

> ExposedThing:setPropertyWriteHandler(name, handler)

- name 属性名
- handler 处理函数

### addAction

添加一个操作方法

> ExposedThing:addAction(name, action, handler)

- name 操作名称
- action 操作描述
- handler 操作调用处理函数

### removeAction

删除指定名称的操作方法

> ExposedThing:removeAction(name)

- name 要删除的操作的名称

### addEvent

添加一个事件

> ExposedThing:addEvent(name, event)

- name 事件名称
- event 事件描述

### removeEvent

删除指定名称的事件

> ExposedThing:removeEvent(name)

- name 要删除的事件的名称

### expose

导出这个事物

> ExposedThing:expose(options)

- options 选项

### destroy

销毁这个事物

> ExposedThing:destroy()



## ThingClient

### 事件 register

当成功注册到指定的服务器后发出这个事件

> function(result)

- result 注册结果

### 事件 unregister

当从指定的服务器注销后发出这个事件

> function(result)

- result 注销结果

### new

> ThingClient:new(options)

- options 选项
  - thing 这个客户端绑定的事物

### start

开始连接到服务器

> ThingClient:start()

### sendMessage

发送上报消息

> ThingClient:sendMessage(message)

- message 要发送的消息

### sendEvent

发送事件发布消息

> ThingClient:sendEvent(events)

- events 要上报的事件

### sendStream

发送数据流上报消息

> ThingClient:sendStream(streams, options)

- streams 要上报的数据流
- options 选项
  - did 设备 ID

### sendProperty

发送属性上报消息

> ThingClient:sendProperty(properties, options)

- properties 要上报的属性
- options 选项
  - did 设备 ID

### sendResult

发送操作调用应答消息

> ThingClient:sendResult(name, output, message)

- name 操作名
- output 输出参数
- message 操作调用消息

## wot 

### discover

用于发现事物

> wot.discover(filter)

- filter 过滤参数

### fetch

获取指定的 URL 的事物描述文件

> wot.fetch(url)

- url 事物描述文件 URL 地址

### consume

消费 (使用) 指定的事物

> wot.consume(description)

- description 要消费的事物描述

### produce

发布指定的事物

> wot.produce(model)

- model 事件模型描述

### register

注册一个事物到指定的服务器

> wot.register(directory, thing)

- directory 注册服务器地址
- thing 要注册的事物

### unregister

从服务器注销指定的事物

> wot.unregister(directory, thing)

- directory 注册服务器地址
- thing 要注销的事物