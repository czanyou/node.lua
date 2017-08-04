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
 
//______________________________________________________________________________
////////////////////////////////////////////////////////////////////////////////
// 视频文字叠加 API

int VideoOverlayClose(int regionId)
{
	if (regionId < 0) {
		return -1;
	}

	return HI_MPI_RGN_Destroy(regionId);
}

int VideoOverlayOpen(int regionId, int width, int height)
{
	if (regionId < 0) {
		return -1;

	} else if (width <= 0 || height <= 0) {
		return -1;
	}

	///////////////////////////////////////////////////////////

	// Create region
	RGN_ATTR_S regionAttributes; 
	memset(&regionAttributes, 0, sizeof(regionAttributes));
	regionAttributes.enType = OVERLAY_RGN; 
	regionAttributes.unAttr.stOverlay.enPixelFmt = PIXEL_FORMAT_RGB_1555; 
	regionAttributes.unAttr.stOverlay.stSize.u32Width  = width; 
	regionAttributes.unAttr.stOverlay.stSize.u32Height = height; 
	regionAttributes.unAttr.stOverlay.u32BgColor = 0x00000fff; 

	int ret = HI_MPI_RGN_Create(regionId, &regionAttributes); 
	if (ret != HI_SUCCESS) { 
		return ret; 
	} 

	///////////////////////////////////////////////////////////

	// Attach & Settings
	MPP_CHN_S channelSettings;
	memset(&channelSettings, 0, sizeof(channelSettings));
	channelSettings.enModId		= HI_ID_GROUP;
	channelSettings.s32DevId	= regionId;
	channelSettings.s32ChnId	= 0;
	
	// channel attributes
	RGN_CHN_ATTR_S channelAttributes;
	memset(&channelAttributes, 0, sizeof(channelAttributes));
	channelAttributes.bShow	 	= HI_TRUE;
	channelAttributes.enType 	= OVERLAY_RGN;

	// overlay attributes
	OVERLAY_CHN_ATTR_S* overlayAttributes = &channelAttributes.unChnAttr.stOverlayChn;
	overlayAttributes->stPoint.s32X		= 0;
	overlayAttributes->stPoint.s32Y		= 16;
	overlayAttributes->u32BgAlpha		= 0;
	overlayAttributes->u32FgAlpha		= 128; // 0 ~ 128
	overlayAttributes->u32Layer			= 0;
	overlayAttributes->stQpInfo.bAbsQp	= HI_FALSE;
	overlayAttributes->stQpInfo.s32Qp	= 0;

	ret = HI_MPI_RGN_AttachToChn(regionId, &channelSettings, &channelAttributes);
	if (ret != HI_SUCCESS) {
		return ret;
	}

	return 0;
}

int VideoOverlaySetBitmap(int regionId, int width, int height, BYTE* bitmapData)
{
	if (regionId < 0) {
		return -1;

	} else if (width <= 0 || height <= 0 || bitmapData == NULL) {
		return -1;
	}

	BITMAP_S bitmapInfo;
	memset(&bitmapInfo, 0, sizeof(BITMAP_S));
	bitmapInfo.enPixelFormat	= PIXEL_FORMAT_RGB_1555;
	bitmapInfo.u32Width			= width;
	bitmapInfo.u32Height		= height;
	bitmapInfo.pData			= bitmapData;

	int ret = HI_MPI_RGN_SetBitMap(regionId, &bitmapInfo); 
	if (ret != HI_SUCCESS) {
		return ret;
	}

	return 0;
}
