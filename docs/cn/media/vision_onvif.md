# ONVIF 客户端

## camera

> onvif.camera(options)

## 类 OnvifCamera

### 属性

- options {object} 选项
- deviceInformation {object} 设备信息

### initialize

> initialize(options)

初始化

### getDeviceInformation

> getDeviceInformation(callback)

获取摄像机设备信息

callback `{function(deviceInformation)}`

- deviceInformation` {object}`

### 云台操作

#### getPresets

> getPresets(callback)

返回所有已存在的预置位

- preset `{integer}` 预置点索引，从 1 开始
- callback `{function(presets)}`
  - presets

#### removePreset

> removePreset(preset, callback)

删除预置位

- preset `{integer}` 预置点索引，从 1 开始
- callback `{function()}`

#### gotoPreset

> gotoPreset(preset, callback)

转到预置位

- preset `{integer}` 预置点索引，从 1 开始
- callback `{function()}`

#### setPreset

> setPreset(preset, callback)

设置预置位

- preset `{integer}` 预置点索引，从 1 开始
- callback `{function()}`

#### stopMove

> stopMove(callback)

停止 PTZ 移动

- callback `{function()}`

#### continuousMove

> continuousMove(x, y, z, callback)

移动 PTZ

- x `{integer}` 1 或 -1
- y `{integer}`  1 或 -1
- z `{integer}`  1 或 -1
- callback `{function()}`

### 媒体信息

#### getProfiles

> getProfiles(callback)

获取媒体 Profile 信息

- callback `{function(profiles)}`
  - profiles `{array}`

#### getStreamUri

> getStreamUri(index, callback)

获取视频流的 URL

- index `{integer}` 通道号，从 1 开始
- callback `{function(uri)}`
  - uri `{string}` 视频流的 URL 地址

#### getSnapshotUri

> getSnapshotUri(index, callback)

获取抓拍图片的 URL

- index `{integer}` 通道号，从 1 开始
- callback `{function(uri)}`
  - uri `{string}` 图片的 URL 地址