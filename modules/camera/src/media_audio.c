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

#ifdef MEDIA_USE_FAAD
#include <neaacdec.h>
#endif

#ifdef MEDIA_USE_FAAC
#include <faac.h>
#endif

#ifdef MEDIA_USE_ALSA
#include <alsa/asoundlib.h>
#endif

///////////////////////////////////////////////////////////////////////////////
// Audio input

typedef struct AudioInContext
{
	int   channel;
	uint  format;
    uint  framesOfChunk;
    ulong sampleRate;
    uint  channels;
    uint  sampleBits;
    ulong inputSamples;
    ulong maxOutputBytes;

	queue_t fQueue;

#ifdef MEDIA_USE_ALSA
	snd_pcm_t *alsaHandle;
#endif

#ifdef MEDIA_USE_FAAC
    faacEncHandle faacEncoder;
#endif

} AudioInContext;

static int AudioEncodeOpen(AudioInContext* audioInContext)
{
#ifdef MEDIA_USE_FAAC

	uint sampleRate = audioInContext->sampleRate;
	uint channels   = audioInContext->channels;
	uint sampleBits = audioInContext->sampleBits;

	if (channels < 1) {
		channels = 1;
	}

	ulong inputSamples   = 0;
	ulong maxOutputBytes = 0;
	faacEncHandle faacEncoder = faacEncOpen(sampleRate, channels, &inputSamples, &maxOutputBytes);
	if (faacEncoder == NULL) {
		LOG_W("faacEncOpen failed!");
		return -1;
	}
	audioInContext->faacEncoder = faacEncoder;

	//printf("inputSamples: %d\r\n",   (int)inputSamples);
	//printf("maxOutputBytes: %d\r\n", (int)maxOutputBytes);

	audioInContext->inputSamples 	= inputSamples;
	audioInContext->maxOutputBytes  = maxOutputBytes;
	audioInContext->framesOfChunk 	= inputSamples / channels;

	// FAAC configuration
	faacEncConfigurationPtr configuration = faacEncGetCurrentConfiguration(faacEncoder);
	configuration->inputFormat = FAAC_INPUT_16BIT;
	faacEncSetConfiguration(faacEncoder, configuration);

#endif
	return 0;
}

static int AudioEncodeAacFrame(AudioInContext* audioInContext, char* pcmData, int framesOfChunk)
{
#ifdef MEDIA_USE_FAAC

	faacEncHandle encoder = audioInContext->faacEncoder; 
	if (encoder == NULL) {
		return -1;
	}

	unsigned long maxOutputBytes = audioInContext->maxOutputBytes;
	int inputSamples = framesOfChunk * audioInContext->channels;

	unsigned char *aacBuffer = malloc(maxOutputBytes);
	int aacSize = faacEncEncode(encoder, (int32_t*)pcmData, inputSamples, aacBuffer, maxOutputBytes);
	if (aacSize > 0) {
		queue_buffer_t* queue_buffer = queue_buffer_malloc(aacSize);
		queue_buffer->length 	= aacSize;
		queue_buffer->timestamp = MediaGetTickCount();
		queue_buffer->sequence++;

		memcpy(queue_buffer->data, aacBuffer, aacSize);
		if (queue_push(&audioInContext->fQueue, queue_buffer) < 0) {
			printf("The queue is full!\r\n");
			queue_buffer_free(queue_buffer);
		}
	}

	free(aacBuffer);

#endif
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

    packet += 7;
	memcpy(packet, pcmData, bytesOfChunk);
	if (queue_push(&audioInContext->fQueue, buffer) < 0) {
		printf("The queue is full!\r\n");
		queue_buffer_free(buffer);
	}
	
	return 0;
}

static int AudioEncodeClose(AudioInContext* audioInContext)
{
#ifdef MEDIA_USE_FAAC
	faacEncHandle faacEncoder = audioInContext->faacEncoder;
	audioInContext->faacEncoder = NULL;
	if (faacEncoder) {
		faacEncClose(faacEncoder);
	}
#endif

	return 0;
}

//______________________________________________________________________________
////////////////////////////////////////////////////////////////////////////////
// AudioInContext


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

int AudioInClose(int channel)
{
	AudioInContext* audioInContext = AudioInGetContext(channel);
	if (audioInContext == NULL) {
		return -1;
	}

	AudioEncodeClose(audioInContext);

#ifdef MEDIA_USE_ALSA
	snd_pcm_t* alsaHandle = audioInContext->alsaHandle;
	audioInContext->alsaHandle = NULL;
	if (alsaHandle) {
		snd_pcm_close(alsaHandle);
	}
#endif

	AudioInSetContext(channel, NULL);

	free(audioInContext);

	return 0;
}

static int AudioInSetParams(AudioInContext* audioInContext)
{
#ifdef MEDIA_USE_ALSA

	snd_pcm_t* handle = audioInContext->alsaHandle;
	if (handle == NULL) {
		return -1;
	}

	uint sampleRate = audioInContext->sampleRate;
	uint channels   = audioInContext->channels;
	snd_pcm_uframes_t frameCount = audioInContext->framesOfChunk;

	snd_pcm_hw_params_t* params = NULL;
	snd_pcm_hw_params_alloca(&params);
	snd_pcm_hw_params_any					(handle, params);
	snd_pcm_hw_params_set_access   			(handle, params, SND_PCM_ACCESS_RW_INTERLEAVED);
	snd_pcm_hw_params_set_format   			(handle, params, SND_PCM_FORMAT_S16_LE);
	snd_pcm_hw_params_set_channels 			(handle, params, channels);
	snd_pcm_hw_params_set_rate_near			(handle, params, &sampleRate, 0);
	snd_pcm_hw_params_set_period_size_near	(handle, params, &frameCount, 0);

	printf("snd_pcm_hw_params_set_rate_near: %d\r\n", (int)sampleRate);
	printf("snd_pcm_hw_params_set_period_size_near: %d\r\n", (int)frameCount);

	int ret = snd_pcm_hw_params(handle, params);
	if (ret < 0) {
		fprintf(stderr, "unable to set hw parameters: %s\n", snd_strerror(ret));
	}

	snd_pcm_uframes_t framesOfChunk = 0;
	int periodTime = 0;
	snd_pcm_hw_params_get_period_size(params, &framesOfChunk, 0);
	snd_pcm_hw_params_get_period_time(params, &periodTime, 0);
	audioInContext->framesOfChunk = framesOfChunk;

	printf("snd_pcm_hw_params_get_period_size: %d\r\n", (int)framesOfChunk);
	printf("snd_pcm_hw_params_get_period_time: %d\r\n", (int)periodTime);

	//snd_pcm_hw_params_free(params);
	params = NULL;

#endif
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

int AudioInInit()
{
	return 0;
}

int AudioInNextStream(int channel)
{
	AudioInContext* audioInContext = AudioInGetContext(channel);
	if (audioInContext == NULL) {
		return -1;
	}

	int framesOfChunk = audioInContext->framesOfChunk;
	int frameSize    = (audioInContext->sampleBits / 8) * audioInContext->channels;

	char *pcmBuffer = malloc(framesOfChunk * frameSize);

	int ret = AudioInRead(audioInContext, pcmBuffer, framesOfChunk);
	if (ret > 0) {
		if (audioInContext->format == MEDIA_FORMAT_AAC) {
			AudioEncodeAacFrame(audioInContext, pcmBuffer, framesOfChunk);

		} else {
			AudioEncodePcmFrame(audioInContext, pcmBuffer, framesOfChunk);
		}
	}

	free(pcmBuffer);

	return ret;
}

static int AudioInOpenDevice(int channel, AudioInContext* audioInContext)
{
#ifdef MEDIA_USE_ALSA
	if (audioInContext->alsaHandle != NULL) {
		return -1;
	}

	char name[256];
	memset(name, 0, sizeof(name));

	if (channel <= 0) {
		strcpy(name, "default");
	} else {
		snprintf(name, 255, "plughw:%d,0", channel);
	}

	LOG_I("name = `%s` (%d)", name, channel);
	int ret = snd_pcm_open(&audioInContext->alsaHandle, name, SND_PCM_STREAM_CAPTURE, 0);
	if (ret < 0) {
		fprintf(stderr,"unable to open pcm device: %s\n", snd_strerror(ret));
		return -1;
	}
#endif

	return 0;
}

int AudioInOpen(int channel, AudioSettings* settings)
{
	AudioInContext* audioInContext = AudioInGetContext(channel);
	if (audioInContext != NULL) {
		return -1;
	}

	int format = settings->fCodecFormat;

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
	
	//LOG_W("AudioInOpen: %x", audioInContext->format);

	if (audioInContext->format == MEDIA_FORMAT_AAC) {
		AudioEncodeOpen(audioInContext);
	}

	int ret = AudioInOpenDevice(channel, audioInContext);
	if (ret < 0) {
		return ret;
	}

	AudioInSetParams(audioInContext);

	queue_init(&audioInContext->fQueue, 1024);

	return 0;
}

static int AudioInRead(AudioInContext* audioInContext, char* buffer, int sampleCount)
{
#ifdef MEDIA_USE_ALSA
	int ret = 0;
	while (TRUE) {
		snd_pcm_t* handle = audioInContext->alsaHandle;
		if (handle == NULL) {
			ret = -1;
		}

		int readSize = snd_pcm_readi(handle, buffer, sampleCount);
		if (readSize == -EPIPE) {
			fprintf(stderr, "overrun occurred\n");
			snd_pcm_prepare(handle);
			break;


		} else if (readSize < 0) {
			fprintf(stderr, "error from read: %s\n", snd_strerror(readSize));
			break;

		} else if (readSize != (int)sampleCount) {
			fprintf(stderr, "short read, read %d framesOfChunk\n", readSize);
			ret = readSize;

		} else {
			ret = sampleCount;
		}

		break;
	}

	return ret;

#else 
	return 0;

#endif
}

int AudioInRelease()
{
	return 0;
}

int AudioInReleaseStream(int channel, AudioSampleInfo* sampleInfo)
{
	queue_buffer_t* buffer = (queue_buffer_t*)sampleInfo->fPrivateData;
	sampleInfo->fPrivateData = NULL;

	if (buffer) {
		queue_buffer_free(buffer);
	}

	return 0;
}

int AudioInStop(int channel)
{
	AudioInContext* audioInContext = AudioInGetContext(channel);
	if (audioInContext == NULL) {
		return -1;
	}

	#ifdef MEDIA_USE_ALSA
	snd_pcm_t* alsaHandle = audioInContext->alsaHandle;
	audioInContext->alsaHandle = NULL;
	if (alsaHandle) {
		snd_pcm_close(alsaHandle);
	}
	#endif

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

	LOG_W("AudioOutDecodeFrame: %x:%d", frameData, frameSize);

#ifdef MEDIA_USE_FAAD

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

    //**
	printf("frame info: bytesconsumed %d, channels %d, header_type %d, "
			"object_type %d, samples %d, samplerate %d\n",   
                (int)frameInfo.bytesconsumed,   
                (int)frameInfo.channels, 
                (int)frameInfo.header_type,   
                (int)frameInfo.object_type, 
                (int)frameInfo.samples,   
                (int)frameInfo.samplerate); 

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

	UINT packetSize  = sampleInfo->fPacketSize;
	BYTE* packetData = sampleInfo->fPacketData;
	void* privateData    = sampleInfo->fPrivateData;

	LOG_W("AudioOutWriteSample: %x:%d", packetData, packetSize);

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
