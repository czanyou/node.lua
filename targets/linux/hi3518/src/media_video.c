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

//_____________________________________________________________________________
///////////////////////////////////////////////////////////////////////////////
// Video Encode Channel Group

/** 绑定视频编码组到视频源, 绑定后编码组自动从视频源获取视频流. */
int VideoGroupBind(int groupId, int channel)
{
	MPP_CHN_S sourceChannel;
	if (groupId < 0) { // 绑定到 VPSS
		sourceChannel.enModId   = HI_ID_VPSS;
		sourceChannel.s32DevId  = 0;
		sourceChannel.s32ChnId  = groupId;
		
	} else { // 绑定到视频输入
		sourceChannel.enModId   = HI_ID_VIU;
		sourceChannel.s32DevId  = 0;
		sourceChannel.s32ChnId  = 0;
	}

	MPP_CHN_S destChannel;
	destChannel.enModId		= HI_ID_GROUP;
	destChannel.s32DevId	= groupId;
	destChannel.s32ChnId	= 0;

	int ret = HI_MPI_SYS_Bind(&sourceChannel, &destChannel);
	if (HI_SUCCESS != ret) {
		LOG_E("HI_MPI_SYS_Bind failed with #%x!\n", ret);
		return HI_FAILURE;
	}
	return HI_SUCCESS;
}

int VideoGroupClose(int groupId)
{
	return HI_MPI_VENC_DestroyGroup(groupId);
}

int VideoGroupOpen(int groupId)
{
	return HI_MPI_VENC_CreateGroup(groupId);
}

int VideoGroupSetCrop(int groupId, int l, int t, int w, int h)
{
	l = l & 0xfff0;
	t = t & 0xfff0;

	GROUP_CROP_CFG_S groupConfig;
	memset(&groupConfig, 0, sizeof(groupConfig));
	groupConfig.bEnable = HI_TRUE;
	groupConfig.stRect.s32X		= l;
	groupConfig.stRect.s32Y		= t;
	groupConfig.stRect.u32Width	= w;
	groupConfig.stRect.u32Height = h;

	int ret = HI_MPI_VENC_SetGrpCrop(groupId, &groupConfig);
	if (ret != 0) {
		LOG_W("HI_MPI_VENC_SetGrpCrop failed with %x\r\n", ret);
		return ret;
	}

	return 0;
}

int VideoGroupUnBind(int groupId)
{
	MPP_CHN_S sourceChannel;
	if (groupId < 0) {
		sourceChannel.enModId   = HI_ID_VPSS;
		sourceChannel.s32DevId  = 0;
		sourceChannel.s32ChnId  = groupId;

	} else {
		sourceChannel.enModId   = HI_ID_VIU;
		sourceChannel.s32DevId  = 0;
		sourceChannel.s32ChnId  = 0;
	}

	MPP_CHN_S destChannel;
	destChannel.enModId		= HI_ID_GROUP;
	destChannel.s32DevId	= groupId;
	destChannel.s32ChnId	= 0;

	int ret = HI_MPI_SYS_UnBind(&sourceChannel, &destChannel);
	if (HI_SUCCESS != ret) {
		LOG_E("HI_MPI_SYS_UnBind failed with %#x!\n", ret);
		return HI_FAILURE;
	}
	return HI_SUCCESS;
}

//_____________________________________________________________________________
///////////////////////////////////////////////////////////////////////////////
// Video Encode Channel

int VideoEncodeBind(int channel, int groupId)
{
	if (groupId >= 0) {
		VideoGroupBind(groupId, 0);
		return HI_MPI_VENC_RegisterChn(groupId, channel);

	} else {
		VideoGroupUnBind(channel);
		return HI_MPI_VENC_UnRegisterChn(channel);
	}
}

int VideoEncodeClose(int channel)
{
	HI_MPI_VENC_UnRegisterChn(channel);
	int ret = HI_MPI_VENC_DestroyChn(channel);
	
	VideoGroupClose(channel);
	return ret;
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

	int ret = HI_MPI_VENC_GetStream(channel, videoStream, HI_FALSE);
	UINT packetCount = videoStream->u32PackCount;
	if (packetCount <= 0) {
		return 0;
	}

	sampleInfo->fPrivateData = videoStream;

	UINT index = 0;
	UINT i = 0;
	for (i = 0; i < packetCount; i++) {
		VENC_PACK_S* packet = &videoStream->pstPack[i];
		if (packet->u32Len[0] > 0) {
			sampleInfo->fPacketSize[index] = packet->u32Len[0];
			sampleInfo->fPacketData[index] = packet->pu8Addr[0];
			index++;
		}

		if (packet->u32Len[1] > 0) {
			sampleInfo->fPacketSize[index] = packet->u32Len[1];
			sampleInfo->fPacketData[index] = packet->pu8Addr[1];
			index++;
		}

		if (index >= kVideoSampleMaxCount - 1) {
			break;
		}

		//printf("%d,%d, %d-%d (%d)\r\n", (int)packet->u32Len[0], (int)packet->u32Len[1],
		//	(int)packet->bFieldEnd, (int)packet->bFrameEnd, (int)packet->DataType.enH264EType);
	}

	sampleInfo->fPacketCount = index;
	sampleInfo->fSampleTime  = videoStream->pstPack[0].u64PTS / 1000;
	sampleInfo->fSequence	 = videoStream->u32Seq;

	return ret;
}

int VideoEncodeInitAttributes(VENC_ATTR_H264_S* attributes, VideoSettings* settings)
{
	if (attributes == NULL || settings == NULL) {
		return -1;
	}

	// video size
	UINT width  = settings->fVideoWidth;
	UINT height = settings->fVideoHeight;

	// attributes
	memset(attributes, 0, sizeof(*attributes));
	attributes->bByFrame		= HI_TRUE;
	attributes->bField			= HI_FALSE;
	attributes->bMainStream		= HI_TRUE;	/* support main stream only for hi3516, bMainStream = HI_TRUE */
	attributes->bVIField		= HI_FALSE;	/* the sign of the VI picture is field or frame. Invalidate for hi3516*/
	attributes->u32BufSize		= width * height * 2;
	attributes->u32MaxPicHeight	= height;
	attributes->u32MaxPicWidth	= width;
	attributes->u32PicHeight	= height;
	attributes->u32PicWidth		= width;
	attributes->u32Priority		= 0;
	attributes->u32Profile		= 0; /* 0: Baseline; 1:MP; 2:HP   ? */

	return 0;
}

int VideoEncodeOpenH264(int channel, VideoSettings* settings) 
{
	if (settings == NULL) {
		return -1;
	}

	// test only
	VPSS_GRP vpssGrp = 0;
	VPSS_CHN vpssChn = channel;
	VPSS_CHN_ATTR_S vpssChannelAttr;
	memset(&vpssChannelAttr, 0, sizeof(vpssChannelAttr));
	vpssChannelAttr.bFrameEn = HI_FALSE;
	vpssChannelAttr.bSpEn    = HI_TRUE;
	VideoProcessChannelEnable(vpssGrp, vpssChn, &vpssChannelAttr, HI_NULL, HI_NULL);

	// 创建一个新的编码通道
	VENC_CHN_ATTR_S channelAttributes;
	memset(&channelAttributes, 0, sizeof(VENC_CHN_ATTR_S));

	// H.264 attributes
	VENC_ATTR_H264_S* h264Attributes = &(channelAttributes.stVeAttr.stAttrH264e);
	VideoEncodeInitAttributes(h264Attributes, settings);

	channelAttributes.stVeAttr.enType = PT_H264;
	//LOG_D("VideoEncodeOpenH264: %d (%dx%d)\r\n", 
	//	channel, settings->fVideoWidth, settings->fVideoHeight);

	// Bitrate mode
	channelAttributes.stRcAttr.enRcMode = VENC_RC_MODE_H264VBR;
	VENC_ATTR_H264_VBR_S* stH264Vbr = &(channelAttributes.stRcAttr.stAttrH264Vbr);
	stH264Vbr->fr32TargetFrmRate = settings->fFrameRate;	/* target frame rate */
	stH264Vbr->u32Gop			= settings->fGopLength;
	stH264Vbr->u32MaxBitRate	= settings->fBitrate; // 1024 * 6 * 3;
	stH264Vbr->u32MaxQp			= 32;
	stH264Vbr->u32MinQp			= 16;
	stH264Vbr->u32StatTime		= 1;		/* stream rate statics time(s) */
	stH264Vbr->u32ViFrmRate		= HI_VIDEO_IN_FRAMERATE; /* input (vi) frame rate */

	// 
	int ret = HI_MPI_VENC_CreateChn(channel, &channelAttributes);
	if (ret != HI_SUCCESS) {
		LOG_E("HI_MPI_VENC_CreateChn failed with 0x%x\n", ret);
	}

	return channel;
}

int VideoEncodeOpenJpeg(int channel, VideoSettings* settings)
{
	if (settings == NULL) {
		return -1;
	}

	// video size
	UINT width  	= settings->fVideoWidth;
	UINT height 	= settings->fVideoHeight;

	// 创建一个 JPEG 抓拍通道
	VENC_CHN_ATTR_S channelAttributes;
	memset(&channelAttributes, 0 ,sizeof(VENC_CHN_ATTR_S));
	channelAttributes.stVeAttr.enType = PT_JPEG;
	VENC_ATTR_JPEG_S* jpegAttr = &(channelAttributes.stVeAttr.stAttrJpeg);
	jpegAttr->u32MaxPicWidth	= width;
	jpegAttr->u32MaxPicHeight= height;
	jpegAttr->u32PicWidth	= width;
	jpegAttr->u32PicHeight	= height;
	jpegAttr->u32BufSize	= width * height * 2;
	jpegAttr->bVIField		= HI_FALSE;	/*the sign of the VI picture is field or frame?*/
	jpegAttr->bByFrame		= HI_TRUE;	/*get stream mode is field mode  or frame mode*/
	jpegAttr->u32Priority	= 0;	/*channels precedence level*/

	//LOG_D("VideoEncodeOpenJpeg: %d (%dx%d)\r\n", 
	//	channel, settings->fVideoWidth, settings->fVideoHeight);

	int ret = HI_MPI_VENC_CreateChn(channel, &channelAttributes);
	if (ret != HI_SUCCESS) {
		LOG_W("HI_MPI_VENC_CreateChn failed with 0x%x\n", ret);
	}

	VENC_PARAM_JPEG_S stParamJpeg; 

	ret = HI_MPI_VENC_GetJpegParam(channel, &stParamJpeg); 
	if (HI_SUCCESS != ret) { 
		printf("HI_MPI_VENC_GetJpegParam failed with 0x%x\n", ret); 
		return HI_FAILURE; 
	} 

	stParamJpeg.u32Qfactor = 30;

	ret = HI_MPI_VENC_SetJpegParam(channel, &stParamJpeg); 
	if (HI_SUCCESS != ret) { 
		printf("HI_MPI_VENC_SetJpegParam failed with 0x%x\n", ret); 
		return HI_FAILURE; 
	} 

	return channel;
}

int VideoEncodeOpen(int channel, VideoSettings* settings) 
{
	if (settings == NULL) {
		return -1;
	}
	
	VideoGroupOpen(channel);
	// LOG_D("VideoEncodeOpen: %d (%dx%d)\r\n", channel, settings->fVideoWidth, settings->fVideoHeight);

	if (settings->fCodecFormat == 1) {
		return VideoEncodeOpenJpeg(channel, settings);

	} else {
		return VideoEncodeOpenH264(channel, settings);
	}
}

/** 释放码流缓存。 */
int VideoEncodeReleaseStream(int channel, VideoSampleInfo* sampleInfo)
{
	if (sampleInfo == NULL) {
		return 0;
	}

	VENC_STREAM_S* videoStream = (VENC_STREAM_S*)sampleInfo->fPrivateData;
	if (videoStream == NULL) {
		return 0;
	}

	HI_MPI_VENC_ReleaseStream(channel, videoStream);

	if (videoStream->pstPack) {
		free(videoStream->pstPack);
		videoStream->pstPack = NULL;
	}

	free(videoStream);
	videoStream = NULL;

	return 0;
}

int VideoEncodeRenewStream(int channel) 
{ 
	return HI_MPI_VENC_RequestIDR(channel); 
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

	//LOG_D("%d (%dx%d)\r\n", channel, settings->fVideoWidth, settings->fVideoHeight);
	channelAttributes.stVeAttr.enType = PT_H264;

	int ret = HI_MPI_VENC_SetChnAttr(channel, &channelAttributes);
	if (ret != HI_SUCCESS) {
		LOG_E("HI_MPI_VENC_SetChnAttr failed: 0x%x\n", ret);
	}
	return ret;
}

int VideoEncodeSetCrop(int channel, int l, int t, int w, int h)
{
	return VideoGroupSetCrop(channel, l, t, w, h);
}

int VideoEncodeStart(int channel, int flags) 
{ 
	return HI_MPI_VENC_StartRecvPic(channel); 
}

int VideoEncodeStop(int channel)
{
	return HI_MPI_VENC_StopRecvPic(channel);
}
