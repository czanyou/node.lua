# Camera 相机

[TOC]

摄像机访问接口

通过 `require('media/camera')` 调用。

## camera.open(cameraId, options)

打开并返回指定 ID 的摄像机

- cameraId
- options

## 类 `Camera`

### 事件 'close'

当设备被关闭

### reconnect()

更新连接

### release()

关闭并释放

### setPreviewCallback(callback)

设置预览回调函数，当采集到新的图像时调用这个函数

- callback(sample) 

sample: 

- syncPoint
- sampleData
- sampleTime


### startPreview()

开始预览

### stopPreview()

停止预览

### takePicture(callback, options)

异步抓拍一张图片

- callback
- options
