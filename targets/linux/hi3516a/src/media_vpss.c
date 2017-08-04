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
// Video Process

int VideoProcessGroupBind(int vpssId, int videoInId)
{
	MPP_CHN_S sourceChannel;
	MPP_CHN_S destChannel;

	sourceChannel.enModId	= HI_ID_VIU;
	sourceChannel.s32DevId	= 0;
	sourceChannel.s32ChnId	= videoInId;

	destChannel.enModId		= HI_ID_VPSS;
	destChannel.s32DevId	= vpssId;
	destChannel.s32ChnId	= 0;

	return HI_MPI_SYS_Bind(&sourceChannel, &destChannel);
}

int VideoProcessGroupStart(int vpssGroup, int flags)
{
	if (vpssGroup < 0 || vpssGroup > VPSS_MAX_GRP_NUM) {
		LOG_D("VpssGrp%d is out of rang. \n", vpssGroup);
		return HI_FAILURE;
	}

	// VPSS Group
	VPSS_GRP_ATTR_S vpssGroupAttr;
	vpssGroupAttr.u32MaxW	= HI_VIDEO_IN_WIDTH;
	vpssGroupAttr.u32MaxH	= HI_VIDEO_IN_HEIGHT;
	vpssGroupAttr.bIeEn		= HI_FALSE;
	vpssGroupAttr.bNrEn		= HI_TRUE;
	vpssGroupAttr.bHistEn	= HI_FALSE;
	vpssGroupAttr.enDieMode = VPSS_DIE_MODE_NODIE;
	vpssGroupAttr.enPixFmt	= PIXEL_FORMAT_YUV_SEMIPLANAR_420;	

	int ret = HI_MPI_VPSS_CreateGrp(vpssGroup, &vpssGroupAttr);
	if (ret != HI_SUCCESS) {
		return ret;
	}

	/*** set vpss param ***/
	VPSS_GRP_PARAM_S vpssGroupParam;
	memset(&vpssGroupParam, 0, sizeof(vpssGroupParam));

	ret = HI_MPI_VPSS_GetGrpParam(vpssGroup, &vpssGroupParam);
	if (ret != HI_SUCCESS) {
		return ret;
	}

	//vpssGroupParam.u32MotionThresh = 0;

	ret = HI_MPI_VPSS_SetGrpParam(vpssGroup, &vpssGroupParam);
	if (ret != HI_SUCCESS) {
		return ret;
	}

	int channelCount = VPSS_MAX_PHY_CHN_NUM;
	int i = 0;

	//HI_MPI_VPSS_StopGrp(vpssGroup);

	for (i = 0; i < channelCount; i++) {
		int vpssChannel = i;
		ret = VideoProcessChannelOpen(vpssGroup, vpssChannel, flags);
		if (ret != 0) {
			LOG_W("VideoProcessChannelOpen: %x", ret);
		}
	}

	return HI_MPI_VPSS_StartGrp(vpssGroup);
}

int VideoProcessGroupStop(int vpssGroup)
{
	if (vpssGroup < 0 || vpssGroup > VPSS_MAX_GRP_NUM) {
		printf("VpssGrp%d is out of rang[0,%d]. \n", vpssGroup, VPSS_MAX_GRP_NUM);
		return HI_FAILURE;
	}

	int channelCount = VPSS_MAX_PHY_CHN_NUM;
	int i = 0;

	HI_MPI_VPSS_StopGrp(vpssGroup);
	for (i = 0; i < channelCount; i++) {
		int vpssChannel = i;
		VideoProcessChannelClose(vpssGroup, vpssChannel);
	}

	return HI_MPI_VPSS_DestroyGrp(vpssGroup);
}

int VideoProcessChannelOpen(VPSS_GRP vpssGroup, VPSS_CHN vpssChannel, int flags)
{
	int ret = 0;

	VPSS_EXT_CHN_ATTR_S *vpssExtChnAttr = NULL;

	if (vpssGroup < 0 || vpssGroup > VPSS_MAX_GRP_NUM) {
		LOG_W("VpssGrp%d is out of rang[0,%d]. \n", vpssGroup, VPSS_MAX_GRP_NUM);
		return HI_FAILURE;
	}

	if (vpssChannel < 0 || vpssChannel > VPSS_MAX_CHN_NUM) {
		LOG_W("VpssChn%d is out of rang[0,%d]. \n", vpssChannel, VPSS_MAX_CHN_NUM);
		return HI_FAILURE;
	}

	VPSS_CHN_ATTR_S vpssChannelAttr;
	memset(&vpssChannelAttr, 0, sizeof(vpssChannelAttr));
    vpssChannelAttr.bSpEn     	= HI_FALSE;
    vpssChannelAttr.bBorderEn 	= HI_FALSE;
    vpssChannelAttr.bMirror 	= HI_FALSE;
    vpssChannelAttr.bFlip 		= HI_FALSE;
    vpssChannelAttr.s32SrcFrameRate 		= -1;
    vpssChannelAttr.s32DstFrameRate 		= -1;
    vpssChannelAttr.stBorder.u32Color       = 0xff00;
    vpssChannelAttr.stBorder.u32LeftWidth   = 2;
    vpssChannelAttr.stBorder.u32RightWidth  = 2;
    vpssChannelAttr.stBorder.u32TopWidth    = 2;
    vpssChannelAttr.stBorder.u32BottomWidth = 2;

    if (flags & 0x010) { vpssChannelAttr.bMirror = HI_TRUE; }
    if (flags & 0x020) { vpssChannelAttr.bFlip   = HI_TRUE; }

	if (vpssChannel < VPSS_MAX_PHY_CHN_NUM) {
		ret = HI_MPI_VPSS_SetChnAttr(vpssGroup, vpssChannel, &vpssChannelAttr);

	} else if (vpssExtChnAttr) {
		ret = HI_MPI_VPSS_SetExtChnAttr(vpssGroup, vpssChannel, vpssExtChnAttr); 
	}

	if (ret != HI_SUCCESS) {
		LOG_W("HI_MPI_VPSS_SetChnAttr: %d 0x%x", vpssChannel, ret);
		//return ret;
	}  

	VPSS_CHN_MODE_S vpssChannelMode;
	memset(&vpssChannelMode, 0, sizeof(vpssChannelMode));
	vpssChannelMode.enChnMode 		= VPSS_CHN_MODE_USER;
	vpssChannelMode.enPixelFormat 	= PIXEL_FORMAT_YUV_SEMIPLANAR_420;
	vpssChannelMode.u32Width 		= HI_VIDEO_IN_WIDTH;
	vpssChannelMode.u32Height 		= HI_VIDEO_IN_HEIGHT;

	if (vpssChannel == VPSS_CHN1) {
		vpssChannelMode.u32Width 		= 1280;
		vpssChannelMode.u32Height 		= 720;

	} else  if (vpssChannel == VPSS_CHN2) {
		vpssChannelMode.u32Width 		= 640;
		vpssChannelMode.u32Height 		= 360;

	} else if (vpssChannel == VPSS_CHN3) {
		vpssChannelMode.u32Width 		= 1280;
		vpssChannelMode.u32Height 		= 720;
	} 

	if (vpssChannel < VPSS_MAX_PHY_CHN_NUM) {
		ret = HI_MPI_VPSS_SetChnMode(vpssGroup, vpssChannel, &vpssChannelMode);
		if (ret != HI_SUCCESS) {
			LOG_W("HI_MPI_VPSS_SetChnMode: %d 0x%x", vpssChannel, ret);
			return ret;
		}   
	}

	ret = HI_MPI_VPSS_EnableChn(vpssGroup, vpssChannel);
	if (ret != HI_SUCCESS) {
		LOG_W("HI_MPI_VPSS_EnableChn: %d 0x%x", vpssChannel, ret);
	}
	return ret;
}

int VideoProcessChannelClose(VPSS_GRP vpssGroup, VPSS_CHN vpssChannel)
{
	if (vpssGroup < 0 || vpssGroup > VPSS_MAX_GRP_NUM) {
		printf("vpssGroup%d is out of rang[0,%d]. \n", vpssGroup, VPSS_MAX_GRP_NUM);
		return HI_FAILURE;
	}

	if (vpssChannel < 0 || vpssChannel > VPSS_MAX_CHN_NUM) {
		printf("vpssChannel%d is out of rang[0,%d]. \n", vpssChannel, VPSS_MAX_CHN_NUM);
		return HI_FAILURE;
	}

	return HI_MPI_VPSS_DisableChn(vpssGroup, vpssChannel);
}

int VideoProcessOutputBind(VENC_GRP vencChannel, VPSS_GRP VpssGrp, VPSS_CHN VpssChn)
{
	MPP_CHN_S sourceChannel;
	MPP_CHN_S destChannel;

	sourceChannel.enModId	= HI_ID_VPSS;
	sourceChannel.s32DevId	= VpssGrp;
	sourceChannel.s32ChnId	= VpssChn;

	destChannel.enModId		= HI_ID_VENC;
	destChannel.s32DevId	= 0;
	destChannel.s32ChnId	= vencChannel;

	return HI_MPI_SYS_Bind(&sourceChannel, &destChannel);
}

int VideoEncodeBind(int channel, int groupId)
{
	//LOG_W("VideoEncodeBind: %d - %d", channel, groupId);
	return VideoProcessOutputBind(channel, groupId, channel);
}

int VideoProcessMemConfig()
{
	LPCSTR mmzName;
	MPP_CHN_S mppChannel;
	int ret, i;

	/*vpss group max is 64, not need config vpss chn.*/
	for (i = 0; i < 64; i++) {
		mppChannel.enModId  = HI_ID_VPSS;
		mppChannel.s32DevId = i;
		mppChannel.s32ChnId = 0;

		if (0 == (i % 2)) {
			mmzName = NULL;  

		} else {
			mmzName = "ddr1";
		}

		ret = HI_MPI_SYS_SetMemConf(&mppChannel, mmzName);
		if (HI_SUCCESS != ret) {
			return ret;
		}
	}

	return HI_SUCCESS;
}
