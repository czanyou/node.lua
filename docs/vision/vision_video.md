# 视频硬件接口

[TOC]

## lmedia.video_in

### 常量 MAX_CHANNEL_COUNT

    lmedia.video_in.MAX_CHANNEL_COUNT

当前设备支持的最大的视频通道数, 网络摄像机一般为 1

### lmedia.video_in.init

    lmedia.video_in.init()

打开视频输入设备, 在打开视频输入通道之前调用

视频输入通道属于视频输入设备, 网络摄像机只有一个视频输入设备, 且每个视频输入设备只有一个物理视频输入通道, 可以有多个扩展输入通道.


### lmedia.video_in.release

    lmedia.video_in.release()

关闭视频输入设备, 在此之前应先关闭所有视频输入通道.


### lmedia.video_in.open

    lmedia.video_in.open(channel, width, height)

打开指定的视频输入通道, 因为视频输入的大小有限, 所以实际的采样宽高度可能小于设置的宽高度.

- channel {Number} 要打开的视频输入通道号, 0 表示第一个通道, 网络摄像机通常也只有一个输入通道.
- width {Number} 视频采样宽度
- height {Number} 视频采样高度

返回 video_in_t 类的实例

### 类 video_in_t

#### video_in:close

    video_in:close()

关闭这个视频输入通道


#### video_in:connect

    video_in:connect(encoder)

连接到指定的编码器

将视频编码通道绑定到指定的输入通道, 这样当视频输入通道采集到数据时, 将自动发送给编译通道编码, 而无需手动调用.


#### video_in:get_framerate

    video_in:get_framerate()

返回当前视频输入通道的采样帧率


#### video_in:set_framerate

    video_in:set_framerate(framerate)

设置当前视频输入通道的采样帧率, 因为一般视频输入的帧率有限, 所以实际帧率可能会低于设置的帧率.

- framerate {Number} 帧率


## lmedia.video_encoder

实现视频采集功能

调用流程如下:

- video_in.init 初始化视频输入环境
- video_in.open 打开指定的摄像头或视频采集设备
- video_encoder.open 创建一个编码器
- video_in:connect 绑定到指定视频输入源
- encoder:start 开始采集
- encoder:set_attributes 可以编码中改变部分可动态调整的参数, 如码流等
- encoder:stop 停止采集
- encoder:close 关闭并释放编码相关的资源
- video_in:close 关闭相关的视频输入源
- video_in.release 释放所有相关的资源

### 常量 MAX_CHANNEL_COUNT

    lmedia.video_encoder.MAX_CHANNEL_COUNT

支持最大的编码通道数

### 常量 MEDIA_FORMAT_H264

    lmedia.video_encoder.MEDIA_FORMAT_H264

H.264 编码类型

### 常量 MEDIA_FORMAT_JPEG

    lmedia.video_encoder.MEDIA_FORMAT_JPEG

JPEG 编码类型

### lmedia.video_encoder.open

    lmedia.video_encoder.open(channel, options)

- channel {Number} 要创建的视频编码通道号, 0 表示第一个通道, 可以有多个通道, 但注意不要重复打开同一个通道.
- options {Object} 创建属性, 包含分辨率等信息.
    + bitrate {Number} 目标码率，单位为位，如 1000 表示码率为 1000kbps, 即每秒大概产生 125KB 的流量。
    + bitrateMode {Number} 码率控制模式
    + framerate {Number} 目标帧率，单位为帧每秒，如 25 表示每秒产生 25 帧图像。
    + gopLength {Number} GOP 长度，即 I 帧间隔，单位为帧，如 25 表示每隔 25 帧产生一个 I 帧。
    + height {Number} 图像高度，单位为像素，不能超过视频输入通道图像的高度
    + type {Number} 编码类型
    + width {Number} 图像宽度，单位为像素，不能超过视频输入通道图像的宽度

创建一个视频编码通道

### 类 video_encoder_t

#### encoder:close

    encoder:close()

关闭当前视频编码通道


#### encoder:renew

    encoder:renew()

刷新当前视频编码通道, 即请求尽快生成一个 I 帧


#### encoder:set_attributes

     encoder:set_attributes(options)

- options {Object} 通道属性

设置当前视频编码通道的参数


#### encoder:set_crop

    encoder:set_crop(left, top, right, bottom)

设置画面切割大小

- left {Number}
- top {Number}
- right {Number}
- bottom {Number}


#### encoder:start

    encoder:start(flags, callback)

开始编码, 当注册了回调函数时, 会在内部创建一个线程来采集视频并通过回调通知给应用程序.

- flags {Number} 保留使用
- callback {Function} - function(ret, buffer) 当有新的帧时调用这个方法


#### encoder:stop

    encoder:stop()

停止编码, 会停止内部线程, 并停止回调
