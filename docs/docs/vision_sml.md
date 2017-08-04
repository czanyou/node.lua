# SML 简单媒体层抽象接口

[TOC]

Node.lua 需要在多个平台上运行，但各个平台的外围硬件实现有很大的差异。
通过 libsml，用于将各平台媒体功能以及外围硬件接口抽象成一样的媒体层访问接口。

## 接口定义

详见： `targets/common/media_comm.h` 

定义了统一的媒体层访问接口。各开发板需实现这些接口以便提供相关的服务。

## 主要功能

- 视频输入和采集
- 视频编码
- 视频文字叠加
- 音频输入和采集
- 音频输出和回放
- 音频编解码

## 多媒体系统

### MediaSystemGetType

返回媒体处理系统的型号. 

    LPCSTR MediaSystemGetType();

### MediaSystemInit

初始化媒体处理系统, 分配相关的媒体缓存区. 

    int MediaSystemInit(int mmzSize);

### MediaSystemRelease

退出媒体处理系统, 清除相关的媒体缓存区.

    int MediaSystemRelease();

## 音频输入

### AudioInRelease

    int AudioInRelease();

关闭音频输入模块并释放相关的资源

### AudioInInit

    int AudioInInit();

初始化音频输入模块, 必须在调用其他音频输入 API 之前调用。

### AudioInSetAttributes

    int AudioInSetAttributes(int flags);

### AudioInClose

    int AudioInClose         (int channel);

关闭打开的音频输入通道

- channel 要关闭的通道号

### AudioInOpen

    int AudioInOpen          (int channel, int format);

打开指定的音频输入通道

- channel 要打开的通道号，如果设备只有一个通道则为 0.

## 音频输出

### AudioOutRelease

    int AudioOutRelease();

### AudioOutInit

    int AudioOutInit();

### AudioOutSetAttributes

    int AudioOutSetAttributes(int flags);

### AudioOutBind

    int AudioOutBind(int channel, int inChannel, int decodeId);

### AudioOutClose

    int AudioOutClose(int channel);

### AudioOutOpen

    int AudioOutOpen(int channel, int format);

## 音频编码

### AudioInCloseEncode

    int AudioInCloseEncode(int channel, int encodeId);

### AudioInGetStream

    int AudioInGetStream(int encodeId, AudioSampleInfo* sampleInfo, BOOL isBlocking);

### AudioInOpenEncode

    int AudioInOpenEncode(int channel, int encodeId, int format);

### AudioInReleaseStream

    int AudioInReleaseStream(int encodeId, AudioSampleInfo* sampleInfo);

## 音频解码

### AudioOutCloseDecode

    int AudioOutCloseDecode(int channel, int decodeId);

### AudioOutOpenDecode

    int AudioOutOpenDecode(int channel, int decodeId, int format);

### AudioOutWriteSample

    int AudioOutWriteSample(int decodeId, AudioSampleInfo* sampleInfo);

## 视频输入 

### VideoInRelease

    int  VideoInRelease();

关闭视频输入并释放相关的资源

### VideoInInit

    int  VideoInInit(UINT flags); 

初始化视频输入模块

### VideoInClose

    int  VideoInClose(int channel);

### VideoInGetDescriptor

    int  VideoInGetDescriptor(int channel);

### VideoInGetFrameRate

    int  VideoInGetFrameRate(int channel);

### VideoInOpen

    int  VideoInOpen(int channel, int width, int height );

### VideoInSetFrameRate

    int  VideoInSetFrameRate(int channel, UINT frameRate );

## 视频编码

### VideoEncodeBind

    int  VideoEncodeBind(int channel, int videoInput);

### VideoEncodeClose

    int  VideoEncodeClose(int channel);

### VideoEncodeGetDescriptor

    int  VideoEncodeGetDescriptor(int channel);

### VideoEncodeGetPacketCount

    int  VideoEncodeGetPacketCount(int channel);

### VideoEncodeGetStream

    int  VideoEncodeGetStream(int channel, VideoSampleInfo* streamInfo);

### VideoEncodeOpen

    int  VideoEncodeOpen(int channel, VideoSettings* settings);

### VideoEncodeReleaseStream

    int  VideoEncodeReleaseStream(int channel, VideoSampleInfo* streamInfo);

### VideoEncodeRenewStream

    int  VideoEncodeRenewStream(int channel);

### VideoEncodeSetAttributes

    int  VideoEncodeSetAttributes(int channel, VideoSettings* settings);

### VideoEncodeSetCrop

    int  VideoEncodeSetCrop(int channel, int l, int t, int w, int h);

### VideoEncodeStart

    int  VideoEncodeStart(int channel);

### VideoEncodeStop

    int  VideoEncodeStop(int channel);

## 视频叠加

### VideoOverlayClose

    int  VideoOverlayClose(int regionId);

### VideoOverlayOpen

    int  VideoOverlayOpen(int regionId, int width, int height);

### VideoOverlaySetBitmap

    int  VideoOverlaySetBitmap(int regionId, int width, int height, BYTE* data);


## 示例

### 音频采集流程 

### 音频播放流程 

### 视频采集流程 

```c

MediaSystemInit();

VideoInInit();

int channel = 0;

VideoInOpen(channel, 0, 0);

VideoSettings settings;
memset(&settings, 0, sizeof(settings));
settings.fWidth   = 1280;
settings.fHeight  = 720;
...

VideoEncodeOpen(channel, &settings);
VideoEncodeStart(channel);

while (isRunning) {
    VideoSampleInfo sampleInfo;
    memset(&sampleInfo, 0, sizeof(sampleInfo));

    VideoEncodeGetStream(channel, &sampleInfo);

    // ...

    VideoEncodeReleaseStream(channel, &sampleInfo);
}

VideoEncodeStop(channel);
VideoEncodeClose(channel);

VideoInClose(channel);
VideoInRelease();

MediaSystemRelease();

```