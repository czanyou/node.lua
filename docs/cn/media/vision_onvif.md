# ONVIF 客户端

用来访问和控制 ONVIF 协议的监控摄像机。

通过 `require('onvif')` 调用

## createClient

> local onvifClient = onvif.createClient(options)

创建一个新的 OnvifClient 类实例

- options `{object}` 选项
  - ip `{string}` 摄像机 IP 地址
  - username `{string}` 用户名
  - password `{string}` 密码

- onvifClient `{OnvifClient}` 返回创建的实例

## 类 OnvifClient

### 属性

- options `{object}` 选项
- deviceInformation `{object}` 设备信息

### initialize

> initialize(options)

初始化

### 设备信息

#### getCapabilities

> getCapabilities(function(capabilities) end)

获取摄像机能力信息

callback `{function(capabilities)}`

- capabilities `{object}`

#### getServices

> getServices(function(services) end)

获取摄像机服务信息

callback `{function(services)}`

- services `{object}`

#### getDeviceInformation

> getDeviceInformation(function(deviceInformation) end)

获取摄像机设备信息

callback `{function(deviceInformation)}`

- deviceInformation `{object}`

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

> getProfiles(function(err, profiles) end)

获取媒体 Profile 信息

- callback `{function(err, profiles)}`
  - profiles `{array}`

#### getVideoSources

> getVideoSources(function(videoSources) end)

获取媒体视频信息

- callback `{function(videoSources)}`
  - videoSources`{array}`

#### getStreamUri

> getStreamUri(index, function(err, uri) end)

获取视频流的 URL

- index `{integer}` 通道号，从 1 开始
- callback `{function(uri)}`
  - uri `{string}` 视频流的 URL 地址

#### getSnapshotUri

> getSnapshotUri(index, function(err, uri) end)

获取抓拍图片的 URL

- index `{integer}` 通道号，从 1 开始
- callback `{function(uri)}`
  - uri `{string}` 图片的 URL 地址
