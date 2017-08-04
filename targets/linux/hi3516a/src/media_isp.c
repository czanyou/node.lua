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

////////////////////////////////////////////////////////////////////////////////
// Video ISP

#define ISP_DEVICE_0 0

static pthread_t sIspThreadId = 0;

int VideoIspInit(void)
{
	/* sensor register callback */
	int ret = sensor_register_callback();
    if (ret != HI_SUCCESS) {
        return ret;
    }

    return VideoIspStart();
}

void* VideoIspRunThead(void *param)
{
    // LOG_D("VideoIspRunThead\n");
    HI_MPI_ISP_Run(ISP_DEVICE_0);
    return HI_NULL;
}

int VideoIspRun()
{
	if (sIspThreadId != 0) {
		return -1;
	}

	int ret = pthread_create(&sIspThreadId, 0, (void* (*)(void*))VideoIspRunThead, NULL);
	if (ret != 0) {
		LOG_E("Create isp running thread failed!\n");
		return HI_FAILURE;
	}

	return HI_SUCCESS;
}

int VideoIspStart(void)
{
    ISP_DEV IspDev = 0;
    HI_S32 ret;
    ISP_PUB_ATTR_S stPubAttr;
    ALG_LIB_S stLib;


    /* 1. sensor register callback */
    ret = sensor_register_callback();
    if (ret != HI_SUCCESS) {
        return ret;
    }

    /* 2. register hisi ae lib */
    stLib.s32Id = 0;
    strcpy(stLib.acLibName, HI_AE_LIB_NAME);
    ret = HI_MPI_AE_Register(IspDev, &stLib);
    if (ret != HI_SUCCESS) {
        return ret;
    }

    /* 3. register hisi awb lib */
    stLib.s32Id = 0;
    strcpy(stLib.acLibName, HI_AWB_LIB_NAME);
    ret = HI_MPI_AWB_Register(IspDev, &stLib);
    if (ret != HI_SUCCESS) {
        return ret;
    }

    /* 4. register hisi af lib */
    stLib.s32Id = 0;
    strcpy(stLib.acLibName, HI_AF_LIB_NAME);
    ret = HI_MPI_AF_Register(IspDev, &stLib);
    if (ret != HI_SUCCESS) {
        return ret;
    }

    /* 5. isp mem init */
    ret = HI_MPI_ISP_MemInit(IspDev);
    if (ret != HI_SUCCESS) {
        return ret;
    }

    /* 6. isp set WDR mode */
    ISP_WDR_MODE_S stWdrMode;
    stWdrMode.enWDRMode  = WDR_MODE_NONE;
    ret = HI_MPI_ISP_SetWDRMode(0, &stWdrMode);    
    if (ret != HI_SUCCESS) {
        return ret;
    }

    stPubAttr.enBayer               = BAYER_GBRG;
    stPubAttr.f32FrameRate          = 30;
    stPubAttr.stWndRect.s32X        = 0;
    stPubAttr.stWndRect.s32Y        = 0;
    stPubAttr.stWndRect.u32Width    = 1920;
    stPubAttr.stWndRect.u32Height   = 1080;

    ret = HI_MPI_ISP_SetPubAttr(IspDev, &stPubAttr);
    if (ret != HI_SUCCESS) {
        return ret;
    }

    /* 8. isp init */
    return HI_MPI_ISP_Init(IspDev);
}

int VideoIspStop()
{
	if (sIspThreadId) {
		HI_MPI_ISP_Exit(ISP_DEVICE_0);
		pthread_join(sIspThreadId, 0);
		sIspThreadId = 0;
	}

    return 0;
}
