# Bluetooth 蓝牙

## Bluetooth Script API

蓝牙相关的 API

### requestDevice

> bluetooth.requestDevice(options)

这个方法用于请求一个蓝牙设备对象, 以使后续和蓝牙模块以及远程的蓝牙设备进行交互

- options `{object}` 选项

```lua

local options = {}

bluetooth.requestDevice(options, function(device)
  console.log('名称: ',  device.name);
  -- 在此处实现设备调用
end)

```

### 蓝牙设备

`BluetoothDevice` 代表了一个蓝牙设备。

#### 事件

##### advertisementreceived

> function(event)

- event
  - device `{BluetoothDevice}` 相关的蓝牙设备
  - manufacturerData `{string}` 制造商数据
  - serviceData `{string}` 服务数据
  - rssi `{number}` 接收信号强度，单位为 dBm
  - txPower `{number}` 发射功率强度，单位为 dBm
  - name `{string}` 从机名称
  - appearance `{number}` 从机外观参数

##### gattserverdisconnected 

> function(event)

- event
  - device `{BluetoothDevice}` 相关的蓝牙设备

##### characteristicvaluechanged

> function(event)

- event
  - characteristic `{BluetoothGATTCharacteristic}` 发生改变的特征值
    - value `{string}` 发生改变后的值


#### 属性

- id `{string}` 一个设备的唯一 ID
- name `{string}` 设备的人类可读的名称
- gatt `{BluetoothRemoteGATTServer}` GATT 服务器的引用
- watchingAdvertisements `{boolean}` 如果正在侦听广播

#### watchAdvertisements 方法

> watchAdvertisements(callback)

开始侦听广播

- callback `{function()}`

#### unwatchAdvertisements 方法

> unwatchAdvertisements()

停止侦听广播

### GATT 服务器

`BluetoothRemoteGATTServer` 接口代表远程设备上的 GATT 服务器。

#### 属性

- connected `{boolean}` 指出是否已连接到远程服务器
- device `{BluetoothDevice}` 所属的蓝牙设备

#### connect 方法

> connect(callback)

请求连接指定的远程设备

- callback `{function(server)}`
    - server `{BluetoothRemoteGATTServer}` GATT 服务器

#### disconnect 方法

> disconnect()

请求断开当前的连接

#### getPrimaryService 方法

> getPrimaryService(uuid, callback)

返回指定的 UUID 的 GATT 服务

- uuid `{string}` 服务的 UUID
- callback `{function(service)}`
  - service `{BluetoothRemoteGATTService}` GATT 服务

#### getPrimaryServices 方法

> getPrimaryServices(uuid, callback)

返回所有的 GATT 服务

- uuid `{string}` 服务的 UUID
- callback `{function(services)}`
  - services `{array of BluetoothRemoteGATTService}` GATT 服务

### GATT 服务

`BluetoothRemoteGATTService` 接口表示由 GATT 服务器提供的服务，包括设备、引用服务列表和该服务的特征列表。

#### 事件

##### characteristicvaluechanged

- event
  - characteristic `{BluetoothGATTCharacteristic}` 发生改变的特征值
    - value `{string}` 发生改变后的值

#### 服务属性

- device `{BluetoothDevice}` 所属的蓝牙设备的信息
- isPrimary `{boolean}` 指出是否是 primary 服务
- uuid `{string}` 这个服务的 UUID

#### getCharacteristic 方法

> getCharacteristic(uuid, callback)

返回指定 UUID 的特征值

- uuid `{string}` 特征值 UUID
- callback `{function(characteristic)}`
  - characteristic `{BluetoothGATTCharacteristic}` 特征值

#### getCharacteristics 方法

> getCharacteristics(uuid, callback)

返回所有的特征值

- uuid `{string}` 可选, 特征值 UUID
- callback `{function(characteristics)}`
  - characteristics `{array of BluetoothGATTCharacteristic}` 特征值

### GATT 特征值

`BluetoothRemoteGATTCharacteristic` 接口代表了一个 GATT 特性，它是一个基本的数据元素，提供了关于外围设备服务的更多信息。

#### 特征值属性

- service `{BluetoothRemoteGATTService}` 所属的 BluetoothGATTService
- uuid `{UUID string}` 这个特征值的 UUID 字符串
- properties `{object}` 这个特征值的属性
  - broadcast `{boolean}` Broadcast
  - read `{boolean}` Read
  - writeWithoutResponse `{boolean}` Write Without Response
  - write `{boolean}`	Write
  - notify `{boolean}` Notify
  - indicate `{boolean}` Indicate
  - authenticatedSignedWrites `{boolean}` Authenticated Signed Writes
- value `{string}` 当前缓存的特征值的值

#### getDescriptor 方法

> getDescriptor(uuid, callback)

返回指定 UUID 的描述符

- uuid `{string}` 描述符 UUID
- callback `{function(descriptor)}`
  - descriptor `{BluetoothRemoteGATTDescriptor}` 描述符

#### getDescriptors 方法

> getDescriptors(uuid, callback)

返回所有描述符

- uuid `{string}` 可选，描述符 UUID
- callback `{function(descriptors)}`
  - descriptors `{array of BluetoothRemoteGATTDescriptor}` 描述符

#### readValue 方法

> readValue(callback)

读取特征值的值

- callback `{function(value)}`
  - value `{string}` 读到的值

#### writeValue 方法

> writeValue(value, callback)

读入特征值的值

- value `{string}` 要写入的值
- callback `{function()}`

#### startNotifications 方法

> startNotifications(callback)

开始接收通知

- callback `{function()}`

#### stopNotifications 方法

> stopNotifications(callback)

停止接收通知

- callback `{function()}`


### GATT 描述符

`BluetoothRemoteGATTDescriptor` 接口提供了一个 GATT 描述符，它提供了关于特征值的更多信息。

#### 描述符属性

- characteristic `{BluetoothGATTCharacteristic}` 所属的 BluetoothGATTCharacteristic
- uuid `{string}` 这个描述符的 UUID
- value `{string}` 当前缓存的描述符值, 这个值在执行读操作后会被更新

#### readValue 方法

> readValue(callback)

读取描述符值

- callback `{function(value)}`
  - value `{string}` 读到的描述符值

#### writeValue 方法

> writeValue(value, callback)

写入描述符值

- value `{string}`
- callback `{function(value)}`
  - value `{string}` 要写入的值
