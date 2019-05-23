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
#ifndef _VISION_TS_COMMON_H
#define _VISION_TS_COMMON_H

#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <math.h>

#ifndef bool_t
#define bool_t int
#endif

#ifndef TRUE
#define TRUE 1
#endif

#ifndef FALSE
#define FALSE 0
#endif

/**
 * 当前支持的音视频编码格式
 */
enum ts_codec_types {
	STREAM_TYPE_AUDIO_AAC   = 0x0F,
	STREAM_TYPE_VIDEO_MPEG4 = 0x10,
	STREAM_TYPE_VIDEO_H264  = 0x1B,
	STREAM_TYPE_AUDIO_LPCM  = 0x80,
};

/**
 * 帧的开始标记, 即表示当前数据分片是一个媒体帧的第一段数据.
 * 一般一帧的长度是不确定的, 可能由多个分片组成.
 */
#ifndef MUXER_FLAG_IS_START
#define MUXER_FLAG_IS_START	0x04
#endif

/**
 * 帧的结束标记, 即表示当前数据分片是一个媒体帧的最后一段数据.
 */
#ifndef MUXER_FLAG_IS_END
#define MUXER_FLAG_IS_END	0x02
#endif

/**
 * 数据流同步标记, 一般解码器从同步点的位置开始解码, 如果找不到同步点可能将无法解码
 * 如视频流的同步点一般在 I 帧的开始位置.
 */
#ifndef MUXER_FLAG_IS_SYNC
#define MUXER_FLAG_IS_SYNC	0x01
#endif

/**
 * 表示音频流
 */
#ifndef MUXER_FLAG_IS_AUDIO
#define MUXER_FLAG_IS_AUDIO	0x8000
#endif

#endif // _VISION_TS_COMMON_H