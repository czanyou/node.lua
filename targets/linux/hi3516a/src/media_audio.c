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
#include "media_video.h"
#include "media_comm.h"
#include "media_queue.h"

///////////////////////////////////////////////////////////////////////////////
// Audio System

#define AUDIO_DEVICE_0 0

int audioInEncoder = -1;
queue_t* audioInQueue = NULL;

int AudioInOpenEncode(int channel, int encoder, int format);
int AudioInReleaseStream(int channel, AudioSampleInfo* streamInfo);

// Audio encode
int AudioInBind(int channel, int encodeId)
{
	MPP_CHN_S srcChannel;
	srcChannel.enModId	 = HI_ID_AI;
	srcChannel.s32DevId	 = AUDIO_DEVICE_0;
	srcChannel.s32ChnId	 = channel;

	MPP_CHN_S destChannel;
	destChannel.enModId	 = HI_ID_AENC;
	destChannel.s32DevId = 0;
	destChannel.s32ChnId = encodeId;

	return HI_MPI_SYS_Bind(&srcChannel, &destChannel);
}

// Audio input channel
int AudioInClose(int channel)
{
	AudioInCloseEncode(channel, channel);

	return HI_MPI_AI_DisableChn(AUDIO_DEVICE_0, channel);
}

int AudioInCloseEncode(int channel, int encodeId)
{
	if (audioInEncoder < 0) {
		return -1;
	}

	return HI_MPI_AENC_DestroyChn(audioInEncoder);
}

int AudioInInit()
{
	AudioInSetAttributes(0);
	return HI_MPI_AI_Enable(AUDIO_DEVICE_0);
}

int AudioInGetStream(int channel, AudioSampleInfo* sampleInfo)
{
	if (sampleInfo == NULL) {
		return -1;

	} else if (audioInQueue == NULL) {
		return -1;
	}

	queue_buffer_t* buffer = queue_pop(audioInQueue);
	if (buffer == NULL) {
		return -1;
	}

	sampleInfo->fPacketSize 	= buffer->length;
	sampleInfo->fPacketData 	= buffer->data;
	sampleInfo->fSampleTime  	= buffer->timestamp;
	sampleInfo->fSequence	 	= buffer->sequence;
	sampleInfo->fPrivateData 	= buffer;
	sampleInfo->fFlags 			= buffer->flags;
	return buffer->length;

	return 0;
}

int AudioInNextStream(int channel)
{
	if (audioInEncoder < 0) {
		LOG_W("audioInEncoder is NULL");
		return -1;

	} else if (audioInQueue == NULL) {
		LOG_W("audioInQueue is NULL");
		return -1;
	}

	AUDIO_STREAM_S* audioStream = malloc(sizeof(*audioStream));
	memset(audioStream, 0, sizeof(*audioStream));

	int ret = HI_MPI_AENC_GetStream(audioInEncoder, audioStream, HI_TRUE);
	if (ret < 0) {
		free(audioStream);
		return 0;
	}

	int sampleBits 		= 16;
	int channels 		= 1;
	int framesOfChunk 	= 320;

	// 一帧音频同时包含了左右声道的数据: 1 frames = [[high l][low l][high r][low r]]
	int frameSize    	= (sampleBits / 8) * channels;
	int bytesOfChunk 	= framesOfChunk * frameSize;
	int profile 		= 0;  // MAIN
    int freqIdx 		= 11;  // 48000HZ
    int channelConf		= 1;  // CPE
    int frameLength 	= audioStream->u32Len + 7;

    //LOG_W("%d", frameLength);

	queue_buffer_t* buffer = queue_buffer_malloc(frameLength);
	buffer->length 	  = audioStream->u32Len;
	buffer->timestamp = MediaGetTickCount(); // audioStream->u64TimeStamp;
	buffer->sequence  = audioStream->u32Seq;

	int sampleRate = 8000;
	switch (sampleRate) {
		case 8000:  freqIdx = 11; break;
		case 11025: freqIdx = 10; break;
		case 12000: freqIdx = 9; break;
		case 16000: freqIdx = 8; break;
		case 22050: freqIdx = 7; break;
		case 24000: freqIdx = 6; break;
		case 32000: freqIdx = 5; break;
		case 44100: freqIdx = 4; break;
		case 48000: freqIdx = 3; break;
		case 64000: freqIdx = 2; break;
		case 88200: freqIdx = 1; break;
		case 96000: freqIdx = 0; break;
	}

    // fill in ADTS data
    BYTE* packet = buffer->data;
    packet[0] = (unsigned char)0xEE;
    packet[1] = (unsigned char)0xE1;
    packet[2] = (unsigned char)(((profile) << 6) + (freqIdx << 2) +(channelConf >> 2));
    packet[3] = (unsigned char)(((channelConf & 0x03) << 6) + (frameLength >> 11));
    packet[4] = (unsigned char)((frameLength & 0x7FF) >> 3);
    packet[5] = (unsigned char)(((frameLength & 0x07) << 5) + 0x1F);
    packet[6] = (unsigned char)0xFC;

    packet += 7;

	memcpy(packet, audioStream->pStream, audioStream->u32Len);

	if (queue_push(audioInQueue, buffer) < 0) {
		printf("The queue is full!\r\n");
		queue_buffer_free(buffer);
	}

	HI_MPI_AENC_ReleaseStream(audioInEncoder, audioStream);
	free(audioStream);

	return frameLength;
}

int AudioInOpen(int channel, AudioSettings* settings)
{
	int format = settings->fCodecFormat;

	int ret = HI_MPI_AI_EnableChn(AUDIO_DEVICE_0, channel);
	if (ret < 0) {
		return ret;
	}

	if (audioInQueue == NULL) {
		audioInQueue = malloc(sizeof(queue_t));
		queue_init(audioInQueue, 1024);
	}

	if (format >= 0) {
		AudioInOpenEncode(channel, channel, format);
		return HI_MPI_AENC_GetFd(channel);
	}

	return HI_MPI_AI_GetFd(AUDIO_DEVICE_0, channel);
}

int AudioInOpenEncode(int channel, int encoder, int format)
{
	AENC_CHN_ATTR_S attributes;
	attributes.u32BufSize = 10;
	attributes.u32PtNumPerFrm = 320;

	if (format == 1) {
		AENC_ATTR_G711_S codecAttr;
		codecAttr.resv = 0;
		attributes.enType = PT_G711A;
		attributes.pValue = &codecAttr;

	} else if (format == 2) {
		AENC_ATTR_G711_S codecAttr;
		codecAttr.resv = 0;
		attributes.enType = PT_G711U;
		attributes.pValue = &codecAttr;

	} else {
		AENC_ATTR_LPCM_S codecAttr;
		attributes.enType = PT_LPCM;
		attributes.pValue = &codecAttr;
	}

	int ret = HI_MPI_AENC_CreateChn(encoder, &attributes);
	if (ret < 0) {
		return ret;
	}

	audioInEncoder = encoder;
	if (channel >= 0) {
		AudioInBind(channel, encoder);
	}
	
	return ret;
}

// Audio input
int AudioInRelease()
{
	return HI_MPI_AI_Disable(AUDIO_DEVICE_0);
}

int AudioInReleaseStream(int channel, AudioSampleInfo* sampleInfo)
{
	if (sampleInfo == NULL) {
		return 0;
	}
	
	queue_buffer_t* buffer = (queue_buffer_t*)sampleInfo->fPrivateData;
	sampleInfo->fPrivateData = NULL;

	if (buffer) {
		queue_buffer_free(buffer);
	}

	return 0;
}

int AudioInSetAttributes(int channel)
{
	AIO_ATTR_S attributes;
	attributes.enBitwidth		= AUDIO_BIT_WIDTH_16;
	attributes.enSamplerate		= AUDIO_SAMPLE_RATE_8000;
	attributes.enSoundmode		= AUDIO_SOUND_MODE_MONO;
	attributes.enWorkmode		= AIO_MODE_I2S_MASTER;
	attributes.u32ChnCnt		= 1; // 2 * 1 channel
	attributes.u32ClkSel		= 0;
	attributes.u32EXFlag		= 0;	// 只对 AUDIO_BIT_WIDTH_8 有效
	attributes.u32FrmNum		= 30;
	attributes.u32PtNumPerFrm	= 320;

	return HI_MPI_AI_SetPubAttr(AUDIO_DEVICE_0, &attributes);
}

int AudioInStop(int channel)
{

	return 0;
}

#include "media_audio_out.c"
