#include "media_video.h"
#include "media_comm.h"

//______________________________________________________________________________
////////////////////////////////////////////////////////////////////////////////
// Video Input

#define VIDEO_IN_DEVICE_ID 0

/** 关闭视频输入设备. */
int VideoInRelease() 
{
	VideoIspStop();

	return HI_MPI_VI_DisableDev(VIDEO_IN_DEVICE_ID);
}

/** 打开视频输入设备. */
int VideoInInit(UINT flags) 
{
	VideoIspInit();

	int deviceId = VIDEO_IN_DEVICE_ID;
	int ret = VideoInSetAttributes(deviceId);
	if (ret != HI_SUCCESS) {
		LOG_E("SetAttributes %d failed with 0x%x\n", deviceId, ret);
		return ret;
	}

	ret = HI_MPI_VI_EnableDev(deviceId);
	if (ret != HI_SUCCESS) {
		LOG_E("HI_MPI_VI_EnableDev %d failed with 0x%x\n", deviceId, ret);
		return ret;
	}

	VideoSensorIspRun();

	// --------------------------------------------------------
	// VPSS Group

	VPSS_GRP_ATTR_S attributes;
	attributes.u32MaxW		= HI_VIDEO_IN_WIDTH;
	attributes.u32MaxH		= HI_VIDEO_IN_HEIGHT;
	attributes.bDrEn		= HI_FALSE;
	attributes.bDbEn		= HI_FALSE;
	attributes.bIeEn		= HI_TRUE;
	attributes.bNrEn		= HI_TRUE;
	attributes.bHistEn		= HI_TRUE;
	attributes.enDieMode 	= VPSS_DIE_MODE_AUTO;
	attributes.enPixFmt		= PIXEL_FORMAT_YUV_SEMIPLANAR_422;

	// test only
	VPSS_GRP vpssGrp = 0;
	VideoProcessGroupStart(vpssGrp, &attributes);
	VideoProcessGroupBind();
	
	return ret;
}

/** 设置视频输入设备的属性. */
int VideoInSetAttributes(int deviceId) 
{
	// AR0130 DC 12bit 输入 720P@30fps
	VI_DEV_ATTR_S attributes;
	memset(&attributes, 0, sizeof(attributes));
	attributes.enIntfMode		= VI_MODE_DIGITAL_CAMERA;	// 接口模式
	attributes.enWorkMode		= VI_WORK_MODE_1Multiplex;	// 1、2、4 路工作模式
	attributes.au32CompMask[0]	= 0xFFF00000;				/* comp mask */
	attributes.au32CompMask[1]	= 0x0;						/* comp mask */
	attributes.enScanMode		= VI_SCAN_PROGRESSIVE;		// 逐行 or 隔行输入
	attributes.s32AdChnId[0]	= -1;
	attributes.s32AdChnId[1]	= -1;
	attributes.s32AdChnId[2]	= -1;
	attributes.s32AdChnId[3]	= -1;
	attributes.enDataSeq		= VI_INPUT_DATA_YUYV;		// 仅支持 YUV 格式
	attributes.enDataPath		= VI_PATH_ISP;				// 使用内部 ISP
	attributes.enInputDataType	= VI_DATA_TYPE_RGB;			// 输入数据类型

#if 1
	// 定义视频设备接收的 BT601 或 DC 时序的同步信息。
	VI_SYNC_CFG_S* syncConfig = &(attributes.stSynCfg);
	syncConfig->enVsync			= VI_VSYNC_PULSE;			// 表示垂直同步脉冲，即一个脉冲到来表示新的一场或一帧
	syncConfig->enVsyncNeg		= VI_VSYNC_NEG_HIGH;		// 则正脉冲表示垂直同步脉冲
	syncConfig->enHsync			= VI_HSYNC_VALID_SINGNAL;	// 表示数据有效信号
	syncConfig->enHsyncNeg		= VI_HSYNC_NEG_HIGH;		// 
	syncConfig->enVsyncValid	= VI_VSYNC_VALID_SINGAL;	// 
	syncConfig->enVsyncValidNeg	= VI_VSYNC_VALID_NEG_HIGH;	// 
#endif

#if 1
	// 
	VI_TIMING_BLANK_S* timingBlank = &syncConfig->stTimingBlank;
	timingBlank->u32HsyncHfb	= 0;	/* horizontal begin blank width */
	timingBlank->u32HsyncAct	= 1280; /* horizontal valid width */
	timingBlank->u32HsyncHbb	= 0;	/* horizontal end blank width */

	timingBlank->u32VsyncVfb	= 0;	/* frame or interleaved odd picture's vertical begin blanking height */
	timingBlank->u32VsyncVact	= 720;  /* frame or interleaved odd picture's vertical valid blanking width */
	timingBlank->u32VsyncVbb	= 0;

	timingBlank->u32VsyncVbfb	= 0;
	timingBlank->u32VsyncVbact	= 0;
	timingBlank->u32VsyncVbbb	= 0;
#endif

#if defined(HI3518_OV9712)
	attributes.au32CompMask[0]	= 0xFFC00000;				/* comp mask */

	syncConfig->enVsyncValid	= VI_VSYNC_NORM_PULSE;	// 
	syncConfig->enVsyncValidNeg	= VI_VSYNC_VALID_NEG_HIGH;

	timingBlank->u32HsyncHfb	= 408;	/* horizontal begin blank width */
	timingBlank->u32VsyncVfb	= 6;	/* frame or interleaved odd picture's vertical begin blanking height */
	timingBlank->u32VsyncVbb	= 6;
#endif

	return HI_MPI_VI_SetDevAttr(deviceId, &attributes);
}

//______________________________________________________________________________
////////////////////////////////////////////////////////////////////////////////
// Video Input Channel

/** 关闭视频输入通道. */
int VideoInClose(int channel) 
{
	return HI_MPI_VI_DisableChn(channel);
}

int VideoInGetFrameRate( int channel )
{
	VI_CHN_ATTR_S attributes;
	int ret = HI_MPI_VI_GetChnAttr(channel, &attributes);
	if (ret != HI_SUCCESS) {
		LOG_W("HI_MPI_VI_GetChnAttr failed with %#x!\n", ret);
		return 0;
	}

	return attributes.s32FrameRate;
}

/** 打开视频输入通道. */
int VideoInOpen( int channel, int width, int height, int flags ) 
{
	int ret = 0;

	SIZE_S caputeSize;
	caputeSize.u32Width	 = 1280;
	caputeSize.u32Height = 720;

	if (width > 0 && height > 0) {
		caputeSize.u32Width  = width;
		caputeSize.u32Height = height;
	}

	SIZE_S desSize;
	desSize.u32Width	= caputeSize.u32Width;
	desSize.u32Height   = caputeSize.u32Height;

	VI_CHN_ATTR_S attributes;

	/* step  5: config & start vicap dev */
	attributes.stCapRect.s32X		= 0;
	attributes.stCapRect.s32Y		= 0;
	attributes.stCapRect.u32Width	= caputeSize.u32Width;
	attributes.stCapRect.u32Height	= caputeSize.u32Height;
	attributes.enCapSel				= VI_CAPSEL_BOTH;

	/* to show scale. this is a mediaBuffer only, we want to show dist_size = D1 only */
	attributes.stDestSize.u32Width	= desSize.u32Width;
	attributes.stDestSize.u32Height	= desSize.u32Height;
	attributes.enPixFormat			= PIXEL_FORMAT_YUV_SEMIPLANAR_420; 
	attributes.bMirror				= HI_TRUE;
	attributes.bFlip				= HI_TRUE;
	attributes.bChromaResample		= HI_FALSE;
	attributes.s32SrcFrameRate		= HI_VIDEO_IN_FRAMERATE;
	attributes.s32FrameRate			= HI_VIDEO_IN_FRAMERATE;

	ret = HI_MPI_VI_SetChnAttr(channel, &attributes);
	if (ret != HI_SUCCESS) {
		LOG_W("HI_MPI_VI_SetChnAttr failed with %#x!\n", ret);
		HI_MPI_VI_ChnUnBind(channel);
		return HI_FAILURE;
	}

	ret = HI_MPI_VI_EnableChn(channel);
	if (ret != HI_SUCCESS) {
		LOG_W("HI_MPI_VI_EnableChn failed with %#x!\n", ret);
		HI_MPI_VI_ChnUnBind(channel);
		return HI_FAILURE;
	}

	/*LOG_D("Video %d.%d (%dx%d-%dx%d)\r\n", deviceId, channel, 
		stCapSize.u32Width, stCapSize.u32Height, 
		stDesSize.u32Width, stDesSize.u32Height);*/

	return HI_SUCCESS;
}

/** */
int VideoInSetFrameRate( int channel, UINT frameRate )
{
	VI_CHN_ATTR_S attributes;
	int ret = HI_MPI_VI_GetChnAttr(channel, &attributes);
	if (ret != HI_SUCCESS) {
		LOG_W("HI_MPI_VI_GetChnAttr failed with %#x!\n", ret);
		return HI_FAILURE;
	}

	if (frameRate > HI_VIDEO_IN_FRAMERATE) {
		frameRate = HI_VIDEO_IN_FRAMERATE;
	}

	attributes.s32SrcFrameRate	= HI_VIDEO_IN_FRAMERATE;
	attributes.s32FrameRate		= frameRate;

	ret = HI_MPI_VI_SetChnAttr(channel, &attributes);
	if (ret != HI_SUCCESS) {
		LOG_W("HI_MPI_VI_SetChnAttr failed with %#x!\n", ret);
		return HI_FAILURE;
	}

	return 0;
}
