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
#include "media_queue.c"

typedef struct VideoEncodeContext
{
	queue_t fQueue;

} VideoEncodeContext;


VideoEncodeContext videoEncodeContext[8];
int VideoEncodeContextState = 0;


VideoEncodeContext* VideoEncodeGetContext(int channel)
{
	if (channel < 0 || channel >= 8) {
		return NULL;
	}

	if (VideoEncodeContextState == 0) {
		VideoEncodeContextState = 1;
		memset(videoEncodeContext, 0, sizeof(videoEncodeContext));
	}

	return &videoEncodeContext[channel];
}

//_____________________________________________________________________________
///////////////////////////////////////////////////////////////////////////////
// Video Encode Channel

int VideoEncodeClose(int channel)
{
	return HI_MPI_VENC_DestroyChn(channel);
}

int VideoEncodeGetAttributes(int channel, VideoSettings* settings)
{

	return -1;
}

/** 获取编码通道对应的设备文件句柄 */
int VideoEncodeGetDescriptor(int channel) 
{ 
	return HI_MPI_VENC_GetFd(channel); 
}

int VideoEncodeGetPacketCount(int channel)
{
	// Channel state
	VENC_CHN_STAT_S channelStat;
	memset(&channelStat, 0, sizeof(channelStat));

	int ret = HI_MPI_VENC_Query(channel, &channelStat);
	if (ret != HI_SUCCESS || channelStat.u32CurPacks <= 0) {
		return 0;
	}

	return channelStat.u32CurPacks;
}

/** 获取编码的码流。*/
int VideoEncodeGetStream(int channel, VideoSampleInfo* sampleInfo)
{
	if (sampleInfo == NULL) {
		return 0;
	}

	VideoEncodeContext* context = VideoEncodeGetContext(channel);

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

int VideoEncodeWaitReady(int fd)
{
	if (fd <= 0) {
		return -1;
	}

	fd_set fds;		
	struct timeval tv;
	int r;

	FD_ZERO(&fds);
	FD_SET(fd, &fds);		
	
	/* Timeout */
	tv.tv_sec  = 2;
	tv.tv_usec = 0;
	
	r = select(fd + 1, &fds, NULL, NULL, &tv);
	if (r == -1) {
		return -10045;

	} else if (r == 0) {
		return 0;
	}

	return 1;
}


// 返回采集的帧的大小
int VideoEncodeNextStream(int channel, BOOL isBlocking)
{
	int ret = VideoEncodeWaitReady(VideoEncodeGetDescriptor(channel));
	if (ret <= 0) {
		return ret;
	}

	int bufferCount = VideoEncodeGetPacketCount(channel);
	if (bufferCount <= 0) {
		return 0;
	}

	VENC_STREAM_S* videoStream = malloc(sizeof(VENC_STREAM_S));
	memset(videoStream, 0, sizeof(VENC_STREAM_S));

	videoStream->pstPack = malloc(sizeof(VENC_PACK_S) * kVideoSampleMaxCount);
	memset(videoStream->pstPack, 0, sizeof(VENC_PACK_S) * kVideoSampleMaxCount);

	videoStream->u32PackCount = bufferCount;
	videoStream->u32Seq		  = 0;

	if (videoStream->u32PackCount > kVideoSampleMaxCount) {
		videoStream->u32PackCount = kVideoSampleMaxCount;
	}

	ret = HI_MPI_VENC_GetStream(channel, videoStream, 0);
	HI_U32 packetCount = videoStream->u32PackCount;
	
	int buf_size = 0;

	if (packetCount > 0) {

		HI_U32 index = 0;
		HI_U32 i = 0;
		for (i = 0; i < packetCount; i++) {
			VENC_PACK_S* packet = &videoStream->pstPack[i];
			if (packet->u32Len > 0) {
				buf_size += packet->u32Len;
				index++;
			}

			if (index >= kVideoSampleMaxCount - 1) {
				break;
			}
		}

		queue_buffer_t* buffer = queue_buffer_malloc(buf_size);
		buffer->length    = buf_size;
		buffer->flags     = 0;

		BYTE* packetBuffer = buffer->data;

		for (i = 0; i < index; i++) {
			VENC_PACK_S* packet = &videoStream->pstPack[i];
			if (packet->u32Len > 0) {
				index++;

				memcpy(packetBuffer, packet->pu8Addr, packet->u32Len);
				packetBuffer += packet->u32Len;
			}
		}

		buffer->timestamp  = videoStream->pstPack[0].u64PTS;
		//sampleInfo->fSequence	 = videoStream->u32Seq;

		int nalType = buffer->data[4] & 0x1f;
		if (nalType == 0x07 || nalType == 0x08 || nalType == 0x05) {
			buffer->flags     = 0x01; // sync point
		}

		VideoEncodeContext* context = VideoEncodeGetContext(channel);
		queue_push(&context->fQueue, buffer);
	}

	HI_MPI_VENC_ReleaseStream(channel, videoStream);

	if (videoStream->pstPack) {
		free(videoStream->pstPack);
		videoStream->pstPack = NULL;
	}

	free(videoStream);
	videoStream = NULL;

	//LOG_W("VideoEncodeNextStream: %d", buf_size);

	return buf_size;
}

int VideoEncodeInitAttributes(VENC_ATTR_H264_S* attributes, VideoSettings* settings)
{
	if (attributes == NULL || settings == NULL) {
		return -1;
	}

	// video size
	HI_U32 width  = settings->fVideoWidth;
	HI_U32 height = settings->fVideoHeight;

	// attributes
	memset(attributes, 0, sizeof(*attributes));
	attributes->u32BFrameNum	= 0;  /* 0: not support B frame; >=1: number of B frames */
	attributes->u32RefNum		= 1;  /* 0: default; number of refrence frame */	 
	attributes->bByFrame		= HI_TRUE; /*get stream mode is slice mode or frame mode?*/
	attributes->u32BufSize		= width * height * 2;
	attributes->u32MaxPicHeight	= height;
	attributes->u32MaxPicWidth	= width;
	attributes->u32PicHeight	= height;
	attributes->u32PicWidth		= width;
	attributes->u32Profile		= 0; /* 0: Baseline; 1:MP; 2:HP   ? */

	return 0;
}

int VideoEncodeOpenH264(int channel, VideoSettings* settings) 
{
	if (settings == NULL) {
		LOG_E("Invalid parameter (settings is NULL).");
		return -1;

	} else if (channel < 0 && channel > 2) {
		LOG_E("Only channel 0~2 video capture is supported (%d).", channel);
		return -1;
	}

	// 创建一个新的编码通道
	VENC_CHN_ATTR_S channelAttributes;
	memset(&channelAttributes, 0, sizeof(VENC_CHN_ATTR_S));

	// H.264 attributes
	VENC_ATTR_H264_S* h264Attributes = &(channelAttributes.stVeAttr.stAttrH264e);
	VideoEncodeInitAttributes(h264Attributes, settings);

	channelAttributes.stVeAttr.enType = PT_H264;
	LOG_D("%d (%dx%d) (%dfps, %dkbps)\r\n", channel, 
		settings->fVideoWidth, settings->fVideoHeight,
		settings->fFrameRate, settings->fBitrate);

	// Bitrate mode
	channelAttributes.stRcAttr.enRcMode = VENC_RC_MODE_H264VBR;
	VENC_ATTR_H264_VBR_S* vbr = &(channelAttributes.stRcAttr.stAttrH264Vbr);
	vbr->fr32DstFrmRate = settings->fFrameRate;	/* target frame rate */
	vbr->u32Gop			= settings->fGopLength;
	vbr->u32MaxBitRate	= settings->fBitrate; 	// 1024 * 6 * 3;
	vbr->u32MaxQp		= 32;
	vbr->u32MinQp		= 16;
	vbr->u32StatTime	= 1;		/* stream rate statics time(s) */
	vbr->u32SrcFrmRate	= HI_VIDEO_IN_FRAMERATE; /* input (vi) frame rate */

	// TODO: CBR

	// 
	int ret = HI_MPI_VENC_CreateChn(channel, &channelAttributes);
	if (ret < HI_SUCCESS) {
		LOG_W("HI_MPI_VENC_CreateChn: 0x%x", ret)
		return ret; 
	}

	return channel;
}

int VideoEncodeOpenJpeg(int channel, VideoSettings* settings)
{
	if (settings == NULL) {
		LOG_E("Invalid parameter (settings is NULL).");
		return -1;

	} else if (channel != 0) {
		LOG_E("Only channel 0 image capture is supported (%d).", channel);
		return -1;
	}

	channel = VPSS_CHN3;

	// video size
	HI_U32 width  = settings->fVideoWidth;
	HI_U32 height = settings->fVideoHeight;

	// 创建一个 JPEG 抓拍通道
	VENC_CHN_ATTR_S channelAttributes;
	memset(&channelAttributes, 0 ,sizeof(VENC_CHN_ATTR_S));
	channelAttributes.stVeAttr.enType = PT_JPEG;
	VENC_ATTR_JPEG_S* jpegAttr  = &(channelAttributes.stVeAttr.stAttrJpeg);
	jpegAttr->u32MaxPicWidth	= width;
	jpegAttr->u32MaxPicHeight	= height;
	jpegAttr->u32PicWidth		= width;
	jpegAttr->u32PicHeight		= height;
	jpegAttr->u32BufSize		= width * height * 2;
	jpegAttr->bSupportDCF		= HI_FALSE;
	jpegAttr->bByFrame			= HI_TRUE;

	int ret = HI_MPI_VENC_CreateChn(channel, &channelAttributes);
	if (ret != HI_SUCCESS) {
		LOG_W("HI_MPI_VENC_CreateChn: 0x%x", ret)
		return ret;
	}

	VENC_PARAM_JPEG_S jpegParameters; 
	ret = HI_MPI_VENC_GetJpegParam(channel, &jpegParameters); 
	if (ret == HI_SUCCESS) {
		// For RFC2435, deault is 90
		jpegParameters.u32Qfactor = 30;
		ret = HI_MPI_VENC_SetJpegParam(channel, &jpegParameters); 
			if (ret != HI_SUCCESS) {
				LOG_W("HI_MPI_VENC_SetJpegParam: 0x%x", ret)
			}
	}

	LOG_D("ret=%d, size=%dx%d\r\n", ret, width, height);

	return channel;
}

int VideoEncodeOpen(int channel, VideoSettings* settings) 
{
	if (settings == NULL) {
		LOG_E("Invalid parameter (settings is NULL).");
		return -1;
	}

	if (settings->fVideoWidth  < 320)  settings->fVideoWidth = 320;
	if (settings->fVideoHeight < 180)  settings->fVideoWidth = 180;
	if (settings->fBitrate < 100)    { settings->fFrameRate  = 100; }
	if (settings->fFrameRate > 30)   { settings->fFrameRate  = 30;  }

	if (channel == 2) {
		if (settings->fVideoWidth  > 640)  settings->fVideoWidth = 640;
		if (settings->fVideoHeight > 360)  settings->fVideoWidth = 360;
		if (settings->fBitrate > 1024)   { settings->fFrameRate  = 1024; }

	} else if (channel == 1) {
		if (settings->fVideoWidth  > 1280) settings->fVideoWidth = 1280;
		if (settings->fVideoHeight > 720)  settings->fVideoWidth = 720;
		if (settings->fBitrate > 2048)   { settings->fFrameRate  = 2048; }

	} else if (channel == 0) {
		if (settings->fVideoWidth  > 1920) settings->fVideoWidth = 1920;
		if (settings->fVideoHeight > 1080) settings->fVideoWidth = 1080;
		if (settings->fBitrate > 4096)   { settings->fFrameRate  = 4096; }

	} else if (channel == 3) {
		if (settings->fVideoWidth  > 1280) settings->fVideoWidth = 1280;
		if (settings->fVideoHeight > 720) settings->fVideoWidth = 720;		
	}


	int ret = -1;
	if (settings->fCodecFormat == MEDIA_FORMAT_JPEG) {
		ret = VideoEncodeOpenJpeg(channel, settings);

	} else {
		ret = VideoEncodeOpenH264(channel, settings);
	}

	if (ret < 0) {
		return ret;
	}

	channel = ret;

	//LOG_D("ch=%d, type=%d, size=(%dx%d)\r\n", channel, 
	//	settings->fCodecFormat, settings->fVideoWidth, settings->fVideoHeight);

	VideoEncodeContext* context = VideoEncodeGetContext(channel);
	if (context) {
		queue_init(&context->fQueue, 128);
	}

	return ret;
}

int VideoEncodeBindVideoIn(int channel, int groupId)
{
	// 绑定到视频输入
	MPP_CHN_S sourceChannel;
	sourceChannel.enModId   = HI_ID_VIU;
	sourceChannel.s32DevId  = 0;
	sourceChannel.s32ChnId  = 0;
	
	MPP_CHN_S destChannel;
	destChannel.enModId		= HI_ID_VENC;
	destChannel.s32DevId	= 0;
	destChannel.s32ChnId	= channel;
	
	if (groupId >= 0) {
		return HI_MPI_SYS_Bind(&sourceChannel, &destChannel);

	} else {
		return HI_MPI_SYS_UnBind(&sourceChannel, &destChannel);	
	}
}

/** 释放码流缓存。 */
int VideoEncodeReleaseStream(int channel, VideoSampleInfo* sampleInfo)
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
	return HI_MPI_VENC_RequestIDR(channel, TRUE); 
}

int VideoEncodeSetAttributes(int channel, VideoSettings* settings) 
{
	if (settings == NULL) {
		return -1;
	}

	// Channel attributes
	VENC_CHN_ATTR_S channelAttributes;
	memset(&channelAttributes, 0, sizeof(VENC_CHN_ATTR_S));

	// H.264 attributes
	VENC_ATTR_H264_S* h264Attributes = &(channelAttributes.stVeAttr.stAttrH264e);
	memset(h264Attributes, 0, sizeof(*h264Attributes));
	VideoEncodeInitAttributes(h264Attributes, settings);

	LOG_D("%d (%dx%d)\r\n", channel, settings->fVideoWidth, settings->fVideoHeight);
	channelAttributes.stVeAttr.enType = PT_H264;

	int ret = HI_MPI_VENC_SetChnAttr(channel, &channelAttributes);
	if (ret != HI_SUCCESS) {
		LOG_W("HI_MPI_VENC_SetChnAttr: 0x%x", ret)
	}

	return ret;
}

int VideoEncodeSetCrop(int groupId, int l, int t, int w, int h)
{
	return 0;
}

int VideoEncodeStart(int channel, int flags) 
{ 

	int ret = 0;
	if (flags > 0) {
		VENC_RECV_PIC_PARAM_S stRecvParam;
		stRecvParam.s32RecvPicNum = 1;
	    ret = HI_MPI_VENC_StartRecvPicEx(channel, &stRecvParam);

	} else {
		ret = HI_MPI_VENC_StartRecvPic(channel);
	}

	if (ret != HI_SUCCESS) {
		LOG_W("HI_MPI_VENC_StartRecvPic: 0x%x", ret)
	}
	return ret;
}

int VideoEncodeStop(int channel)
{
	int ret = HI_MPI_VENC_StopRecvPic(channel);
	if (ret != HI_SUCCESS) {
		LOG_W("HI_MPI_VENC_StopRecvPic: 0x%x", ret)
	}
	return ret;
}

