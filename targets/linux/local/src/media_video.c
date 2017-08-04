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
#include "media_v4l2.h"

#include "media_encode.c"
#include "media_mjpeg.c"

//_____________________________________________________________________________
///////////////////////////////////////////////////////////////////////////////
// V4LContext

V4LContext* fV4LContext = NULL;

V4LContext* VideoInGetContext(int channel)
{
	return fV4LContext;
}

int VideoInSetContext(int channel, V4LContext* context)
{
	fV4LContext = context;
	return 0;
}

//_____________________________________________________________________________
///////////////////////////////////////////////////////////////////////////////
// VideoEncodeContext

typedef struct VideoEncodeContext
{
	int   fBitrate;
	int   fChannel;
	int   fCodecFormat;
	int   fFrameRate;
	int   fSourceChannel;
	int   fSourceHeight;
	int   fSourceWidth;
	int   fVideoHeight;
	int   fVideoWidth;
	UINT  fSequence;

	queue_t fQueue;
	void* fEncoder;

} VideoEncodeContext;

VideoEncodeContext* fVideoEncodeContext = NULL;

VideoEncodeContext* VideoEncodeGetContext(int channel)
{
	return fVideoEncodeContext;
}

int VideoEncodeSetContext(int channel, VideoEncodeContext* context)
{
	fVideoEncodeContext = context;
	return 0;
}

//_____________________________________________________________________________
///////////////////////////////////////////////////////////////////////////////
// Video Encode Channel

int VideoEncodeClearQueue(VideoEncodeContext* context)
{
	// clear queue
	while (TRUE) {
		queue_buffer_t* buffer = queue_pop(&context->fQueue);
		if (buffer == NULL) {
			break;
		}

		queue_buffer_free(buffer);
	}

	return 0;	
}

int VideoEncodeClose(int channel)
{
	VideoEncodeContext* context = VideoEncodeGetContext(channel);
	if (context == NULL) {
		return -1;
	}

	VideoEncodeClearQueue(context);

#ifdef MEDIA_USE_AW_ENCODER

	void* encoder = context->fEncoder;
	context->fEncoder = NULL;

	if (encoder) {
		VencReleaseContext(encoder);
		encoder = NULL;
	}

#endif
	return 0;
}

int VideoEncodeGetAttributes(int channel, VideoSettings* settings)
{
	VideoEncodeContext* context = VideoEncodeGetContext(channel);

	if (settings == NULL) {
		return E_INALID_PARAMETER;

	} else if (context == NULL) {
		return E_NOT_INITIALIZED;
	}

	memset(settings, 0, sizeof(*settings));

	settings->fVideoWidth 	= context->fVideoWidth;
	settings->fVideoHeight 	= context->fVideoHeight;
	settings->fFrameRate	= context->fFrameRate;
	settings->fCodecFormat	= context->fCodecFormat;

	return 0;
}

queue_buffer_t* VideoEncodeJpegFrame(VideoEncodeContext* context, BYTE* frameBuffer, int frameSize)
{
	if (context == NULL) {
		return NULL;
	}

	if (frameBuffer == NULL) {
		return NULL;

	} else if (frameSize <= HEADERFRAME1) { 
		/* Prevent crash on empty image */
		LOG_W("Ignoring empty buffer ...\n");
		return NULL;
	}

	// JPEG format
	if (memcmp("AVI1", frameBuffer + 6, 4) != 0) {
		queue_buffer_t* buffer = queue_buffer_malloc(frameSize);
		buffer->timestamp = MediaGetTickCount();
		buffer->length    = frameSize;
		buffer->flags 	  = FLAG_IS_SYNC;

		memcpy(buffer->data, frameBuffer, frameSize);
		return buffer;
	}

	// MJPEG format
	int skipSize = (frameBuffer[4] << 8) + frameBuffer[5] + 4;
	if (frameSize > skipSize) {
		frameBuffer += skipSize;
		frameSize   -= skipSize;
		int jpegSize = frameSize + sizeof(jpeg_header) + dht_segment_size;

		queue_buffer_t* buffer = queue_buffer_malloc(jpegSize);
		buffer->timestamp = MediaGetTickCount();
		buffer->length    = jpegSize;
		buffer->flags 	  = FLAG_IS_SYNC;

		BYTE* out = buffer->data;
		out = append(out, jpeg_header, sizeof(jpeg_header));
		out = append_dht_segment(out);
		out = append(out, frameBuffer, frameSize);

		return buffer;
	}

	return NULL;
}

int VideoEncodeH264Init(VideoEncodeContext* context)
{
	if (context == NULL) {
		return E_NOT_INITIALIZED;
	}

#ifdef MEDIA_USE_AW_ENCODER
	if (context->fEncoder != NULL) {
		return 0;
	}

	VideoEncodeSettings settings;
	memset(&settings, 0, sizeof(settings));

	settings.bitrate 		= context->fBitrate;
	settings.codecType 		= VENC_CODEC_H264;
	settings.destHeight		= context->fVideoHeight;
	settings.destWidth		= context->fVideoWidth;
	settings.framerate		= context->fFrameRate;

	settings.keyInterval 	= context->fFrameRate;
	settings.qMax			= 30;
	settings.qMin			= 15;
	settings.sourceHeight	= context->fSourceHeight;
	settings.sourceWidth	= context->fSourceWidth;

	if (context->fCodecFormat == MEDIA_FORMAT_JPEG) {
		settings.codecType 	= VENC_CODEC_JPEG;
		settings.qMax		= 70;
	}

	context->fEncoder = VencCreate(&settings);
	
#endif

	return 0;
}

queue_buffer_t* VideoEncodeYUYVFrame(VideoEncodeContext* context, BYTE* frameData, int frameSize)
{
	if (context == NULL) {
		LOG_W("context is NULL");
		return NULL;

	} else if (frameData == NULL) {
		return NULL;
	}

	V4LContext* videoInContext = VideoInGetContext(0);
	if (videoInContext == NULL) {
		LOG_W("videoInContext is NULL");
		return NULL;
	}

#ifdef MEDIA_USE_JPEG_LIB

	BYTE *yuvData 	 = frameData;
	int imageWidth 	 = videoInContext->fSourceWidth;
	int imageHeight  = videoInContext->fSourceHeight;
	int quality 	 = 80;
	BYTE* jpegBuffer = NULL;
	ulong jpegSize   = 0;

	MediaJpegEncodeYUYV(yuvData, imageWidth, imageHeight, quality, &jpegBuffer, &jpegSize);
	if (jpegBuffer == NULL) {
		LOG_W("MediaJpegEncode failed");
		return NULL;
	}

	//LOG_W("%x, %d", jpegBuffer, jpegSize);
	queue_buffer_t* buffer = queue_buffer_malloc2(jpegBuffer, jpegSize);
	buffer->timestamp = MediaGetTickCount();
	buffer->length    = jpegSize;
	buffer->flags 	  = FLAG_IS_SYNC;	

	memcpy(buffer->data, jpegBuffer, jpegSize);

	return buffer;

#else
	//  /usr/local/lnode/app/camera/init.lua snapshot
	return NULL;

#endif
}

queue_buffer_t* VideoEncodeYV12Frame(VideoEncodeContext* context, BYTE* frameData, int frameSize)
{
	if (context == NULL) {
		LOG_W("context is NULL");
		return NULL;
	}

	V4LContext* videoInContext = VideoInGetContext(0);

	if (context->fCodecFormat == MEDIA_FORMAT_JPEG) {
		int imageWidth 	 = videoInContext->fSourceWidth;
		int imageHeight  = videoInContext->fSourceHeight;

		BYTE *yuvData 	 = frameData;
		int quality 	 = 80;
		BYTE* jpegBuffer = NULL;
		ulong jpegSize   = 0;

		MediaJpegEncodeYUV420(yuvData, imageWidth, imageHeight, quality, &jpegBuffer, &jpegSize);
		if (jpegBuffer == NULL) {
			LOG_W("MediaJpegEncode failed");
			return NULL;
		}

		// LOG_W("%x, %d", jpegBuffer, jpegSize);
		queue_buffer_t* buffer = queue_buffer_malloc(jpegSize);
		buffer->timestamp = MediaGetTickCount();
		buffer->length    = jpegSize;
		buffer->flags 	  = FLAG_IS_SYNC;	

		memcpy(buffer->data, jpegBuffer, jpegSize);
		
		return buffer;
	}

#ifdef MEDIA_USE_AW_ENCODER

	void* videoEncoder = context->fEncoder;
	queue_buffer_t* buffer = VencEncodeFrame(videoEncoder, frameData, frameSize);
	if (buffer == NULL) {
		LOG_W("VencEncodeFrame failed");
		return NULL;
	}

	return buffer;

#else
	LOG_W("VideoEncodeH264Frame not supported");
	return NULL;

#endif
}

int VideoEncodeNextFrame(VideoEncodeContext* context)
{
	V4LContext* videoInContext = VideoInGetContext(0);
	if (videoInContext == NULL) {
		LOG_W("videoInContext is NULL");
		return -1;
	}

	struct v4l2_buffer v4l2Buffer;
	memset(&v4l2Buffer, 0, sizeof(v4l2Buffer));
	BYTE* frameBuffer = V4LGetBuffer(videoInContext, &v4l2Buffer);
	if (frameBuffer == NULL) {
		LOG_W("V4LGetBuffer return NULL.");
		return -1;
	}

	int frameSize = v4l2Buffer.bytesused;
	int pixelFormat = videoInContext->fPixelFormat;
	queue_buffer_t* buffer = NULL;

	switch (pixelFormat) {
	case V4L2_PIX_FMT_MJPEG:
		buffer = VideoEncodeJpegFrame(context, frameBuffer, frameSize);
		break;

	case V4L2_PIX_FMT_YUYV:
		buffer = VideoEncodeYUYVFrame(context, frameBuffer, frameSize);
		break;

	case V4L2_PIX_FMT_NV12:
	case V4L2_PIX_FMT_YUV420:
		buffer = VideoEncodeYV12Frame(context, frameBuffer, frameSize);
		break;
	}

	int ret = -1;
	if (buffer) {
    	buffer->sequence  = context->fSequence++;

		if (queue_push(&context->fQueue, buffer) < 0) {
			queue_buffer_free(buffer);
			ret = 0;
		}
	}

	V4LQueueBuffer(videoInContext, v4l2Buffer.index);
	return ret;
}

// 返回采集的帧的大小
int VideoEncodeNextStream(int channel, BOOL isBlocking)
{
	VideoEncodeContext* context = VideoEncodeGetContext(channel);
	if (context == NULL) {
		return E_NOT_INITIALIZED;
	}

	if (isBlocking) {
		V4LContext* videoInContext = VideoInGetContext(0);
		if (videoInContext == NULL) {
			return E_NOT_INITIALIZED;
		}

		int ret = V4LWaitReady(videoInContext, 2);
		if (ret < 0) {
			return ret;
		}
	}

	VideoEncodeNextFrame(context);

	return 0;
}

// 返回采集的帧的大小
int VideoEncodeGetStream(int channel, VideoSampleInfo* sampleInfo)
{
	VideoEncodeContext* context = VideoEncodeGetContext(channel);
	if (context == NULL) {
		return E_NOT_INITIALIZED;

	} else if (sampleInfo == NULL) {
		return 0;
	}

	queue_buffer_t* buffer = queue_pop(&context->fQueue);
	if (buffer == NULL) {
		return -1;
	}

	UINT index = 0;
	sampleInfo->fPacketSize[index] 	= buffer->length;
	sampleInfo->fPacketData[index] 	= buffer->data;
	sampleInfo->fPacketCount 		= 1;
	sampleInfo->fSampleTime  		= buffer->timestamp;
	sampleInfo->fSequence	 		= buffer->sequence;
	sampleInfo->fPrivateData 		= buffer;
	sampleInfo->fFlags 				= buffer->flags;

	return buffer->length;
}

int VideoEncodeOpen(int channel, struct VideoSettings* settings) 
{
	if (settings == NULL) {
		LOG_D("Not supported settings.");
		return E_INALID_PARAMETER;
	}

	VideoEncodeContext* context = VideoEncodeGetContext(channel);
	if (context != NULL) {
		return -1;
	}

	context = malloc(sizeof(VideoEncodeContext));
	memset(context, 0, sizeof(*context));
	VideoEncodeSetContext(channel, context);

	queue_init(&context->fQueue, 128);
	
	V4LContext* v4lContext = VideoInGetContext(0);
	v4lContext->fDebugFlags = settings->fFlags;
	if (v4lContext->fSourceWidth <= 0) {
		v4lContext->fSourceHeight = settings->fVideoHeight;
		v4lContext->fSourceWidth  = settings->fVideoWidth;
	}

	context->fChannel 	   = channel;
	context->fCodecFormat  = settings->fCodecFormat;
	context->fBitrate      = settings->fBitrate;
	context->fFrameRate    = settings->fFrameRate;
	context->fVideoHeight  = settings->fVideoHeight;
	context->fVideoWidth   = settings->fVideoWidth;
	context->fSourceHeight = v4lContext->fSourceHeight;
	context->fSourceWidth  = v4lContext->fSourceWidth;
	
	LOG_D("%d (%dx%d) %dfps %dkbps\r\n", 
		channel, context->fSourceWidth, context->fSourceHeight, 
		context->fFrameRate, context->fBitrate);

	int ret = V4LOpen(v4lContext);
	if (ret < 0) {
		return ret;
	}

	VideoEncodeH264Init(context);

	return channel;
}

int VideoEncodeBind(int channel, int groupId)
{
	VideoEncodeContext* context = VideoEncodeGetContext(channel);
	if (context == NULL) {
		return E_NOT_INITIALIZED;
	}

	context->fSourceChannel = groupId;
	//printf("VideoEncodeBind (%d.%d)\n", channel, groupId);
	return 0;
}

int VideoEncodeReleaseStream(int channel, struct VideoSampleInfo* sampleInfo)
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

int VideoEncodeRenewStream(int channel) 
{
	return E_UNSUPPORTED;
}

int VideoEncodeSetAttributes(int channel, struct VideoSettings* settings) 
{
	// TODO:
	return 0;
}

int VideoEncodeSetCrop(int groupId, int l, int t, int w, int h)
{
	// TODO: 不支持视频剪切
	return E_UNSUPPORTED;
}

int VideoEncodeStart(int channel, int flags) 
{ 
	return V4LStartStreaming(VideoInGetContext(0));
}

int VideoEncodeStop(int channel)
{
	return V4LStopStreaming(VideoInGetContext(0));
}

//______________________________________________________________________________
////////////////////////////////////////////////////////////////////////////////
// Video Input

int VideoInInit(UINT flags) 
{
	return 0;
}

int VideoInRelease() 
{
	return 0;
}

int VideoInClose(int channel) 
{
	V4LContext* videoInContext = VideoInGetContext(channel);
	VideoInSetContext(channel, NULL);

	if (videoInContext) {
		V4LClose(videoInContext);
		videoInContext = NULL;
	}

	return 0;
}

int VideoInGetFrameRate( int channel )
{
	V4LContext* videoInContext = VideoInGetContext(channel);
	if (videoInContext) {
		return videoInContext->fSourceFrameRate;
	}

	return 0;
}

int VideoInOpen( int channel, int width, int height, int flags ) 
{
	V4LContext* videoInContext = VideoInGetContext(channel);
	if (videoInContext == NULL) {
		videoInContext = V4LCreate();

		VideoInSetContext(channel, videoInContext);
	}

	if (videoInContext) {
		videoInContext->fSourceChannel = channel;
		videoInContext->fSourceWidth  	= width;
		videoInContext->fSourceHeight 	= height;
		snprintf(videoInContext->fDeviceName, 255, "/dev/video%d", channel);
	}

	return 0;
}

/** */
int VideoInSetFrameRate( int channel, UINT frameRate )
{
	V4LContext* videoInContext = VideoInGetContext(channel);
	if (videoInContext) {
		videoInContext->fSourceFrameRate = frameRate;
	}
	return 0;
}
