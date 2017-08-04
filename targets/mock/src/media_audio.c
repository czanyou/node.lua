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

#ifdef MEDIA_USE_FAAD
#include <neaacdec.h>
#endif

#ifdef MEDIA_USE_FAAC
#include <faac.h>
#endif

///////////////////////////////////////////////////////////////////////////////
// Audio input

typedef struct AudioInContext
{
	int   channel;
	uint32_t  format;
	uint32_t  framesOfChunk;
	uint32_t  sampleRate;
	uint32_t  channels;
	uint32_t  sampleBits;
	uint32_t  inputSamples;
	uint32_t  maxOutputBytes;

	queue_t fQueue;

	BYTE*	pcmBuffer;
	uint32_t  pcmLength;
	uint32_t  pcmOffset;

} AudioInContext;

AudioInContext* fAudioInContext = NULL;

static int AudioInRead(AudioInContext* audioInContext, char* buffer, int sampleCount);

AudioInContext* AudioInGetContext(int channel)
{
	return fAudioInContext;
}

int AudioInSetContext(int channel, AudioInContext* audioInContext)
{
	fAudioInContext = audioInContext;
	return 0;
}


static int AudioEncodePcmFrame(AudioInContext* audioInContext, char* pcmData, int framesOfChunk)
{
	if (framesOfChunk <= 0) {
		return -1;
	}

	// 一帧音频同时包含了左右声道的数据: 1 frames = [[high l][low l][high r][low r]]
	int frameSize    = (audioInContext->sampleBits / 8) * audioInContext->channels;
	int bytesOfChunk = framesOfChunk * frameSize;
	int profile 	= 0;  // MAIN
    int freqIdx 	= 3;  // 48000HZ
    int channel 	= 1;  // CPE
    int frameLength = bytesOfChunk + 7;

	queue_buffer_t* buffer = queue_buffer_malloc(frameLength);
	buffer->length 	= frameLength;
	buffer->timestamp = MediaGetTickCount();
	buffer->sequence++;

	int sampleRate = audioInContext->sampleRate;
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
    packet[2] = (unsigned char)(((profile) << 6) + (freqIdx << 2) +(channel >> 2));
    packet[3] = (unsigned char)(((channel & 0x03) << 6) + (frameLength >> 11));
    packet[4] = (unsigned char)((frameLength & 0x7FF) >> 3);
    packet[5] = (unsigned char)(((frameLength & 0x07) << 5) + 0x1F);
    packet[6] = (unsigned char)0xFC;

    //LOG_W("AudioInNextStream: %d", bytesOfChunk);

    packet += 7;
	memcpy(packet, pcmData, bytesOfChunk);

	if (queue_push(&audioInContext->fQueue, buffer) < 0) {
		printf("The queue is full!\r\n");
		queue_buffer_free(buffer);
	}
	
	return 0;
}

int AudioInNextStream(int channel)
{
	AudioInContext* audioInContext = AudioInGetContext(channel);
	if (audioInContext == NULL) {
		return -1;
	}

#ifdef _WIN32
	Sleep(40);
#else
	usleep(1000 * 40);
#endif
	//LOG_W("AudioInNextStream");

	char* buffer = audioInContext->pcmBuffer;
	uint32_t bufferLenth = audioInContext->pcmLength;
	uint32_t bufferOffset = audioInContext->pcmOffset;

	buffer += bufferOffset;
	int framesOfChunk = 1024;
	AudioEncodePcmFrame(audioInContext, buffer, framesOfChunk);
	bufferOffset += framesOfChunk * 4;
	if (bufferOffset > 1024 * 1024) {
		bufferOffset = 0;
	}

	audioInContext->pcmOffset = bufferOffset;

	return framesOfChunk * 4;
}

// Audio input channel
int AudioInClose(int channel)
{
	AudioInContext* audioInContext = AudioInGetContext(channel);
	if (audioInContext == NULL) {
		return -1;
	}

	AudioInSetContext(channel, NULL);

	free(audioInContext);
	return 0;
}

int AudioInGetStream(int channel, AudioSampleInfo* sampleInfo)
{
	AudioInContext* audioInContext = AudioInGetContext(channel);
	if (audioInContext == NULL) {
		return -1;
	}

	queue_buffer_t* buffer = queue_pop(&audioInContext->fQueue);
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
}

int AudioInReleaseStream(int channel, AudioSampleInfo* audioStream)
{
	return 0;
}

int AudioInOpen(int channel, AudioSettings* settings)
{
	int format = settings->fCodecFormat;

	AudioInContext* audioInContext = AudioInGetContext(channel);
	if (audioInContext != NULL) {
		return -1;
	}

	audioInContext = malloc(sizeof(AudioInContext));
	memset(audioInContext, 0, sizeof(*audioInContext));
	AudioInSetContext(channel, audioInContext);	

	audioInContext->sampleRate 		= settings->fSampleRate;
	audioInContext->sampleBits 		= settings->fSampleBits;
	audioInContext->channels 		= settings->fNumChannels;
	audioInContext->framesOfChunk 	= audioInContext->sampleRate / 10;
	audioInContext->inputSamples 	= 0;
	audioInContext->maxOutputBytes 	= 0;
	audioInContext->format  		= format;
	audioInContext->channel 		= channel;

	if (audioInContext->channels < 1) {
		audioInContext->channels = 1;

	} else if (audioInContext->channels > 2) {
		audioInContext->channels = 2;
	}

	audioInContext->pcmBuffer = malloc(1024 * 1024 * 2);
	audioInContext->pcmLength = 1024 * 1024;
	audioInContext->pcmOffset = 0;

	queue_init(&audioInContext->fQueue, 1024);

	char* buffer = audioInContext->pcmBuffer;
	FILE* file = fopen("/tmp/input.pcm", "rb");
	if (file) {
		int ret = fread(buffer, 1, 1024 * 1024 * 2, file);
		fclose(file);
		file = NULL;

		LOG_W("fread: %d", ret);	
		audioInContext->pcmLength = ret;
	}

	return 0;
}

int AudioInStop(int channel)
{
	return 0;
}


// Audio input
int AudioInRelease()
{
	return 0;
}

int AudioInInit()
{
	return 0;
}


///////////////////////////////////////////////////////////////////////////////
// Audio output

#define AUDIO_OUT_BUFFER_SIZE 2048

typedef struct AudioOutContext
{
#ifdef MEDIA_USE_FAAD
	NeAACDecHandle faadDecoder;  
#endif

	BOOL  decodeState;
	BYTE* frameBuffer;
	UINT  channels;
	UINT  frameBufferMaxSize;
	UINT  frameBufferSize;
	UINT  sampleBits;
	UINT  sampleRate;

} AudioOutContext;

AudioOutContext* audioOutContext = NULL;


int AudioOutOnFrame(int channel, void* context, BYTE* frameData, UINT frameSize);

int AudioOutDecodeFrame(int channel, BYTE* frameData, UINT frameSize, void* privateData)
{
	AudioOutContext* context = audioOutContext;
	if (context == NULL) {
		return -1;
	}


#ifdef MEDIA_USE_FAAD

	//LOG_W("AudioOutDecodeFrame: %x:%d", privateData, frameSize);

	NeAACDecHandle faadDecoder = context->faadDecoder;

	// 初始化解码器
	if (context->decodeState == 0) {
		context->decodeState = 1;

		unsigned long sampleRate = 0;  
	    unsigned char channels = 0;  

		NeAACDecInit(faadDecoder, frameData, frameSize, &sampleRate, &channels);  
    	printf("sampleRate %d, channels %d\n", (int)sampleRate, (int)channels);
    	context->sampleRate = sampleRate;
    	context->channels   = channels;
	}

	// 解码下一帧
	NeAACDecFrameInfo frameInfo; 
	memset(&frameInfo, 0, sizeof(frameInfo));
	BYTE* pcmData = (BYTE*)NeAACDecDecode(faadDecoder, &frameInfo, frameData, frameSize);
	if (frameInfo.error > 0) {  
 		if (frameInfo.error == 21) {
 			// 经测试, 出现这个错误必须重新打开解码器
 			context->decodeState = 0;
 			context->faadDecoder = 0;

 			NeAACDecClose(faadDecoder);

 			context->faadDecoder = NeAACDecOpen(); 
 		}

 		return -frameInfo.error;
    }

    /**
	printf("frame info: bytesconsumed %d, channels %d, header_type %d, "
			"object_type %d, samples %d, samplerate %d\n",   
                (int)frameInfo.bytesconsumed,   
                (int)frameInfo.channels, 
                (int)frameInfo.header_type,   
                (int)frameInfo.object_type, 
                (int)frameInfo.samples,   
                (int)frameInfo.samplerate); //*/

	int pcmLength = frameInfo.samples * 2;
	AudioOutOnFrame(channel, privateData, pcmData, pcmLength);
	return frameInfo.bytesconsumed;

#else 
	return 0;
#endif
}

int AudioOutWriteSample(int channel, AudioSampleInfo* sampleInfo)
{
	AudioOutContext* context = audioOutContext;
	if (context == NULL) {
		return -1;
	}

	UINT packetSize   = sampleInfo->fPacketSize;
	BYTE* packetData  = sampleInfo->fPacketData;
	void* privateData = sampleInfo->fPrivateData;

	//LOG_W("AudioOutWriteSample: %x:%d", privateData, packetSize);

	// 初始化缓存区
	if (context->frameBuffer == NULL) {
		context->frameBufferMaxSize = AUDIO_OUT_BUFFER_SIZE;
		if (context->frameBufferMaxSize <= packetSize * 3) {
			context->frameBufferMaxSize = packetSize * 3;
		}

    	context->frameBuffer = malloc(context->frameBufferMaxSize);
    	context->frameBufferSize = 0;
	}

	if (packetSize > context->frameBufferMaxSize) {
		return -3;
	} 

	if (context->frameBufferSize + packetSize > context->frameBufferMaxSize) {
		context->frameBufferSize = 0;
	}

	// 复制待解码的数据到缓存区, cache
	BYTE* p = context->frameBuffer + context->frameBufferSize;
	memcpy(p, packetData, packetSize);
	context->frameBufferSize += packetSize;

	// decode
	BYTE* data = context->frameBuffer;
	int size   = context->frameBufferSize;
	while (size > 7) { // sizeof(ADTS) == 7
		int ret = AudioOutDecodeFrame(channel, data, size, privateData);
		if (ret <= 0) {
			break;
		}

		// ret 表示已经被解码器消费的字节数
		data += ret;
		size -= ret;
	}

	// 将剩余未解码的数据复制到缓存区的开始位置
	memmove(context->frameBuffer, data, size);
	context->frameBufferSize = size;

	return 0;
}

int AudioOutClose(int channel)
{
	AudioOutContext* context = audioOutContext;
	audioOutContext = NULL;

	if (context) {

#ifdef MEDIA_USE_FAAD
		NeAACDecHandle faadDecoder = audioOutContext->faadDecoder;
		audioOutContext->faadDecoder = NULL;
		if (faadDecoder) {
			NeAACDecClose(faadDecoder);
		}
#endif
		// free buffer
		BYTE* buffer = context->frameBuffer;
		context->frameBuffer = NULL;
		if (buffer) {
			free(buffer);
		}
		
		free(context);
	}
	
	return 0;
}

int AudioOutOpen(int channel, int format)
{
	if (audioOutContext == NULL) {
		audioOutContext = malloc(sizeof(AudioOutContext));

		memset(audioOutContext, 0, sizeof(*audioOutContext));

#ifdef MEDIA_USE_FAAD
		audioOutContext->faadDecoder = NeAACDecOpen();
#endif

		return 0;
	}

	return -1;
}

int AudioOutInit()
{
	return 0;
}

int AudioOutRelease()
{
	return 0;
}