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
#ifndef _VISION_TS_READER_H
#define _VISION_TS_READER_H

#include "ts_common.h"

/**
 * TS 流复用器.
 * 注意目前只支持 H.264 等基本类型的流.
 */
typedef struct ts_reader_t
{
	uint8_t* fCacheBuffer;		/** 内部缓存区. */
	uint8_t* fPacketBuffer;	/** 最终输出 TS 包的内部缓存区. */
	uint32_t  fAudioCodec;
	uint32_t  fAudioId;			/** Audio PID */
	uint32_t  fPMTId;			/** PMT PID */
	uint32_t  fVideoCodec;
	uint32_t  fVideoId;			/** Video PID */
	uint32_t  fCacheSize;		/** 当前内部缓存区缓存的流的长度. */
  	int   fCallback;		/** 回调函数句柄(用于 Lua 绑定). */
  	void* fState;  			/** 回调函数相关状态(用于 Lua 绑定). */
} ts_reader_t;

/**
 * 初始化, 须在所有其他方法前调用
 */
int ts_reader_init		(ts_reader_t* reader);

/**
 * 释放相关的资源, 须在所有其他方法后调用
 */
int ts_reader_release	(ts_reader_t* reader);

/**
 * 写入一段 TS 流媒体数据
 * 当前接口支持以流的方法写入媒体数据, 即可以任意分割传入数据。
 * @param data TS 流媒体数据
 * @param length 媒体数据长度
 * @param flags 标记信息，暂未用到
 */
int ts_reader_read  	(ts_reader_t* reader, const uint8_t* data, uint32_t length, int flags);

/**
 * TS 解析回调函数
 * 当生成新的流数据包时, 会调用这个方法.
 * 注意这个方法并不会返回完整的一帧，一般只返回一帧的一部分数据，返回的数据中只包含 ES 流数据。
 * 一般每解析一个 TS 包就会返回这个 TS 包中包含的数据分片，应用程序需要自己拼合完整的帧。
 * @param data 流数据包数据
 * @param length 流数据包长度
 * @param sampleTime 媒体数据时间戳, 单位为 1/1000,1000 秒
 * @param flags 相关标记, 当 flags 为 MUXER_FLAG_IS_START 表示这是新的一帧的开始。
 */
int ts_reader_on_sample (ts_reader_t* reader, const uint8_t* data, uint32_t length, int64_t sampleTime, int flags);


#endif //_VISION_TS_READER_H
