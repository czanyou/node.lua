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
 
#include "media_comm.c"

//______________________________________________________________________________
////////////////////////////////////////////////////////////////////////////////
// Media System

/** Video buffer exit & MPI system exit */
int MediaSystemRelease() 
{
	HI_MPI_SYS_Exit();
	HI_MPI_VB_Exit();

	return HI_SUCCESS;
}

/** 初始化整个多媒体系统以及音频编解码缓存区. */
int MediaSystemInit(int flags)
{
	LogSetLevel(flags);
	
	HI_MPI_SYS_Exit();
	HI_MPI_VB_Exit();

	// Init video buffer 
	VB_CONF_S bufferConfig = { 0 };
	memset(&bufferConfig, 0, sizeof(bufferConfig));
	// BlkSize = Stride x Height x 1.5。

	// 目前MPP 系统内除公共缓存池外主要其他 MMZ 内存资源需求如下：
	// 创建一路 H.264 编码通道，需要 MMZ 空间为图像大小 x 4。
	// 创建一路 H.264 解码通道，需要 MMZ 空间为图像大小 x（参考帧数目+4）。
	// 创建一路 MJPEG 编码通道，需要 MMZ 空间约 200K 左右。
	// 创建一路 MJPEG 解码通道，需要 MMZ 空间为图像大小 x 3。
	// 其他如音频、MD、VPP 等模块也需要从 MMZ 中申请适当内存，总共约 5M 左右。
	// 16 M

	// 整个系统中可容纳的缓存池个数。建议配置成产品中视频编码和解码通道个数和的 2 倍。
	bufferConfig.u32MaxPoolCnt = 128; // 最大缓存池数量

	bufferConfig.astCommPool[0].u32BlkSize	= (UINT)(1920 * 1080 * 2); // 720p
	bufferConfig.astCommPool[0].u32BlkCnt	= 8;

	bufferConfig.astCommPool[1].u32BlkSize	= (UINT)(1280 * 720 * 2);	// 360p
	bufferConfig.astCommPool[1].u32BlkCnt	= 8;

	bufferConfig.astCommPool[2].u32BlkSize	= (UINT)(640 * 360 * 2);	// 180p
	bufferConfig.astCommPool[2].u32BlkCnt	= 8;

	// Config
	int ret = HI_MPI_VB_SetConf(&bufferConfig);
	if (ret != HI_SUCCESS) {
		return ret;
	}

	// Init
	ret = HI_MPI_VB_Init();
	if (ret != HI_SUCCESS) {
		return ret;
	}

	// MPP 系统配置
	MPP_SYS_CONF_S sysConfig = { 0 };

	// 整个系统中使用图像的跨度 (stride) 字节对齐数, 直接配置成 16 或者 64 即可。
	sysConfig.u32AlignWidth = HI_SYS_ALIGN_WIDTH; 
	
	// Config
	ret = HI_MPI_SYS_SetConf(&sysConfig);
	if (ret != HI_SUCCESS) {
		return ret;
	}

	// Init
	return HI_MPI_SYS_Init();
}

LPCSTR MediaSystemGetType() 
{ 
	return "hi3516a"; 
}

LPCSTR MediaSystemGetVersion()
{
	static MPP_VERSION_S versionInfo;
	memset(&versionInfo, 0, sizeof(versionInfo));
	HI_MPI_SYS_GetVersion(&versionInfo);

	return versionInfo.aVersion;
}

