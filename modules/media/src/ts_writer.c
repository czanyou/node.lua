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
#include "ts_writer.h"

///////////////////////////////////////////////////////////////////////////////
// TS

/**

MPEG transport stream
=========================

MPEG transport stream (MPEG-TS, MTS or TS) is a standard container format for 
transmission and storage of audio, video, and Program and System Information 
Protocol (PSIP) data.[3] It is used in broadcast systems such as DVB, ATSC and 
IPTV.

Transport Stream is specified in MPEG-2 Part 1, Systems (formally known as 
ISO/IEC standard 13818-1 or ITU-T Rec. H.222.0).[2]

Transport stream specifies a container format encapsulating packetized elementary 
streams, with error correction and stream synchronization features for 
maintaining transmission integrity when the signal is degraded.

Transport streams differ from the similarly named program streams in several 
important ways: program streams are designed for reasonably reliable media, 
such as discs (like DVDs), while transport streams are designed for less reliable 
transmission, namely terrestrial or satellite broadcast. Further, a transport 
stream may carry multiple programs.

Layers of communication
=========================

A transport stream encapsulates a number of other substreams, often Packetized 
elementary streams (PES) which in turn wrap the main data stream of an MPEG codec,
as well as any number of non-MPEG codecs (such as AC3 or DTS audio, and MJPEG or 
JPEG 2000 video), text and pictures for subtitles, tables identifying the streams, 
and even broadcaster-specific information such as an electronic program guide. 
Many unrelated streams are often mixed together, such as several different 
television channels, or multiple angles of a movie. Each stream is chopped into 
(at most) 188-byte sections and interleaved together; because of the tiny packet 
size, streams can be interleaved with less latency and greater error resilience 
compared to program streams and common containers such as AVI, MOV/MP4, and MKV, 
which generally wrap each frame into one packet. This is particularly important 
for videoconferencing, where even one large frame may introduce unacceptable 
audio delay.

*/

int ts_writer_write_pes_fragment( ts_writer_t* stream, uint8_t* data, int leftover, 
	bool_t isStart, int64_t pcr, int64_t pts, int flags );

int ts_writer_write_ts_header( ts_writer_t* stream, uint8_t* buffer, int leftover, bool_t isStart, uint32_t pid );

int ts_writer_write_pcr(uint8_t* buffer, int64_t pcr);


/**
Packet Identifier (PID)[edit]
=========================

Each table or elementary stream in a transport stream is identified by a 13-bit packet identifier (PID). A demultiplexer extracts elementary streams from the transport stream in part by looking for packets identified by the same PID. In most applications, time-division multiplexing will be used to decide how often a particular PID appears in the transport stream.

Identifiers in use
=========================

Decimal	Hexadecimal		Description
0		0x0000			Program Association Table (PAT) contains a directory 
						listing of all Program Map Tables
1		0x0001			Conditional Access Table (CAT) contains a directory 
						listing of all ITU-T Rec. H.222 entitlement management
						message streams used by Program Map Tables
2		0x0002			Transport Stream Description Table contains descriptors 
						relating to the overall transport stream
3		0x0003			IPMP Control Information Table contains a directory 
						listing of all ISO/IEC 14496-13 control streams used by 
						Program Map Tables
4-15	0x0004-0x000F	Reserved for future use
16-31	0x0010-0x001F	Used by DVB metadata
32-8186	0x0020-0x1FFA	May be assigned as needed to Program Map Tables, elementary 
						streams and other data tables
8187	0x1FFB			Used by DigiCipher 2/ATSC MGT metadata
8188-	0x1FFC-0x1FFE	May be assigned as needed to Program Map Tables, elementary 
						streams and other data tables
8190
8191	0x1FFF			Null Packet (used for fixed bandwidth padding)
*/
enum ts_defines 
{
	TS_PACKET_SIZE			= 188,
	TS_PAYLOAD_SIZE			= 184,
	TS_MAX_PES_SIZE			= 1920 * 1080 * 3,
	TS_START_CODE			= 0x47,

	TS_PAT_PID				= 0x0000,
	TS_PMT_PID				= 0x1001,
	TS_VIDEO_PID			= 0x0100,
	TS_AUDIO_PID			= 0x0101,
	TS_PCR_PID				= 0x0100,

	TS_PAT_TABLE_ID			= 0x00,
	TS_PMT_TABLE_ID			= 0x02,
	TS_PTS_BASE				= 63000,

};

static const uint32_t ts_crc32_table[256] = {
	0x00000000, 0x04c11db7, 0x09823b6e, 0x0d4326d9, 0x130476dc, 0x17c56b6b,
	0x1a864db2, 0x1e475005, 0x2608edb8, 0x22c9f00f, 0x2f8ad6d6, 0x2b4bcb61,
	0x350c9b64, 0x31cd86d3, 0x3c8ea00a, 0x384fbdbd, 0x4c11db70, 0x48d0c6c7,
	0x4593e01e, 0x4152fda9, 0x5f15adac, 0x5bd4b01b, 0x569796c2, 0x52568b75,
	0x6a1936c8, 0x6ed82b7f, 0x639b0da6, 0x675a1011, 0x791d4014, 0x7ddc5da3,
	0x709f7b7a, 0x745e66cd, 0x9823b6e0, 0x9ce2ab57, 0x91a18d8e, 0x95609039,
	0x8b27c03c, 0x8fe6dd8b, 0x82a5fb52, 0x8664e6e5, 0xbe2b5b58, 0xbaea46ef,
	0xb7a96036, 0xb3687d81, 0xad2f2d84, 0xa9ee3033, 0xa4ad16ea, 0xa06c0b5d,
	0xd4326d90, 0xd0f37027, 0xddb056fe, 0xd9714b49, 0xc7361b4c, 0xc3f706fb,
	0xceb42022, 0xca753d95, 0xf23a8028, 0xf6fb9d9f, 0xfbb8bb46, 0xff79a6f1,
	0xe13ef6f4, 0xe5ffeb43, 0xe8bccd9a, 0xec7dd02d, 0x34867077, 0x30476dc0,
	0x3d044b19, 0x39c556ae, 0x278206ab, 0x23431b1c, 0x2e003dc5, 0x2ac12072,
	0x128e9dcf, 0x164f8078, 0x1b0ca6a1, 0x1fcdbb16, 0x018aeb13, 0x054bf6a4,
	0x0808d07d, 0x0cc9cdca, 0x7897ab07, 0x7c56b6b0, 0x71159069, 0x75d48dde,
	0x6b93dddb, 0x6f52c06c, 0x6211e6b5, 0x66d0fb02, 0x5e9f46bf, 0x5a5e5b08,
	0x571d7dd1, 0x53dc6066, 0x4d9b3063, 0x495a2dd4, 0x44190b0d, 0x40d816ba,
	0xaca5c697, 0xa864db20, 0xa527fdf9, 0xa1e6e04e, 0xbfa1b04b, 0xbb60adfc,
	0xb6238b25, 0xb2e29692, 0x8aad2b2f, 0x8e6c3698, 0x832f1041, 0x87ee0df6,
	0x99a95df3, 0x9d684044, 0x902b669d, 0x94ea7b2a, 0xe0b41de7, 0xe4750050,
	0xe9362689, 0xedf73b3e, 0xf3b06b3b, 0xf771768c, 0xfa325055, 0xfef34de2,
	0xc6bcf05f, 0xc27dede8, 0xcf3ecb31, 0xcbffd686, 0xd5b88683, 0xd1799b34,
	0xdc3abded, 0xd8fba05a, 0x690ce0ee, 0x6dcdfd59, 0x608edb80, 0x644fc637,
	0x7a089632, 0x7ec98b85, 0x738aad5c, 0x774bb0eb, 0x4f040d56, 0x4bc510e1,
	0x46863638, 0x42472b8f, 0x5c007b8a, 0x58c1663d, 0x558240e4, 0x51435d53,
	0x251d3b9e, 0x21dc2629, 0x2c9f00f0, 0x285e1d47, 0x36194d42, 0x32d850f5,
	0x3f9b762c, 0x3b5a6b9b, 0x0315d626, 0x07d4cb91, 0x0a97ed48, 0x0e56f0ff,
	0x1011a0fa, 0x14d0bd4d, 0x19939b94, 0x1d528623, 0xf12f560e, 0xf5ee4bb9,
	0xf8ad6d60, 0xfc6c70d7, 0xe22b20d2, 0xe6ea3d65, 0xeba91bbc, 0xef68060b,
	0xd727bbb6, 0xd3e6a601, 0xdea580d8, 0xda649d6f, 0xc423cd6a, 0xc0e2d0dd,
	0xcda1f604, 0xc960ebb3, 0xbd3e8d7e, 0xb9ff90c9, 0xb4bcb610, 0xb07daba7,
	0xae3afba2, 0xaafbe615, 0xa7b8c0cc, 0xa379dd7b, 0x9b3660c6, 0x9ff77d71,
	0x92b45ba8, 0x9675461f, 0x8832161a, 0x8cf30bad, 0x81b02d74, 0x857130c3,
	0x5d8a9099, 0x594b8d2e, 0x5408abf7, 0x50c9b640, 0x4e8ee645, 0x4a4ffbf2,
	0x470cdd2b, 0x43cdc09c, 0x7b827d21, 0x7f436096, 0x7200464f, 0x76c15bf8,
	0x68860bfd, 0x6c47164a, 0x61043093, 0x65c52d24, 0x119b4be9, 0x155a565e,
	0x18197087, 0x1cd86d30, 0x029f3d35, 0x065e2082, 0x0b1d065b, 0x0fdc1bec,
	0x3793a651, 0x3352bbe6, 0x3e119d3f, 0x3ad08088, 0x2497d08d, 0x2056cd3a,
	0x2d15ebe3, 0x29d4f654, 0xc5a92679, 0xc1683bce, 0xcc2b1d17, 0xc8ea00a0,
	0xd6ad50a5, 0xd26c4d12, 0xdf2f6bcb, 0xdbee767c, 0xe3a1cbc1, 0xe760d676,
	0xea23f0af, 0xeee2ed18, 0xf0a5bd1d, 0xf464a0aa, 0xf9278673, 0xfde69bc4,
	0x89b8fd09, 0x8d79e0be, 0x803ac667, 0x84fbdbd0, 0x9abc8bd5, 0x9e7d9662,
	0x933eb0bb, 0x97ffad0c, 0xafb010b1, 0xab710d06, 0xa6322bdf, 0xa2f33668,
	0xbcb4666d, 0xb8757bda, 0xb5365d03, 0xb1f740b4
};

uint32_t ts_crc32(const uint8_t *data, int len)
{
    int i;
	uint32_t crc = 0xffffffff;
    for (i = 0; i < len; i++) {
		crc = (crc << 8) ^ ts_crc32_table[((crc >> 24) ^ *data++) & 0xff];
    }

	return crc;
}

int ts_writer_init(ts_writer_t* writer)
{
	if (writer == NULL) {
		return 0;
	}

	writer->fCacheBuffer			= NULL;
	writer->fPacketBuffer			= NULL;
	writer->fCacheSize				= 0;
	writer->fFrameSize				= 0;
	writer->fPATContinuityCounter	= 0;
	writer->fPESContinuityCounter	= 0;
	writer->fPESPacketCounter		= 0;
	writer->fPMTContinuityCounter	= 0;
	writer->fVideoID				= TS_VIDEO_PID;
	writer->fAudioID				= TS_AUDIO_PID;
	writer->fAudioCodec				= STREAM_TYPE_AUDIO_AAC;
	writer->fVideoCodec				= STREAM_TYPE_VIDEO_H264;

	writer->fCallback				= 0;
	writer->fState					= NULL;

	return 0;
}

int ts_writer_release(ts_writer_t* writer)
{
	if (writer == NULL) {
		return 0;
	}

	if (writer->fCacheBuffer) {
		free(writer->fCacheBuffer);
		writer->fCacheBuffer = NULL;
	}

	if (writer->fPacketBuffer) {
		free(writer->fPacketBuffer);
		writer->fPacketBuffer = NULL;
	}

	return 0;
}

/**
Adaptation Field Format
===============================================================================
Name	                Number        mask  Description
                        of bits	Byte
-------------------------------------------------------------------------------
Adaptation Field Length	8		    Number of bytes in the adaptation field 
									immediately following this byte
Discontinuity indicator	1	0x80	Set if current TS packet is in a discontinuity 
									state with respect to either the continuity 
									counter or the program clock reference
Random Access indicator	1	0x40	Set when the stream may be decoded without 
									errors from this point
Elementary stream 	    1	0x20	Set when this stream should be considered 
									"high priority"
priority indicator
PCR flag	            1	0x10	Set when PCR field is present
OPCR flag	            1	0x08	Set when OPCR field is present
Splicing point flag	    1	0x04	Set when splice countdown field is present
Transport private data  1	0x02	Set when private data field is present
flag	
Adaptation field 	    1	0x01	Set when extension field is present
extension flag
-------------------------------------------------------------------------------
                   Optional fields
-------------------------------------------------------------------------------
PCR						48			Program clock reference, stored as 33 bits 
									base, 6 bits reserved, 9 bits extension.
									The value is calculated as base * 300 + extension.
OPCR					48			Original Program clock reference. Helps when 
									one TS is copied into another
Splice countdown		8			Indicates how many TS packets from this one 
									a splicing point occurs (Two's complement signed; 
									may be negative)
Transport private data 	8			The length of the following field
length
Transport private data	variable	Private data
Adaptation extension	variable	See below
Stuffing bytes			variable	Always 0xFF

*/
int ts_writer_write_adaptation_field(uint8_t* buffer, int leftover, int64_t pcr)
{
	uint32_t stuffing = TS_PAYLOAD_SIZE - leftover;
	if (stuffing > 0) {
		buffer[4] = stuffing - 1; // 长度, Adaptation Field Length
	}

	if (stuffing > 1) {
		buffer[5] = 0x00; // 总是为 0x00
	}

	if (stuffing > 2) { // stuffing
		memset(buffer + 6, 0xFF, stuffing - 2);
	}

	if (stuffing > 8) { // Program clock reference, 
		buffer[5] |= 0x10; // flags: PCR present 
		ts_writer_write_pcr(buffer + 6, pcr); // 6 Bytes
	}

	return stuffing;
}

int ts_writer_write_crc32(uint8_t* buffer, const uint8_t *data, int len)
{
	uint8_t* p = buffer;
	
	uint32_t crc = ts_crc32(data, len);
	*p++ = (crc >> 24) & 0xFF;
	*p++ = (crc >> 16) & 0xFF;
	*p++ = (crc >> 8 ) & 0xFF;
	*p++ = (crc      ) & 0xFF;

	return 0;
}

int ts_writer_write_es_cache(ts_writer_t* writer, uint8_t* data, int leftover)
{
	int freeSpace = TS_PAYLOAD_SIZE - writer->fCacheSize;
	int size = (leftover > freeSpace) ? freeSpace : leftover;
	uint8_t* freeBuffer = writer->fCacheBuffer + writer->fCacheSize;
	memcpy(freeBuffer, data, size);

	writer->fCacheSize += size;
	writer->fFrameSize += size;

	return size;
}

int ts_writer_write_es_cache_flush(ts_writer_t* writer, int64_t pcr, int64_t pts, bool_t isEnd, int flags)
{
	int size = writer->fCacheSize;
	if (size <= 0) {
		return 0;
	}

	if (isEnd) {
		flags = flags | MUXER_FLAG_IS_END;

	} else if (writer->fCacheSize >= TS_PAYLOAD_SIZE) {
		size = TS_PAYLOAD_SIZE;

	} else {
		return 0;
	}

	uint8_t* data = writer->fCacheBuffer;
	bool_t isStart = (writer->fPESPacketCounter == 0);
	ts_writer_write_pes_fragment(writer, data, size, isStart, pcr, pts, flags);
	writer->fCacheSize = 0;
	writer->fPESPacketCounter++;

	return 0;
}

/**
PAT stands for Program Association Table. It lists all programs available in the 
transport stream. Each of the listed programs is identified by a 16-bit value 
called program_number. Each of the programs listed in PAT has an associated value 
of PID for its Program Map Table (PMT).

The value 0x0000 of program_number is reserved to specify the PID where to look 
for Network Information Table (NIT). If such a program is not present in PAT the 
default PID value (0x0010) shall be used for NIT.

TS Packets containing PAT information always have PID 0x0000.
*/
/** 生成 PAT 包. */
int ts_writer_write_pat_packet(ts_writer_t* writer, int64_t sampleTime, int flags)
{
	uint8_t buffer[TS_PACKET_SIZE];
	memset(buffer, 0xFF, TS_PACKET_SIZE);

	uint32_t PMT_ID = TS_PMT_PID;
	uint32_t PAT_TABLE_OFFSET = 5;
	uint8_t* p = buffer;
	uint32_t tableLength = 13; // 13

	// TS Packet Header (4 Bytes)
	*p++ = TS_START_CODE;	// 8: 同步字节, 为 0x47
	*p++ = 0x40;	// (0100 0000) 1: 传输误码指示符, 1: 起始指示符, 1: 优先传输
	*p++ = 0x00;	// 13: PID
	*p++ = 0x10 | writer->fPATContinuityCounter; //  2: 传输加扰, 2: 自适应控制 4: 连续计数器
	writer->fPATContinuityCounter = (writer->fPATContinuityCounter + 1) & 0x0F;

	// 
	*p++ = 0x00;

	// PSI
	// There are 4 PSI tables: Program Association (PAT), Program Map (PMT), Conditional Access (CAT), and Network Information (NIT).
	*p++ = TS_PAT_TABLE_ID;	// 8: 固定为0x00, 标志是该表是PAT
	*p++ = 0xB0 | ((tableLength >> 8) & 0x0F);	// 1: 段语法标志位，固定为1; 1: 0; 2: 保留 (1011 0000) 
	*p++ = tableLength & 0xFF;	// 12: 13, 表示这个字节后面有用的字节数，包括CRC32
	*p++ = 0x00;	// 
	*p++ = 0x01;	// 16: 该传输流的ID，区别于一个网络中其它多路复用的流
	*p++ = 0xC1;	// 2: 保留; 5: 范围0-31，表示PAT的版本号; 1: 发送的PAT是当前有效还是下一个PAT有效 (1100 0001) 
	*p++ = 0x00;	// 8: 分段的号码。PAT可能分为多段传输，第一段为00，以后每个分段加1，最多可能有256个分段
	*p++ = 0x00;	// 8: 最后一个分段的号码

	// Programs 节目列表 (PAT)
	*p++ = 0x00;  //
	*p++ = 0x01;  // 16: 节目号
	*p++ = 0xE0 | ((PMT_ID >> 8) & 0x1F);	// 3: 保留位 (1110 0001) 
	*p++ = PMT_ID & 0xFF; // 13: 节目映射表的PID，节目号大于 0 时对应的 PID，每个节目对应一个
						  // 13: 网络信息表(NIT)的 PID,节目号为 0 时对应的 PID 为network_PID

	// CRC 32
	ts_writer_write_crc32(p, buffer + PAT_TABLE_OFFSET, (tableLength + 3) - 4); // 3Bytes header, 4Bytes crc

	ts_writer_on_ts_packet(writer, buffer, TS_PACKET_SIZE, sampleTime, flags);
	return 0;
}

/**
To enable a decoder to present synchronized content, such as audio tracks 
matching the associated video, at least once each 100 ms a Program Clock 
Reference, or PCR is transmitted in the adaptation field of an MPEG-2 transport
stream packet. The PID with the PCR for an MPEG-2 program is identified by the 
pcr_pid value in the associated Program Map Table. The value of the PCR, when 
properly used, is employed to generate a system_timing_clock in the decoder. 
The STC or System Time Clock decoder, when properly implemented, provides a 
highly accurate time base that is used to synchronize audio and video elementary 
streams. Timing in MPEG2 references this clock. For example, the presentation 
time stamp (PTS) is intended to be relative to the PCR. The first 33 bits are 
based on a 90 kHz clock. The last 9 are based on a 27 MHz clock. The maximum 
jitter permitted for the PCR is +/- 500 ns.
*/
/** 写入指定的 PCR 节目时钟基准 (Program clock reference). */
int ts_writer_write_pcr(uint8_t* buffer, int64_t pcr)
{
	uint8_t* p = buffer;
	if (p == NULL) {
		return -1;
	}

	// (33bit) program clock reference base
	*p++  = (pcr >> 25) & 0xFF; // 
	*p++  = (pcr >> 17) & 0xFF; // 
	*p++  = (pcr >> 9)  & 0xFF; // 
	*p++  = (pcr >> 1)  & 0xFF; // 

	// (6bit) reserved 
	*p++ = ((pcr << 7)  & 0x80); //

	// (9bit) Program clock reference extension
	*p++ = 0x00;

	return 0;
}

/**
 * 写入指定的 PES 包. 
 * @param writer self
 * @param data PES 数据包
 * @param length PES 数据包长度, 不过超过 TS_PAYLOAD_SIZE
 * @param pts PES 数据包时间戳
 */
int ts_writer_write_pes_fragment( ts_writer_t* writer, uint8_t* data, int length, 
	bool_t isStart, int64_t pcr, int64_t pts, int flags )
{
	if (writer == NULL) {
		return 0;

	} else if (data == NULL || length <= 0) {
		return 0;
	}

	if (writer->fPacketBuffer == NULL) {
		writer->fPacketBuffer = malloc(256);
	}

	uint8_t* buffer = writer->fPacketBuffer;
	if (buffer == NULL) {
		return 0;
	}

	uint32_t pid = writer->fVideoID;
	if (flags & MUXER_FLAG_IS_AUDIO) {
		pid = writer->fAudioID;
	}

	ts_writer_write_ts_header(writer, buffer, length, isStart, pid); // 4 bytes

	uint32_t size   = 0;
	uint32_t offset = 4; // sizeof(TS Header)

	if (length < TS_PAYLOAD_SIZE) {
		size = length;
		offset += ts_writer_write_adaptation_field(buffer, length, pcr);

	} else {
		size = TS_PAYLOAD_SIZE;
	}

	memcpy(buffer + offset, data, size);
	ts_writer_on_ts_packet(writer, buffer, TS_PACKET_SIZE, pts, flags);

	return (int)size;
}

/** 
 * 写入指定的 PES 头信息. 
 * @param buffer 
 * @param pts 90kHZ
 */
int ts_writer_write_pes_header(ts_writer_t* writer, uint8_t* buffer, int64_t pts, bool_t isAudio)
{
	int64_t dts = pts;
	uint8_t  streamID = 0xE0;
	if (isAudio) {
		streamID = 0xC0;
	}

	uint8_t* pes = buffer;

	// PES packet header
	// ====================
	// 3 Byte: 0x000001 包起始码前缀 Packet start code prefix
	// 1 Byte: 0xE0 数据流识别码,	
	// 2 Byte: PES 包长度, PES Packet length
	// 2 Byte: PES 包头识别标志, Optional PES header
	// 1 Byte: PES 包头长度
	// X Byte: 

	// PTS: 显示时间戳, DTS 解码时间戳, DSM 数据存储媒体, ESCE 基本流时钟基准

	// Packet start code prefix, 3 Byte: 0x000001
	*pes++ = 0x00;
	*pes++ = 0x00;
	*pes++ = 0x01;

	// 数据流识别码, Stream id, Audio streams (0xC0-0xDF), Video streams (0xE0-0xEF)
	*pes++ = streamID;	// Stream ID, E0: Video; C0: Audio

	// PES Packet Length
	// Specifies the number of bytes remaining in the packet after this field.
	// Can be zero. If the PES packet length is set to zero, the PES packet can 
	// be of any length. A value of zero for the PES packet length can be used 
	// only when the PES packet payload is a video elementary stream.
	*pes++ = 0x00;	//
	*pes++ = 0x00;	// 16 bits

	// Flags (1/2)
	*pes++ = 0x84;	// (1000 0100) data_alignment
	// 2: Marker bits, 10 binary or 0x2 hex
	// 2: PES 加扰控制, Scrambling control, 00 implies not scrambled
	// 1: PES 优先, Priority
	// 1: 数据定位指示符, data alignement indicator, 1 indicates that the PES packet
	//    header is immediately followed by the video start code or audio syncword
	// 1: 版权, copyright, 1 implies copyrighted
	// 1: 原版或拷贝, original or copy, 1 implies original

	// Flags (2/2)
	*pes++ = 0xC0;	// (1100 0000) PTS DTS
	// 2: PTS/DTS 标志, PTS DTS flags, 11 = both present, 01 is forbidden, 
	// 	  10 = only PTS, 00 = no PTS or DTS
	// 1: ESCR 标志, escr flags
	// 1: 基本速率标志, es rate flag
	// 1: DSM, dsm trick mode flag
	// 1: 附加信息, additional copy info flag
	// 1: PES CRC 标志, pes crc flag
	// 1: PES 扩展标志, pes extention flags

	*pes++ = 0x0A;	// 8: PES header length, 0x0A = 10

	/**
	While above flags indicate that values are appended into variable length 
	optional fields, they are not just simply written out. For example, PTS 
	(and DTS) is expanded from 33 bits to 5 bytes (40 bits). If only PTS is 
	present, this is done by catenating 0010b, most significant 3 bits from 
	PTS, 1, following next 15 bits, 1, rest 15 bits and 1. If both PTS and 
	DTS are present, first 4 bits are 0011 and first 4 bits for DTS are 0001. 
	Other appended bytes have similar but different encoding.
	*/
	// PTS 5 Byte, expanded from 33 bits to 5 bytes (40 bits)
	*pes++ = ((pts >> 29) & 0x0E) | 0x31; 	// 4 bits: '0011' or '0010', 3 bits: PTS, 1 bits: marker
	*pes++ = ( pts >> 22) & 0xFF; 			// 15 bits: PTS
	*pes++ = ((pts >> 14) & 0xFE) | 0x01; 	// 1 bits:  marker
	*pes++ = ( pts >> 7 ) & 0xFF; 			// 15 bits: PTS
	*pes++ = ((pts << 1 ) & 0xFE) | 0x01; 	// 1 bits:  marker

	// DTS 5 Byte, expanded from 33 bits to 5 bytes (40 bits)
	*pes++ = ((dts >> 29) & 0x0E) | 0x11; 	// 4 bits: '0001', 3 bits: DTS, 1 bits: marker
	*pes++ = ( dts >> 22) & 0xFF; 			// 15 bits: DTS
	*pes++ = ((dts >> 14) & 0xFE) | 0x01; 	// 1 bits:  marker
	*pes++ = ( dts >> 7 ) & 0xFF; 			// 15 bits: DTS
	*pes++ = ((dts << 1 ) & 0xFE) | 0x01; 	// 1 bits:  marker

	if (isAudio) {
		return pes - buffer; // 9 + 10;
	}

	// AU (Access Unit) header
	*pes++ = 0x00;
	*pes++ = 0x00;
	*pes++ = 0x00;
	*pes++ = 0x01;
	*pes++ = 0x09;
	*pes++ = 0x10;

	return pes - buffer; // 9 + 10 + 6;
}

int ts_writer_write_pes_packet( ts_writer_t* writer, uint8_t* data, uint32_t length, int64_t pts, int flags )
{
	bool_t isStart = TRUE;

	int64_t pcr 	 = pts / 1000;
	pcr 		 = pcr * 90 + TS_PTS_BASE;

	uint8_t* leftdata = data;
	int leftover = length;

	while (leftover > 0) {
		if (leftover <= TS_PAYLOAD_SIZE) {
			flags = flags | MUXER_FLAG_IS_END;
		}

		int size = ts_writer_write_pes_fragment(writer, leftdata, leftover, isStart, pcr, pts, flags);

		leftdata += size;
		leftover -= size;

		isStart  = FALSE;
	}
	return 0;
}


/**
PMT[edit]
Program Map Tables (PMTs) contain information about programs. For each program,
there is one PMT. While the MPEG-2 standard permits more than one PMT section 
to be transmitted on a single PID (Single Transport stream PID contains PMT 
information of more than one program), most MPEG-2 "users" such as ATSC and 
SCTE require each PMT to be transmitted on a separate PID that is not used for 
any other packets. The PMTs provide information on each program present in the 
transport stream, including the program_number, and list the elementary streams 
that comprise the described MPEG-2 program. There are also locations for 
optional descriptors that describe the entire MPEG-2 program, as well as an 
optional descriptor for each elementary stream. Each elementary stream is 
labeled with a stream_type value.
*/
/** 生成 PMT 包, 这个包用来描述指定的节目的编码格式等信息. */
int ts_writer_write_pmt_packet(ts_writer_t* writer, int64_t sampleTime, int flags)
{
	uint32_t PMT_ID  = TS_PMT_PID;
	uint32_t PCR_PID = TS_PCR_PID;
	uint32_t PMT_TABLE_OFFSET = 5;

	uint8_t buffer[TS_PACKET_SIZE];
	memset(buffer, 0xFF, TS_PACKET_SIZE);

	uint8_t* p = buffer;
	uint32_t tableLength = 9 + 4; // PMT 表数据内容长度, 不包括 PMT 表前 3 个字节

	if (writer->fVideoID != 0) {
		tableLength += 5;
	}

	if (writer->fAudioID != 0) {
		tableLength += 5;
	}

	// TS Packet Header (4 Bytes)
	*p++ = TS_START_CODE;	// 8 bit: 同步字符, 总是为 0x47
	*p++ = 0x40 | ((PMT_ID >> 8) & 0x1F);	// 1 bit: 传输误码指示符, 1 bit: 起始指示符, 1 bit: 优先传输
	*p++ = PMT_ID & 0xFF;	// 13 bit: PID
	*p++ = 0x10 | writer->fPMTContinuityCounter;	// 2 bit: 传输加扰, 2 bit: 自适应控制, 4 bit: 连续计数器
	writer->fPMTContinuityCounter = (writer->fPMTContinuityCounter + 1) & 0x0F;

	*p++ = 0x00;	// 总是为 0x00

	// PMT Table
	*p++ = TS_PMT_TABLE_ID;	// 8 bit: 固定为0x02, 标志是该表是PMT
	*p++ = 0xB0 | ((tableLength >> 8) & 0x0F);	// 1 bit: 段语法标志位，固定为1; 1 bit: 0; 2 bit: 保留 (1011 0000) 
	*p++ = tableLength & 0xFF;	// 12 bit: 表示这个字节后面有用的字节数，包括CRC32

	*p++ = 0x00;	// 
	*p++ = 0x01;	// 16 bit: 指出该节目对应于可应用的 Program map PID
	*p++ = 0xC1;	// 2 bit: 保留; 5 bit: 指出TS流中Program map section的版本号
					// 1 bit: 当该位置1时，当前传送的 Program map section 可用 (1100 0001) 
	*p++ = 0x00;	// 8 bit: 固定为0x00
	*p++ = 0x00;	// 8 bit: 固定为0x00

	*p++ = 0xE0 | ((PCR_PID >> 8) & 0x1F);	// 3 bit: 保留
	*p++ = PCR_PID & 0xFF; // 13 bit: 节目号 指明 TS 包的PID值
	*p++ = 0xF0;	// 4 bit: 保留位  
	*p++ = 0x00;	// 12 bit: 前两位bit为00。该域指出跟随其后对节目信息的描述的 byte 数

	// 视频流的描述
	if (writer->fVideoID != 0) {
		*p++ = writer->fVideoCodec;	// H.264 视频流
		*p++ = 0xE0 | ((writer->fVideoID >> 8) & 0x1F);	//
		*p++ = writer->fVideoID & 0xFF;	//
		*p++ = 0xF0;	// 
		*p++ = 0x00;	//
	}

	if (writer->fAudioID != 0) {
		*p++ = writer->fAudioCodec;	// AAC Audio Stream
		*p++ = 0xE0 | ((writer->fAudioID >> 8) & 0x1F);	//
		*p++ = writer->fAudioID & 0xFF;	//
		*p++ = 0xF0;	// 
		*p++ = 0x00;	//
	}

	// 32 位 CRC 校验码
	ts_writer_write_crc32(p, buffer + PMT_TABLE_OFFSET, (tableLength + 3) - 4); // 3Bytes header, 4Bytes crc

	ts_writer_on_ts_packet(writer, buffer, TS_PACKET_SIZE, sampleTime, flags);
	return 0;
}

/** 写入指定的 ES 包. */
int ts_writer_write_sample( ts_writer_t* writer, uint8_t* data, uint32_t length, int64_t sampleTime, int sampleFlags )
{
	if (writer == NULL) {
		return 0;
	}

	if (writer->fCacheBuffer == NULL) {
		writer->fCacheBuffer = malloc(TS_PACKET_SIZE);
	}

	// 无效的帧
	if (writer->fFrameSize + length > TS_MAX_PES_SIZE) {
		writer->fFrameSize = 0;
		return 0;
	}

	int64_t pcr = sampleTime / 1000;
	pcr = pcr * 90 + TS_PTS_BASE;

	int leftover = length;

	bool_t isAudio = ((sampleFlags & MUXER_FLAG_IS_AUDIO) != 0);
	bool_t isEnd   = ((sampleFlags & MUXER_FLAG_IS_END) != 0);

	int flags = sampleFlags & MUXER_FLAG_IS_AUDIO;

	// Build PES Header
	if (writer->fFrameSize == 0) {
		uint8_t* buffer = writer->fCacheBuffer;
		uint32_t headerLength = ts_writer_write_pes_header(writer, buffer, pcr, isAudio);
		writer->fFrameSize = headerLength;
		writer->fCacheSize = headerLength;
	}

	// 填充缓存区剩余的空间
	if (writer->fCacheSize > 0) {
		int size = ts_writer_write_es_cache(writer, data, leftover);
		data     += size;
		leftover -= size;

		ts_writer_write_es_cache_flush(writer, pcr, sampleTime, FALSE, flags);
	}

	// 直接转换为 TS
	while (leftover > TS_PAYLOAD_SIZE) {
		uint32_t size = TS_PAYLOAD_SIZE;
		bool_t isStart = FALSE;
		ts_writer_write_pes_fragment(writer, data, size, isStart, pcr, sampleTime, flags);
		
		writer->fPESPacketCounter++;
		writer->fFrameSize += size;

		data     += size;
		leftover -= size;
	}

	// 缓存剩余的数据
	while (leftover > 0) {
		int size = ts_writer_write_es_cache(writer, data, leftover);
		data     += size;
		leftover -= size;
	}

	ts_writer_write_es_cache_flush(writer, pcr, sampleTime, isEnd, flags);

	if (isEnd) {
		writer->fFrameSize  = 0;
		writer->fPESPacketCounter = 0;
	}

	return 0;
}

int ts_writer_write_sync_info(ts_writer_t* writer, int64_t sampleTime)
{
	int flags = MUXER_FLAG_IS_SYNC;
	ts_writer_write_pat_packet(writer, sampleTime, flags);
	ts_writer_write_pmt_packet(writer, sampleTime, 0);
	return 0;
}

/**
Packet
=========================

A packet is the basic unit of data in a transport stream, and a transport stream 
is merely a sequence of packets, without any global header. Each packet starts 
with a sync byte and a header, that may be followed with optional additional 
headers; the rest of the packet consists of payload. All header fields are read 
as big-endian. Packets are 188 bytes in length, but the communication medium may 
add additional information: Forward error correction is added by ISDB & DVB 
(16 bytes) and ATSC (20 bytes),[4] while the M2TS format prefixes packets with 
a 4-byte copyright and timestamp tag. The 188-byte packet size was originally 
chosen for compatibility with ATM systems.[5][6]

Partial Transport Stream Packet Format
=========================

===============================================================================
Name			Number      32-bit BE 	Description
        		of bits	     mask
-------------------------------------------------------------------------------
                       4-byte Transport Stream Header
-------------------------------------------------------------------------------
Sync byte	    | 8  | 0xff000000  | Bit pattern of 0x47 (ASCII char 'G')
-------------------------------------------------------------------------------
Transport Error | 1  | 0x800000    | Set when a demodulator can't correct errors 
Indicator (TEI) |    |             | from FEC data; indicating the packet is corrupt.[7]
-------------------------------------------------------------------------------
Payload Unit    | 1  | 0x400000    | Set when a PES, PSI, or DVB-MIP packet begins 
Start Indicator |    |             | immediately following the header.
-------------------------------------------------------------------------------
Transport       | 1  | 0x200000    | Set when the current packet has a higher 
Priority        |    |             | priority than other packets with the same PID.
-------------------------------------------------------------------------------
PID             | 13 | 0x1fff00    | Packet Identifier, describing the payload data.
-------------------------------------------------------------------------------
Scrambling      | 2  | 0xc0        | '00' = Not scrambled. For DVB-CSA only:[8]
control         |    |             | '01' (0x40) = Reserved for future use
                |    |             | '10' (0x80) = Scrambled with even key
                |    |             | '11' (0xC0) = Scrambled with odd key
-------------------------------------------------------------------------------
Adaptation      | 1  | 0x20        | 
field flag      |    |             |	
-------------------------------------------------------------------------------
Payload flag    | 1  | 0x10        | 
-------------------------------------------------------------------------------
Continuity      | 4  | 0xf         | Sequence number of payload packets (0x00 to 0x0F) 
counter         |    |             | within each stream (except PID 8191) Incremented 
                |    |             | per-PID, only when a payload flag is set.
-------------------------------------------------------------------------------
                        Optional fields
-------------------------------------------------------------------------------
Adaptation field  | variable | If Adaptation field flag is set, see below.
-------------------------------------------------------------------------------
Payload Data	  | variable | If Payload flag is set. Payload may be PES packets,
						     | program specific information (below), or other data.
-------------------------------------------------------------------------------

*/
/**
 * 写入指定的 TS 包 Header.  
 * @param writer self
 * @param buffer 缓存区
 * @param leftover 缓存区中剩余的数据长度
 * @param isStart 指出这个包是否是一帧数据的第一个包
 * @param pid 这个包所属的流的 ID
 */
int ts_writer_write_ts_header( ts_writer_t* writer, uint8_t* buffer, int leftover, bool_t isStart, uint32_t pid )
{
	uint32_t adaptationFieldFlag = (leftover < TS_PAYLOAD_SIZE) ? 0x20 : 0x00;

	// TS Packet Header
	buffer[0] = TS_START_CODE;
	buffer[1] = (isStart ? 0x40 : 0x00) | ((pid >> 8) & 0x1f);
	buffer[2] = pid & 0xff;
	buffer[3] = (adaptationFieldFlag) | 0x10 | writer->fPESContinuityCounter;
	writer->fPESContinuityCounter = (writer->fPESContinuityCounter + 1) & 0x0F;

	return 0;
}
