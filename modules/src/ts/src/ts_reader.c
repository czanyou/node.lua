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
#include "ts_reader.h"

enum ts_defines 
{
	TS_PACKET_SIZE			= 188,
	TS_PAYLOAD_SIZE			= 184,
	TS_START_CODE			= 0x47,

	TS_PAT_PID				= 0x0000,

	TS_PAT_TABLE_ID			= 0x00,
	TS_PMT_TABLE_ID			= 0x02,
	TS_PTS_BASE				= 63000,

	AUDIO_STREAM_TYPE 		= 0xC0,
	VIDEO_STREAM_TYPE 		= 0xE0

};

int64_t ts_reader_parse_pts(ts_reader_t* reader, const uint8_t* data);

int ts_reader_init(ts_reader_t* reader)
{
	if (reader == NULL) {
		return 0;
	}

  	reader->fAudioCodec		= 0;
  	reader->fAudioId 		= 0;
  	reader->fCacheBuffer 	= NULL;
  	reader->fCacheSize 		= 0;
  	reader->fCallback 		= 0;
  	reader->fPMTId 			= 0;
  	reader->fState			= NULL;
  	reader->fVideoCodec 	= 0;
  	reader->fVideoId 		= 0;

	return 0;
}

int ts_reader_release(ts_reader_t* reader)
{
	if (reader == NULL) {
		return 0;
	}

	if (reader->fCacheBuffer) {
		free(reader->fCacheBuffer);
		reader->fCacheBuffer = NULL;
	}

	reader->fState 			= NULL;
  	reader->fCacheSize 		= 0;

	return 0;
}

int ts_reader_parse_pat( ts_reader_t* reader, const uint8_t* data, int flags )
{
	if (reader == NULL || data == NULL) {
		return 0;
	}

	int offset = 5;

	/*

	typedef struct TS_PAT_Program  
	{  
	    unsigned program_number   :  16;  // 节目号  
	    unsigned program_map_PID  :  13;  // 节目映射表的PID，节目号大于0时对应的PID，每个节目对应一个  
	} TS_PAT_Program  

	typedef struct TS_PAT  
	{  
	    unsigned table_id                     : 8;  // 固定为0x00 ，标志是该表是PAT表  
	    unsigned section_syntax_indicator     : 1;  // 段语法标志位，固定为1  
	    unsigned zero                         : 1;  // 0  
	    unsigned reserved_1                   : 2;  // 保留位  
	    unsigned section_length               : 12; // 表示从下一个字段开始到CRC32(含)之间有用的字节数  
	    unsigned transport_stream_id          : 16; // 该传输流的ID，区别于一个网络中其它多路复用的流  
	    unsigned reserved_2                   : 2;  // 保留位  
	    unsigned version_number               : 5;  // 范围0-31，表示PAT的版本号  
	    unsigned current_next_indicator       : 1;  // 发送的PAT是当前有效还是下一个PAT有效  
	    unsigned section_number               : 8;  // 分段的号码。PAT可能分为多段传输，第一段为00，以后每个分段加1，最多可能有256个分段  
	    unsigned last_section_number          : 8;  // 最后一个分段的号码  
	   
	    std::vector<TS_PAT_Program> program;  
	    unsigned reserved_3                   : 3;  // 保留位  
	    unsigned network_PID                  : 13; // 网络信息表（NIT）的PID,节目号为0时对应的PID为network_PID  
	    unsigned CRC_32                       : 32; // CRC32校验码  
	} TS_PAT;   

    */

	// PMT ID
	int value = (data[offset + 10] << 8) | data[offset + 11];
	reader->fPMTId = value & 0x1fff;

	//printf("fPMTId: %d\r\n", reader->fPMTId);
	return 0;
}

int ts_reader_parse_pmt( ts_reader_t* reader, const uint8_t* data, int flags )
{
	if (reader == NULL || data == NULL) {
		return 0;
	}

	int offset = 5;

	/*
	typedef struct TS_PMT_Stream  
	{  
	 unsigned stream_type                       : 8;  // 指示特定PID的节目元素包的类型。该处PID由elementary PID指定  
	 unsigned elementary_PID                    : 13; // 该域指示TS包的PID值。这些TS包含有相关的节目元素  
	 unsigned ES_info_length                    : 12; // 前两位bit为00。该域指示跟随其后的描述相关节目元素的byte数  
	 unsigned descriptor;  
	}TS_PMT_Stream;   

	//PMT 表结构体  
	typedef struct TS_PMT  
	{  
	    unsigned table_id                        : 8; //固定为0x02, 表示PMT表  
	    unsigned section_syntax_indicator        : 1; //固定为0x01  
	    unsigned zero                            : 1; //0x01  
	    unsigned reserved_1                      : 2; //0x03  
	    unsigned section_length                  : 12;//首先两位bit置为00，它指示段的byte数，由段长度域开始，包含CRC。  
	    unsigned program_number                  : 16;// 指出该节目对应于可应用的Program map PID  
	    unsigned reserved_2                      : 2; //0x03  
	    unsigned version_number                  : 5; //指出TS流中Program map section的版本号  
	    unsigned current_next_indicator          : 1; //当该位置1时，当前传送的Program map section可用；  
	                                                     //当该位置0时，指示当前传送的Program map section不可用，下一个TS流的Program map section有效。  
	    unsigned section_number                  : 8; //固定为0x00  
	    unsigned last_section_number             : 8; //固定为0x00  
	    unsigned reserved_3                      : 3; //0x07  
	    unsigned PCR_PID                         : 13;//指明TS包的PID值，该TS包含有PCR域，  
	            //该PCR值对应于由节目号指定的对应节目。  
	            //如果对于私有数据流的节目定义与PCR无关，这个域的值将为0x1FFF。  
	    unsigned reserved_4                      : 4; //预留为0x0F  
	    unsigned program_info_length             : 12;//前两位bit为00。该域指出跟随其后对节目信息的描述的byte数。  
	      
	    std::vector<TS_PMT_Stream> PMT_Stream;  //每个元素包含8位, 指示特定PID的节目元素包的类型。该处PID由elementary PID指定  
	    unsigned reserved_5                      : 3; //0x07  
	    unsigned reserved_6                      : 4; //0x0F  
	    unsigned CRC_32                          : 32;   
	} TS_PMT;  

	*/

	// table length
	int value = (data[offset + 1] << 8) | data[offset + 2];
	int length = value & 0x0fff;
	if (length < 17) {
		return 0;
	}

	//-- skip 
	offset = offset + 12;

	// stream list
	while ((offset + 5) <= (length + 5)) {
		int streamType = data[offset];
		value = (data[offset + 1] << 8) | data[offset + 2];
		int streamId = value & 0x1fff;

		//--console.log('streamType', offset, length, streamType, string.format('0x%02x 0x%04x', streamType, streamId))	

		if (streamType == STREAM_TYPE_VIDEO_H264) {
			reader->fVideoId = streamId;

		} else if (streamType == STREAM_TYPE_AUDIO_AAC) {
			reader->fAudioId = streamId;

		} else if (streamType == STREAM_TYPE_AUDIO_LPCM) {
			reader->fAudioId = streamId;	
		}
		
		offset = offset + 5;
	}

	//printf("fVideoId: %d\r\n", reader->fVideoId);
	return 0;
}

int64_t ts_reader_parse_pts(ts_reader_t* reader, const uint8_t* data) 
{
	if (reader == NULL || data == NULL) {
		return 0;
	}

	int64_t pts = 0;
	int offset = 0;

	// hight int
	pts = (data[offset + 0] & 0x0e);
	pts = pts << 29;
	
	// low int
	pts = pts + ((data[offset + 1] & 0xff) << 22);
	pts = pts + ((data[offset + 2] & 0xfe) << 14);
	pts = pts + ((data[offset + 3] & 0xff) << 7);
	pts = pts + ((data[offset + 4] & 0xfe) >> 1);

	pts = (pts - TS_PTS_BASE) * 1000 / 90;
	return floor(pts);
}

int ts_reader_parse_es_packet_header(ts_reader_t* reader, const uint8_t* data, int size, int flags)
{
	if (reader == NULL) {
		return 0;

	} else if (data == NULL || size <= 0) {
		return 0;
	}

	int offset = 0;
	int64_t sampleTime = 0;
	int streamId = data[offset + 3];

	if ((streamId & VIDEO_STREAM_TYPE) == VIDEO_STREAM_TYPE) {
		offset = offset + 8;
		int length = data[offset];
		if (length <= 0) {
			length = 10;
		}

		offset = offset + 1;
		sampleTime = ts_reader_parse_pts(reader, data + offset);

		offset = offset + length;
		offset = offset + 6; // -- AU (access unit) header

	} else if ((streamId & AUDIO_STREAM_TYPE) == AUDIO_STREAM_TYPE) {
		offset = offset + 8;
		int length = data[offset];
		if (length <= 0) {
			length = 5;
		}

		offset = offset + 1;
		sampleTime = ts_reader_parse_pts(reader, data + offset);

		offset = offset + length;

	} else {
		return 0;
	}

	//printf("sampleTime: %f\r\n", (double)(sampleTime / 1000));

	flags = flags | MUXER_FLAG_IS_START;
	const uint8_t* sampleData = data + offset;
	int sampleSize = size - offset;
	ts_reader_on_sample(reader, sampleData, sampleSize, sampleTime, flags);

	return 0;
}

int ts_reader_parse_es_packet_data(ts_reader_t* reader, const uint8_t* data, int size, int flags)
{
	if (reader == NULL) {
		return 0;

	} else if (data == NULL || size <= 0) {
		return 0;
	}

	//int flags = 0x00;
	ts_reader_on_sample(reader, data, size, 0, flags);
	return 0;
}

int ts_reader_parse_es_packet(ts_reader_t* reader, const uint8_t* data, int isStart, int flags )
{
	if (reader == NULL || data == NULL) {
		return 0;
	}

	int offset = 0;
	int size = TS_PAYLOAD_SIZE;
	int isAdaptationField = (data[offset + 3] & 0x20) != 0;
	offset += 4; //-- TS_HEADER_SIZE = 4

	// 有填充物
	if (isAdaptationField) {
		int stuffing = data[offset] + 1;
		//--console.log('stuffing', stuffing)

		if (stuffing > 0) {
			size   -= stuffing;
			offset += stuffing;
		}
	}

	if (isStart) {
		ts_reader_parse_es_packet_header(reader, data + offset, size, flags);

	} else {
		ts_reader_parse_es_packet_data(reader, data + offset, size, flags);
	}

	return 0;
}

/** 写入指定的 TS 包. */
int ts_reader_parse_ts_packet( ts_reader_t* reader, const uint8_t* data, uint32_t length )
{
	if (reader == NULL) {
		return -4;
		
	} else if (data == NULL || length <= 0) {
		return -1;

	} else if (length != TS_PACKET_SIZE) {
		return -2;

	} else if (data[0] != TS_START_CODE) {
		return -3;
	}

	/*
	Packet Header（包头）信息说明
	--- ------------------------------- ------- ---------------------------------------------
	1 	sync_byte						8bits	同步字节
	2	transport_error_indicator		1bit 	错误指示信息（1：该包至少有1bits传输错误）
	3	payload_unit_start_indicator 	1bit 	负载单元开始标志（packet不满188字节时需填充）
	4 	transport_priority 				1bit 	传输优先级标志（1：优先级高）
	5 	PID 							13bits  Packet ID号码，唯一的号码对应不同的包
	6 	transport_scrambling_control 	2bits 	加密标志（00：未加密；其他表示已加密）
	7	adaptation_field_control		2bits 	附加区域控制
	8 	continuity_counter 				4bits 	包递增计数器
	*/

	// pid is a 13-bit field starting at the last bit of TS[1]
	int offset  = 0;
	int value   = (data[offset + 1] << 8) + data[offset + 2];
	int pid 	= value & 0x1fff;
	int isStart = ((value & 0x4000) != 0);
	int flags   = 0;

	// printf("write_packet: %d, %d\r\n", pid, isStart);

	if (pid == TS_PAT_PID) {
		ts_reader_parse_pat(reader, data, flags);

	} else if (pid == reader->fPMTId) {
		ts_reader_parse_pmt(reader, data, flags);

	} else if (pid == reader->fVideoId) {
		ts_reader_parse_es_packet(reader, data, isStart, flags);

	} else if (pid == reader->fAudioId) {
		flags = flags | MUXER_FLAG_IS_AUDIO;
		ts_reader_parse_es_packet(reader, data, isStart, flags);		
	}

	return 0;
}

/** 写入指定的 ES 包. */
int ts_reader_read( ts_reader_t* reader, const uint8_t* data, uint32_t length, int flags )
{
	if (reader == NULL) {
		return -4;

	} else if (data == NULL || length <= 0) {
		return -1;
	}

	// cache buffer
	if (reader->fCacheBuffer == NULL) {
		reader->fCacheBuffer = malloc(TS_PACKET_SIZE);
		reader->fCacheSize = 0;
	}

	int leftover 		 = length;
	const uint8_t* leftdata = data;

	// 拼接上一次未处理完的 TS 包
	uint8_t* cacheBuffer = reader->fCacheBuffer;
	if (reader->fCacheSize > 0) {
		int size = TS_PACKET_SIZE - reader->fCacheSize;
		if (size > leftover) {
			size = leftover;
		}

		memcpy(cacheBuffer + reader->fCacheSize, leftdata, size);
		leftdata 	+= size;
		leftover 	-= size;

		reader->fCacheSize += size;
		if (reader->fCacheSize < TS_PACKET_SIZE) {
			return 0;
		}

		int ret = ts_reader_parse_ts_packet(reader, cacheBuffer, TS_PACKET_SIZE);
		reader->fCacheSize = 0;
		if (ret < 0) {
			return ret;
		}
	}

	// 分解成单个 TS 包
	while (leftover >= TS_PACKET_SIZE) {
		int ret = ts_reader_parse_ts_packet(reader, leftdata, TS_PACKET_SIZE);
		if (ret < 0) {
			return ret;
		}

		leftdata 	+= TS_PACKET_SIZE;
		leftover 	-= TS_PACKET_SIZE;
	}

	// 缓存余下的不足一个 TS 包的数据分片
	if (leftover > 0) {
		memcpy(cacheBuffer + reader->fCacheSize, leftdata, leftover);
		reader->fCacheSize += leftover;
	}

	return 0;
}
