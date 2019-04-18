/***
 * The content of this file or document is CONFIDENTIAL and PROPRIETARY
 * to ChengZhen(Anyou).  It is subject to the terms of a
 * License Agreement between Licensee and ChengZhen(Anyou).
 * restricting among other things, the use, reproduction, distribution
 * and transfer.  Each of the embodiments, including this information and
 * any derivative work shall retain this copyright notice.
 *
 * Copyright (c) 2014-2015 ChengZhen(Anyou). All Rights Reserved.
 *
 */
#ifndef _NS_VISION_MEDIA_COMMON_H
#define _NS_VISION_MEDIA_COMMON_H

#include "base_types.h"
#include "media_utils.h"


//_____________________________________________________________________________
///////////////////////////////////////////////////////////////////////////////
// kVideoSourceMaxCount

#define kVideoSourceMaxCount	16

/*  Four-character-code (FOURCC) */
#define media_fourcc(a, b, c, d)\
	((uint32_t)(a) | ((uint32_t)(b) << 8) | ((uint32_t)(c) << 16) | ((uint32_t)(d) << 24))

#define MEDIA_FORMAT_JPEG     media_fourcc('J', 'P', 'E', 'G') /* JFIF JPEG     */
#define MEDIA_FORMAT_H264     media_fourcc('H', '2', '6', '4') /* H264 with start codes */

#define MEDIA_FORMAT_AAC      media_fourcc('A', 'A', 'C', ' ') /* AAC with ADTS */
#define MEDIA_FORMAT_PCM      media_fourcc('P', 'C', 'M', ' ') /* PCM with wavformat */

#define FLAG_IS_SYNC		  0x01

///////////////////////////////////////////////////////////////////////////////
// AudioSettings struct

typedef struct AudioSettings
{
	BOOL fEnabled;			///< 
	UINT fBitrate;			///< 
	UINT fBitrateMode;		///< 
	UINT fCodecFormat;		///< 
	UINT fFlags;			///< 
	UINT fNumChannels;		///< 
	UINT fQuality;			///< 
	UINT fSampleBits;		///< 
	UINT fSampleRate;		///< 
	int  fChannel;
} AudioSettings;


///////////////////////////////////////////////////////////////////////////////
// VideoSettings struct

/** 
 * 定义了视频通道的主要参
 *
 * @author ChengZhen (anyou@msn.com)
 */
typedef struct VideoSettings
{
	BOOL fEnabled;			///< 指出是否启用这个通道
	UINT fBitrate;			///< 视频的目标码 CBR 或最高码 VBR, 单位 bps.
	UINT fBitrateMode;		///< 视频的码流控制模 1: CBR/0: VBR
	UINT fFlags;			///< 视频标记信息
	UINT fFrameRate;		///< 视频的目标帧PAL: 0 ~ 25 / NTSC: 0 ~ 30
	UINT fGopLength;		///< 视频编码 GOP 长度, 单位为帧
	UINT fCodecFormat;		///< 视频的编码类型
	UINT fQuality;			///< 视频的图像质量 0 ~ 5.
	UINT fVideoHeight;		///< 视频的高度, 单位为像素
	UINT fVideoNorm;		///< 视频的制 0:PAL/1:NTSC
	UINT fVideoWidth;		///< 视频的宽度, 单位为像素, 必须 16 的倍数
	BOOL fIsMirror;			///<
	BOOL fIsFlip;			///< 
	UINT fRotate;			///<
	INT  fChannel;			///< 
	
} VideoSettings;


///////////////////////////////////////////////////////////////////////////////
// AudioSampleInfo struct

typedef struct AudioSampleInfo
{
	INT64 fSampleTime;		///< 采集这一音频数据包的时间戳
	UINT  fSequence;		///< 采集序号, 以 1 递增
	UINT  fPacketSize;		///< 这个音频数据包的大小
	BYTE* fPacketData;		///< 这个音频数据包的内容
	void* fPrivateData;		///< 私有信息
	UINT  fFlags;      		///< 标志位
} AudioSampleInfo;


///////////////////////////////////////////////////////////////////////////////
// VideoSampleInfo struct

#define kVideoSampleMaxCount 64

typedef struct VideoSampleInfo
{
	INT64 fSampleTime;		///< 采集这一视频数据包的时间戳
	UINT  fSequence;		///< 采集序号, 以 1 递增
	UINT  fPacketCount;		///< 这个视频帧包含的数据包的数量 
	UINT  fFlags;      		///< 标志位
	UINT  fPacketSize[kVideoSampleMaxCount];
	BYTE* fPacketData[kVideoSampleMaxCount];
	void* fPrivateData;		///< 私有信息
} VideoSampleInfo;


///////////////////////////////////////////////////////////////////////////////

#define E_UNSUPPORTED  	0x84000011
#define E_NOT_READY  	0x84000012

//_____________________________________________________________________________
///////////////////////////////////////////////////////////////////////////////
// Media System

/** 返回媒体处理系统的型号. */
LPCSTR MediaSystemGetType();

/** 返回媒体处理系统的. */
LPCSTR MediaSystemGetVersion();

/** 初始化媒体处理系统, 分配相关的媒体缓存区. */
int MediaSystemInit(int flags);

/** 退出媒体处理系统, 清除相关的媒体缓存区. */
int MediaSystemRelease();

///////////////////////////////////////////////////////////////////////////////
// Audio System

// Audio encode

/** 关闭指定的音频输入通道 */
int AudioInClose(int channel);

/** 采集并编码一下帧, 阻塞模式，只有采集到足够的数据或发生错误时才返回，
 可以在子线程调用这个方法，防止主线程被阻塞. */
int AudioInNextStream(int channel);

/** 从队列中获取一帧音频. 必须调用 AudioInReleaseStream 释放获取的音频帧，
 如果队列为空则返回 0。*/
int AudioInGetStream(int channel, AudioSampleInfo* sampleInfo);

/** 初始化音频输入模块，在所有其他方法前调用 */
int AudioInInit();

/** 打开指定的音频输入通道 */
int AudioInOpen(int channel, AudioSettings* settings);

/** 停止指定的音频输入通道, 中断阻塞的 AudioInNextStream 方法. */
int AudioInStop(int channel);

/** 卸载音频输入模块，在程序退出时调用。*/
int AudioInRelease();

/** 释放指定的音频帧相关的内存空间，必须和 AudioInGetStream 成对出现. */
int AudioInReleaseStream(int channel, AudioSampleInfo* sampleInfo);

// Audio output

/** 关闭指定的音频输出通道. */
int AudioOutClose(int channel);

/** 初始化音频输出模块，在所有其他方法前调用 */
int AudioOutInit();

/** 打开指定的音频输出通道 */
int AudioOutOpen(int channel, int format);

/** 卸载音频输出模块，在程序退出时调用。*/
int AudioOutRelease();

/** 输出(播放)音频流到指定的输出通道 */
int AudioOutWriteSample(int channel, AudioSampleInfo* sampleInfo);

///////////////////////////////////////////////////////////////////////////////
// Video System

// encode channel
int VideoEncodeBind(int channel, int videoInput);

/** 关闭指定的视频编码器。*/
int VideoEncodeClose(int channel);

/** 获取动态编码属性。*/
int VideoEncodeGetAttributes(int channel, VideoSettings* settings);

/** 从队列中获取一帧音频. 必须调用 VideoEncodeReleaseStream 释放获取的音频帧，
 如果队列为空则返回 0。*/
int VideoEncodeGetStream(int channel, VideoSampleInfo* streamInfo);

/** 采集并编码一下帧, 阻塞模式，只有采集到足够的数据或发生错误时才返回，
 可以在子线程调用这个方法，防止主线程被阻塞. */
int VideoEncodeNextStream (int channel, BOOL isBlocking);

/** 打开指定的视频编码器。*/
int VideoEncodeOpen(int channel, VideoSettings* settings);

/** 释放指定的视频帧相关的内存空间，必须和 VideoEncodeGetStream 成对出现. */
int VideoEncodeReleaseStream(int channel, VideoSampleInfo* streamInfo);

/** 请求尽快生成关键帧。*/
int VideoEncodeRenewStream(int channel);

/** 设置动态编码属性。*/
int VideoEncodeSetAttributes(int channel, VideoSettings* settings);

/** 设置剪切区域。*/
int VideoEncodeSetCrop(int channel, int l, int t, int w, int h);

/** 开启指定的视频编码器。*/
int VideoEncodeStart(int channel, int flags);

/** 停止指定的视频编码器，之后可以调用 VideoEncodeStart 重新开始。*/
int VideoEncodeStop(int channel);

// video input

/** 关闭指定的视频输入通道 */
int VideoInClose(int channel);

/** 返回当前视频输入通道原始视频采集帧率. */
int VideoInGetFrameRate(int channel);

/** 初始化视频输入模块，在所有其他方法前调用 */
int VideoInInit(UINT flags); 

/** 打开指定的视频输入通道 */
int VideoInOpen(int channel, int width, int height, int flags);

/** 卸载视频输入模块，在程序退出时调用。*/
int VideoInRelease();

/** 设置当前视频输入通道原始视频采集帧率. */
int VideoInSetFrameRate(int channel, UINT frameRate);

// video overlay
int VideoOverlayClose(int regionId);
int VideoOverlayOpen(int regionId, int width, int height);
int VideoOverlaySetBitmap(int regionId, int width, int height, BYTE* data);

#endif //_NS_VISION_MEDIA_COMMON_H
