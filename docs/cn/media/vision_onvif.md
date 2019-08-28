# ONVIF 客户端

用来访问和控制 ONVIF 协议的监控摄像机。

通过 `require('onvif')` 调用

## camera

> local camera = onvif.camera(options)

创建一个新的 OnvifCamera 类实例

- options {object} 选项
  - ip {string} 摄像机 IP 地址
  - username {string} 用户名
  - password {string} 密码

- camera {OnvifCamera} 返回创建的实例

## 类 OnvifCamera

### 属性

- options {object} 选项
- deviceInformation {object} 设备信息

### initialize

> initialize(options)

初始化

### 设备信息

#### getCapabilities

> getCapabilities(function(capabilities) end)

获取摄像机能力信息

callback `{function(capabilities)}`

- capabilities` {object}`

#### getServices

> getServices(function(services) end)

获取摄像机服务信息

callback `{function(services)}`

- services` {object}`

#### getDeviceInformation

> getDeviceInformation(function(deviceInformation) end)

获取摄像机设备信息

callback `{function(deviceInformation)}`

- deviceInformation` {object}`

### 云台操作

#### getPresets

> getPresets(function(presets) end)

返回所有已存在的预置位

- preset `{integer}` 预置点索引，从 1 开始
- callback `{function(presets)}`
  - presets

#### removePreset

> removePreset(preset, function() end)

删除预置位

- preset `{integer}` 预置点索引，从 1 开始
- callback `{function()}`

#### gotoPreset

> gotoPreset(preset, function() end)

转到预置位

- preset `{integer}` 预置点索引，从 1 开始
- callback `{function()}`

#### setPreset

> setPreset(preset, function() end)

设置预置位

- preset `{integer}` 预置点索引，从 1 开始
- callback `{function()}`

#### stopMove

> stopMove(function() end)

停止 PTZ 移动

- callback `{function()}`

#### continuousMove

> continuousMove(x, y, z, function() end)

移动 PTZ

- x `{integer}` 1 或 -1
- y `{integer}`  1 或 -1
- z `{integer}`  1 或 -1
- callback `{function()}`

### 媒体信息

#### getProfiles

> getProfiles(function(profiles) end)

获取媒体 Profile 信息

- callback `{function(profiles)}`
  - profiles `{array}`

#### getVideoSources

> getVideoSources(function(videoSources) end)

获取媒体视频信息

- callback `{function(videoSources)}`
  - videoSources`{array}`

#### getStreamUri

> getStreamUri(index, function(uri) end)

获取视频流的 URL

- index `{integer}` 通道号，从 1 开始
- callback `{function(uri)}`
  - uri `{string}` 视频流的 URL 地址

#### getSnapshotUri

> getSnapshotUri(index, function(uri) end)

获取抓拍图片的 URL

- index `{integer}` 通道号，从 1 开始
- callback `{function(uri)}`
  - uri `{string}` 图片的 URL 地址

## XML 工具模块

用来解析 XML 文档的简单工具

通过 `require('onvif/xml')` 来调用

### newParser

> local parser = xml.newParser()

创建一个新的 XML 解析器

- parser {XmlParser} 返回创建的解析器

### 类 XmlParser

#### ToXmlString

> parser.ToXmlString(value)

编码 XML 字符串，将字符串中的特殊符号转码成 XML 可以接受的格式

- value {string} 要编码的字符串

#### FromXmlString

> parser.FromXmlString(value)

解析 XML 字符串，将编码过的字符串还原成原始的格式

- value {string} 要解析的字符串

#### ParseArgs

> parser.ParseArgs(node, s)

解析 XML 节点属性

- node {XmlNode} 要解析的节点
- s {string} 要解析的字符串

#### ParseXmlText

> local topNode = parser.ParseXmlText(xmlText)

解析 XML 文档

- xmlText {string} 要解析的 XML 文档

### 类 XmlNode

#### value

> local value = node.value()

返回 XML 节点的值

#### setValue

> node.setValue(value)

设置 XML 节点的值

- value {string} 节点值

#### name

> local name = node.name()

返回 XML 节点的名称

#### setName

> node.setName(name)

设置 XML 节点的名称

- name {string} 节点名称

#### children

> local children = node.children()

返回 XML 节点的所有子节点

#### numChildren

> local count = node.numChildren()

返回 XML 节点的子节点数量

#### addChild

> node.addChild(childNode)

添加一个子节点

#### properties

> local properties = node.properties()

返回 XML 节点的所有属性

#### numProperties

> local count = node.numProperties()

返回XML 节点的属性的数量

#### addProperty

> node.addProperty(name, value)

添加一个新的属性

- name {string} 属性名
- value {string} 属性值