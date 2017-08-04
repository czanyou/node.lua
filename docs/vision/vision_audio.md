# 音频硬件接口

[TOC]

## lmedia.audio_in

实现音频输入(录音)功能.

调用流程为:

- audio_in.init 初始化音频输入环境
- audio_in.open 打开一个音频输入通道
- audio_in:start 启动音频采集
- audio_in:stop 停止音频采集
- audio_in:close 关闭音频输入通道
- audio_in.release 在程序退出前调用以释放所有相关的资源

### 常量 MAX_CHANNEL_COUNT

    lmedia.audio_in.MAX_CHANNEL_COUNT

当前设备支持的最大的通道数, 网络摄像机一般为 1

### 常量 MEDIA_FORMAT_PCM

表示 PCM 编码类型

### 常量 MEDIA_FORMAT_AAC

表示带 ADTS 头的 AAC 编码类型


### lmedia.audio_in.init

    lmedia.audio_in.init()

初始化音频输入模块, 如加载相关的模块或初始化相关的设备等, 在调用其他所有方法前调用.


### lmedia.audio_in.release

    lmedia.audio_in.release()

关闭音频输入模块并释放相关的资源。在程序结束调用这个方法.


### lmedia.audio_in.open

    lmedia.audio_in.open(channel, options)

打开指定的音频输入通道

- channel {Number} 要打开的音频输入通道号, 0 表示第一个通道, 网络摄像机通常也只有一个输入通道.
- options {Object} 选项
  + sampleRate {Number} 采样率, 没指定的话为 8000
  + sampleBits {Number} 样本大小, 没指定的话为 16bit
  + channels {Number} 通道数, 没有指定的话为 1, 2 则表示立体声
  + codec {Number} 编码格式, 默认为 MEDIA_FORMAT_PCM

### 类 audio_in_t


#### audio_in:close

    audio_in:close()

关闭这个音频输入通道


#### audio_in:start
 
     audio_in:start(callback)

开始采集, 采集得到的数据通过注册的回调函数返回给应用程序.

- callback {Function} `-function(data)`


#### audio_in:stop

    audio_in:stop()

停止采集


## lmedia.audio_out

实现音频输出(播放)功能.

调用流程通常为:

- audio_out.init 初始化模块
- audio_out.open 打开一个输出通道
- audio_out:write 反复调用输出要播放的音频数据
- audio_out:close 关闭并停止音频输出
- audio_out.release 在程序退出前调用释放相关的所有资源



### 常量 MAX_CHANNEL_COUNT

    lmedia.audio_out.MAX_CHANNEL_COUNT

当前设备支持的最大的通道数, 网络摄像机一般为 1

### 常量 MEDIA_FORMAT_PCM

表示 PCM 编码类型

### 常量 MEDIA_FORMAT_AAC

表示带 ADTS 头的 AAC 编码类型


### lmedia.audio_out.init

    lmedia.audio_out.init()

初始化音频输出模块, 加载需要的模块或初始化相关的设备.

应当在调用其他所有方法前先调用这个接口.


### lmedia.audio_out.release

    lmedia.audio_out.release()

关闭音频输出模块并释放相关的资源, 在程序退出前调用.

应当在调用这个方法前关闭所有的音频输出通道.


### lmedia.audio_out.open

    lmedia.audio_out.open(channel, options)

打开指定的音频输出通道

- channel {Number} 要打开的音频输出通道号, 0 表示第一个通道, 网络摄像机通常也只有一个输出通道.
- options {Object|Number} 选项, 默认为 MEDIA_FORMAT_PCM

### 类 audio_out_t


#### audio_out:close

    audio_out:close()

关闭音频输出通道并释放相关的资源.


#### audio_out:write

    audio_out:write(data)

- data {String} 要播放的音频流数据