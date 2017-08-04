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
#ifndef _NS_VISION_HI_MEDIA_HI3518_H
#define _NS_VISION_HI_MEDIA_HI3518_H

#include "hi_type.h"
#include "hi_common.h"
#include "hi_comm_video.h"
#include "hi_comm_sys.h"
#include "hi_comm_vo.h"
#include "hi_comm_vi.h"
#include "hi_comm_aio.h"
#include "hi_comm_aenc.h"
#include "hi_comm_venc.h"
#include "hi_comm_vpss.h"
#include "hi_comm_aio.h"
#include "hi_comm_isp.h"
#include "hi_comm_region.h"
#include "hi_sns_ctrl.h"
#include "mpi_vb.h"
#include "mpi_sys.h"
#include "mpi_vi.h"
#include "mpi_vo.h"
#include "mpi_venc.h"
#include "mpi_ai.h"
#include "mpi_ao.h"
#include "mpi_aenc.h"
#include "mpi_adec.h"
#include "mpi_vpss.h"
#include "mpi_isp.h"
#include "mpi_region.h"

#include "base_types.h"

#define HI3518_OV9712 			1

#define NO_MOTION_DETECT		1
#define NO_VIDEO_DECODER		1
#define NO_VIDEO_OVERLAY

#define HI_SYS_ALIGN_WIDTH		64
#define HI_VIDEO_IN_WIDTH		1280
#define HI_VIDEO_IN_HEIGHT		720
#define HI_VIDEO_IN_FRAMERATE	25

int  VideoIspInit(void);
int  VideoIspStart(void);
int  VideoIspRun(void);
void VideoIspStop(void);
int  VideoInSetAttributes(int deviceId);


#endif // _NS_VISION_HI_MEDIA_HI3518_H
