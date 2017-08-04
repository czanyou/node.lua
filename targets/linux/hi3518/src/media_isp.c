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

static struct VI_CONFIG_S* sSensorConfig = NULL;
static pthread_t sSensorThreadId = 0;

int VideoIspInit(void)
{
	/* 1. sensor init */
	sensor_init();

	/* 0: linear mode, 1: WDR mode */
	sensor_mode_set(0);

	/* 2. sensor register callback */
	int ret = sensor_register_callback();
	if (ret != HI_SUCCESS) {
		LOG_E("sensor_register_callback failed with %#x!\n", ret);
		return ret;
	}

	return HI_SUCCESS;
}

int VideoSensorIspRun()
{
	if (sSensorThreadId != 0) {
		return -1;
	}

	int ret = VideoIspStart();
	if (HI_SUCCESS != ret) {
		LOG_E("ISP Start failed!\n");
		return HI_FAILURE;
	}

	ret = pthread_create(&sSensorThreadId, 0, (void* (*)(void*))HI_MPI_ISP_Run, NULL);
	if (ret != 0) {
		LOG_E("Create ISP running thread failed!\n");
		return HI_FAILURE;
	}

	return HI_SUCCESS;
}

int VideoIspStart(void)
{
    // --------------------------------------------------------
    /* 1. isp init */
    int ret = HI_MPI_ISP_Init();
    if (ret != HI_SUCCESS) {
        LOG_E("HI_MPI_ISP_Init failed!\n");
        return ret;
    }

    // --------------------------------------------------------
    /* 2. isp set image attributes */
    /* note : different sensor, different ISP_IMAGE_ATTR_S define.
              if the sensor you used is different, you can change 
              ISP_IMAGE_ATTR_S definition */

	ISP_IMAGE_ATTR_S imageAttributes;

#if defined(HI3518_AR0130)
	imageAttributes.enBayer			= BAYER_GRBG;

#elif defined(HI3518_OV9712)
	imageAttributes.enBayer			= BAYER_BGGR;

#elif defined(HI3518_IMX138)
	imageAttributes.enBayer			= BAYER_GBRG;
#endif

	imageAttributes.u16FrameRate    = HI_VIDEO_IN_FRAMERATE;
	imageAttributes.u16Width        = HI_VIDEO_IN_WIDTH;
	imageAttributes.u16Height       = HI_VIDEO_IN_HEIGHT;

    ret = HI_MPI_ISP_SetImageAttr(&imageAttributes);
    if (ret != HI_SUCCESS) {
        LOG_E("HI_MPI_ISP_SetImageAttr failed with %#x!\n", ret);
        return ret;
    }

    // --------------------------------------------------------
    /* 3. isp set timing */

	ISP_INPUT_TIMING_S inputTiming;
#ifdef HI3518_AR0130
    inputTiming.enWndMode			= ISP_WIND_NONE;

#elif defined(HI3518_OV9712)
	inputTiming.enWndMode			= ISP_WIND_NONE;

#elif defined(HI3518_IMX138)
	inputTiming.enWndMode			= ISP_WIND_ALL;
	inputTiming.u16HorWndStart		= 68;
	inputTiming.u16HorWndLength		= 1280;
	inputTiming.u16VerWndStart		= 40;
	inputTiming.u16VerWndLength		= 720;
#endif

	ret = HI_MPI_ISP_SetInputTiming(&inputTiming);    
    if (ret != HI_SUCCESS) {
        LOG_E("HI_MPI_ISP_SetInputTiming failed with %#x!\n", ret);
        return ret;
    }

    // --------------------------------------------------------
	// 4. AE

	ISP_AE_ATTR_S attributes;
	memset(&attributes, 0, sizeof(attributes));
	ret = HI_MPI_ISP_GetAEAttr(&attributes);
	if (ret != HI_SUCCESS) {
		LOG_E("HI_MPI_ISP_GetAEAttr failed with %#x!\n", ret);
	}

	// 1, (65535,2), (1,1), (31,1), (16,10,128)
	LOG_D("%d, (%d,%d), (%d,%d), (%d,%d), (%d,%d,%d)", attributes.enAEMode, 
		attributes.u16ExpTimeMax, attributes.u16ExpTimeMin, 
		attributes.u16DGainMax, attributes.u16DGainMin, 
		attributes.u16AGainMax, attributes.u16AGainMin, 
		attributes.u8ExpStep, attributes.s16ExpTolerance, attributes.u8ExpCompensation);
	
	attributes.enAEMode = AE_MODE_LOW_NOISE;
	//attributes.u16AGainMax = 8;
	//attributes.s16ExpTolerance = 16;
	//attributes.u8ExpCompensation = 64;

	ret = HI_MPI_ISP_SetAEAttr(&attributes);
	if (ret != HI_SUCCESS) {
		LOG_E("HI_MPI_ISP_SetAEAttr failed with %#x!\n", ret);
	}

	return 0;
}

void VideoIspStop()
{
	if (sSensorThreadId) {
		HI_MPI_ISP_Exit();
		pthread_join(sSensorThreadId, 0);
		sSensorThreadId = 0;
	}
}
