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
#ifndef _VISION_TS_WRITER_H
#define _VISION_TS_WRITER_H

#include "ts_common.h"

/**
 * TS 流复用器.
 * 注意目前只支持 H.264 等基本类型的流.
 */
typedef struct ts_writer_t
{
	uint8_t* fCacheBuffer;			/** 内部缓存区. */
	uint8_t* fPacketBuffer;			/** 最终输出 TS 包的内部缓存区. */
	uint32_t fAudioCodec;			/** 当前 TS 流的音频流的编码类型. */
	uint32_t fAudioID;				/** 当前 TS 流的音频流的 ID. */
	uint32_t fCacheSize;			/** 当前内部缓存区缓存的流的长度. */
	uint32_t fFrameSize;			/** 当前帧的已经处理的长度. */
	uint32_t fPATContinuityCounter;	/** PAT 计数器. */
	uint32_t fPESContinuityCounter;	/** PES 计数器. */
	uint32_t fPESPacketCounter;		/** 计数器, 表示示前帧已生成的 TS 包的数量. */
	uint32_t fPMTContinuityCounter;	/** PMT 计数器. */
	uint32_t fVideoCodec;			/** 当前 TS 流的视频流的编码类型. */
	uint32_t fVideoID;				/** 当前 TS 流的视频流的 ID. */
  	int      fCallback;				/** 回调函数句柄(用于 Lua 绑定). */
  	void*    fState;  				/** 回调函数相关状态(用于 Lua 绑定). */

} ts_writer_t;

/**
 * 初始化, 须在所有其他方法前调用
 */
int ts_writer_init			(ts_writer_t* writer);

/**
 * 释放相关的资源, 须在所有其他方法后调用
 */
int ts_writer_release		(ts_writer_t* writer);

/**
 * 写入一段原始媒体数据
 * 当前接口支持以流的方法写入媒体数据, 即不需要提供一次性提供完整的一帧数据,
 * 但请注意要用 MUXER_FLAG_IS_END 标记一帧的结束
 * @param data 媒体数据
 * @param length 媒体数据长度
 * @param sampleTime 媒体数据时间戳, 单位为 1/1000,1000 秒
 * @param flags 相关标记, 请参考 MUXER_FLAG_XXXX 相关定义
 */
int ts_writer_write_sample  (ts_writer_t* writer, uint8_t* data, uint32_t length, int64_t sampleTime, int flags);
int ts_writer_write_sync_info(ts_writer_t* writer, int64_t sampleTime);

/**
 * 回调函数
 * 当生成新的 TS 流数据包时, 会调用这个方法.
 * @param data TS 流数据包数据
 * @param length TS 流数据包长度, 一般为 188 个字节
 * @param sampleTime 媒体数据时间戳, 单位为 1/1000,1000 秒
 * @param flags 标记, 请参考 MUXER_FLAG_XXXX 相关定义
 */
int ts_writer_on_ts_packet (ts_writer_t* writer, uint8_t* data, uint32_t length, int64_t sampleTime, int flags);

#endif // _VISION_TS_WRITER_H

