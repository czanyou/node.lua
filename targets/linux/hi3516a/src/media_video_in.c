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

#include "hi_mipi.h"

//______________________________________________________________________________
////////////////////////////////////////////////////////////////////////////////
// Video Input

#define VIDEO_INPUT_0 0

combo_dev_attr_t LVDS_4LANE_IMX178_12BIT_1080p =
{
    /* input mode */
    .input_mode = INPUT_MODE_LVDS,
    {

    .lvds_attr = {
        .img_size = { 1920, 1080 },
        HI_WDR_MODE_NONE, 	// wdr_mode
        LVDS_SYNC_MODE_SAV, // sync_mode
        RAW_DATA_12BIT, 	// raw_data_type
        LVDS_ENDIAN_BIG,	// data_endian
        LVDS_ENDIAN_BIG,	// sync_code_endian
        .lane_id = { 0, 1, 2, 3, -1, -1, -1, -1 }, 
        .sync_code = { 
            {{0xab0, 0xb60, 0x800, 0x9d0}, 
             {0xab0, 0xb60, 0x800, 0x9d0}, 
             {0xab0, 0xb60, 0x800, 0x9d0}, 
             {0xab0, 0xb60, 0x800, 0x9d0}},
            
            {{0xab0, 0xb60, 0x800, 0x9d0}, 
             {0xab0, 0xb60, 0x800, 0x9d0}, 
             {0xab0, 0xb60, 0x800, 0x9d0}, 
             {0xab0, 0xb60, 0x800, 0x9d0}},

            {{0xab0, 0xb60, 0x800, 0x9d0}, 
             {0xab0, 0xb60, 0x800, 0x9d0}, 
             {0xab0, 0xb60, 0x800, 0x9d0}, 
             {0xab0, 0xb60, 0x800, 0x9d0}},
            
            {{0xab0, 0xb60, 0x800, 0x9d0}, 
             {0xab0, 0xb60, 0x800, 0x9d0}, 
             {0xab0, 0xb60, 0x800, 0x9d0}, 
             {0xab0, 0xb60, 0x800, 0x9d0}},
            
            {{0xab0, 0xb60, 0x800, 0x9d0}, 
             {0xab0, 0xb60, 0x800, 0x9d0}, 
             {0xab0, 0xb60, 0x800, 0x9d0}, 
             {0xab0, 0xb60, 0x800, 0x9d0}},
                
            {{0xab0, 0xb60, 0x800, 0x9d0}, 
             {0xab0, 0xb60, 0x800, 0x9d0}, 
             {0xab0, 0xb60, 0x800, 0x9d0}, 
             {0xab0, 0xb60, 0x800, 0x9d0}},
 
            {{0xab0, 0xb60, 0x800, 0x9d0}, 
             {0xab0, 0xb60, 0x800, 0x9d0}, 
             {0xab0, 0xb60, 0x800, 0x9d0}, 
             {0xab0, 0xb60, 0x800, 0x9d0}},
            
            {{0xab0, 0xb60, 0x800, 0x9d0}, 
             {0xab0, 0xb60, 0x800, 0x9d0}, 
             {0xab0, 0xb60, 0x800, 0x9d0}, 
             {0xab0, 0xb60, 0x800, 0x9d0}} 

        } // end sync_code
    } // end lvds_attr 

    }
};

/** 关闭视频输入设备. */
int VideoInRelease() 
{
	VideoIspStop();

	return HI_MPI_VI_DisableDev(VIDEO_INPUT_0);
}

/** 初始化 MIPI/LVDS 视频输入接口. */
int VideoInStartMIPI()
{
    combo_dev_attr_t *attributes = &LVDS_4LANE_IMX178_12BIT_1080p;

    /* mipi reset unrest */
    int fd = open("/dev/hi_mipi", O_RDWR);
    if (fd < 0) {
        printf("warning: open `/dev/hi_mipi` device failed\n");
        return -1;
    }

	if (ioctl(fd, HI_MIPI_SET_DEV_ATTR, attributes)) {
        printf("set mipi attr failed\n");
        close(fd);
        return -1;
    }

    close(fd);
    return HI_SUCCESS;
}

/** 打开视频输入设备. */
int VideoInInit(HI_U32 flags) 
{
	VideoInStartMIPI();
	VideoIspInit();

	int videoInId = VIDEO_INPUT_0;
	int ret = VideoInSetAttributes(videoInId);
	if (ret != HI_SUCCESS) {
		return ret;
	}

	ret = HI_MPI_VI_EnableDev(videoInId);
	if (ret != HI_SUCCESS) {
		return ret;
	}

	VideoIspRun();

	return ret;
}

/** 设置视频输入设备的属性. */
int VideoInSetAttributes(int deviceId) 
{
	VI_DEV_ATTR_S attributes;
	memset(&attributes, 0, sizeof(attributes));
	attributes.enIntfMode		= VI_MODE_LVDS;				// 接口模式
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
	attributes.bDataRev			= HI_FALSE;

	// SONY_IMX178_LVDS_1080P_30FPS
    attributes.stDevRect.s32X 		= 0;
    attributes.stDevRect.s32Y 		= 20;
    attributes.stDevRect.u32Width  	= 1920;
    attributes.stDevRect.u32Height 	= 1080;
	
#if 1
	// 定义视频设备接收时序的同步信息。
	VI_SYNC_CFG_S* syncConfig = &(attributes.stSynCfg);
	syncConfig->enVsync			= VI_VSYNC_PULSE;			// 表示垂直同步脉冲，即一个脉冲到来表示新的一场或一帧
	syncConfig->enVsyncNeg		= VI_VSYNC_NEG_LOW;			// 则正脉冲表示垂直同步脉冲
	syncConfig->enHsync			= VI_HSYNC_VALID_SINGNAL;	// 表示数据有效信号
	syncConfig->enHsyncNeg		= VI_HSYNC_NEG_HIGH;		// 
	syncConfig->enVsyncValid	= VI_VSYNC_VALID_SINGAL;	// 
	syncConfig->enVsyncValidNeg	= VI_VSYNC_VALID_NEG_HIGH;	// 

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
		return 0;
	}

	return attributes.s32DstFrameRate;
}

/** 打开视频输入通道. */
int VideoInOpen( int channel, int width, int height, int flags ) 
{
	int ret = 0;

    // caputeSize
	SIZE_S caputeSize;
	caputeSize.u32Width	 = 1920;
	caputeSize.u32Height = 1080;

	if (width > 0 && height > 0) {
		caputeSize.u32Width  = width;
		caputeSize.u32Height = height;
	}

	//LOG_W("%dx%d, 0x%x", width, height, flags);
	
	// destSize
	SIZE_S destSize;
	destSize.u32Width	 = caputeSize.u32Width;
	destSize.u32Height   = caputeSize.u32Height;
	
	// attributes
	VI_CHN_ATTR_S attributes;
	memset(&attributes, 0, sizeof(attributes));
	attributes.enCapSel  = VI_CAPSEL_BOTH;

	attributes.stCapRect.s32X		= 0;
	attributes.stCapRect.s32Y		= 0;
	attributes.stCapRect.u32Width	= caputeSize.u32Width;
	attributes.stCapRect.u32Height	= caputeSize.u32Height;

	attributes.stDestSize.u32Width	= destSize.u32Width;
	attributes.stDestSize.u32Height	= destSize.u32Height;
	attributes.enPixFormat			= PIXEL_FORMAT_YUV_SEMIPLANAR_420; 

	attributes.bMirror				= HI_FALSE;
	attributes.bFlip				= HI_FALSE;

	attributes.s32SrcFrameRate		= -1;
	attributes.s32DstFrameRate		= -1;
	attributes.enCompressMode 		= COMPRESS_MODE_NONE;

	/* Enable video input channel */
	ret = HI_MPI_VI_SetChnAttr(channel, &attributes);
	if (ret != HI_SUCCESS) {
		LOG_W("HI_MPI_VI_SetChnAttr: 0x%x", ret)
		return ret;
	}

	ret = HI_MPI_VI_EnableChn(channel);
	if (ret != HI_SUCCESS) {
		LOG_W("HI_MPI_VI_EnableChn: 0x%x", ret)
		return ret;
	}

	int vpssId = 0;
	ret = VideoProcessGroupStart(vpssId, flags);
	if (ret != 0) {
		LOG_W("VideoProcessGroupStart: %x", ret);
		return ret;
	}
	
	ret = VideoProcessGroupBind(vpssId, channel);
	if (ret != 0) {
		LOG_W("VideoProcessGroupStart: %x", ret);
		return ret;
	}

	return ret;
}

/** */
int VideoInSetFrameRate( int channel, HI_U32 frameRate )
{
	VI_CHN_ATTR_S attributes;
	int ret = HI_MPI_VI_GetChnAttr(channel, &attributes);
	if (ret != HI_SUCCESS) {
		return ret;
	}

	if (frameRate > HI_VIDEO_IN_FRAMERATE) {
		frameRate = HI_VIDEO_IN_FRAMERATE;
	}

	attributes.s32SrcFrameRate	= HI_VIDEO_IN_FRAMERATE;
	attributes.s32DstFrameRate	= frameRate;

	return HI_MPI_VI_SetChnAttr(channel, &attributes);
}
