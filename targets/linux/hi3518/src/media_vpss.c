#include "media_video.h"
#include "media_comm.h"

//_____________________________________________________________________________
///////////////////////////////////////////////////////////////////////////////
// Video Process

int VideoProcessGroupBind()
{
	HI_S32 j, ret;
	MPP_CHN_S sourceChannel;
	MPP_CHN_S destChannel;

	int videoChannelCount	= 1;
	VPSS_GRP vpssGroup = 0;

	for (j = 0; j < videoChannelCount; j++) {
		sourceChannel.enModId	= HI_ID_VIU;
		sourceChannel.s32DevId	= 0;
		sourceChannel.s32ChnId	= j;

		destChannel.enModId		= HI_ID_VPSS;
		destChannel.s32DevId	= vpssGroup;
		destChannel.s32ChnId	= 0;

		ret = HI_MPI_SYS_Bind(&sourceChannel, &destChannel);
		if (ret != HI_SUCCESS) {
			LOG_D("failed with %#x!\n", ret);
			return HI_FAILURE;
		}

		vpssGroup++;
	}

	return HI_SUCCESS;
}

int VideoProcessGroupStart(VPSS_GRP vpssGroup, VPSS_GRP_ATTR_S *groupAttributes)
{
	if (vpssGroup < 0 || vpssGroup > VPSS_MAX_GRP_NUM) {
		LOG_D("VpssGrp%d is out of rang. \n", vpssGroup);
		return HI_FAILURE;
	}

	if (HI_NULL == groupAttributes) {
		LOG_D("null ptr, line.\n");
		return HI_FAILURE;
	}

	int ret = HI_MPI_VPSS_CreateGrp(vpssGroup, groupAttributes);
	if (ret != HI_SUCCESS) {
		LOG_E("HI_MPI_VPSS_CreateGrp failed with %#x!\n", ret);
		return HI_FAILURE;
	}

	/*** set vpss param ***/
	VPSS_GRP_PARAM_S vpssGroupParam;
	memset(&vpssGroupParam, 0, sizeof(vpssGroupParam));

	ret = HI_MPI_VPSS_GetGrpParam(vpssGroup, &vpssGroupParam);
	if (ret != HI_SUCCESS) {
		LOG_E("failed with %#x!\n", ret);
		return HI_FAILURE;
	}

	vpssGroupParam.u32MotionThresh = 0;

	ret = HI_MPI_VPSS_SetGrpParam(vpssGroup, &vpssGroupParam);
	if (ret != HI_SUCCESS) {
		LOG_E("failed with %#x!\n", ret);
		return HI_FAILURE;
	}

	ret = HI_MPI_VPSS_StartGrp(vpssGroup);
	if (ret != HI_SUCCESS) {
		LOG_E("HI_MPI_VPSS_StartGrp failed with %#x\n", ret);
		return HI_FAILURE;
	}

	return HI_SUCCESS;
}

int VideoProcessGroupStop(VPSS_GRP vpssGroup)
{
	if (vpssGroup < 0 || vpssGroup > VPSS_MAX_GRP_NUM) {
		printf("VpssGrp%d is out of rang[0,%d]. \n", vpssGroup, VPSS_MAX_GRP_NUM);
		return HI_FAILURE;
	}

	int ret = HI_MPI_VPSS_StopGrp(vpssGroup);
	if (ret != HI_SUCCESS) {
		LOG_E("HI_MPI_VPSS_StopGrp failed with %#x\n", ret);
		return HI_FAILURE;
	}

	ret = HI_MPI_VPSS_DestroyGrp(vpssGroup);
	if (ret != HI_SUCCESS) {
		LOG_E("HI_MPI_VPSS_DestroyGrp failed with %#x\n", ret);
		return HI_FAILURE;
	}

	return HI_SUCCESS;
}

int VideoProcessChannelEnable(VPSS_GRP vpssGrp, VPSS_CHN vpssChn, 
							  VPSS_CHN_ATTR_S *vpssChnAttr,
							  VPSS_CHN_MODE_S *vpssChnMode,
							  VPSS_EXT_CHN_ATTR_S *vpssExtChnAttr)
{
	int ret;

	if (vpssGrp < 0 || vpssGrp > VPSS_MAX_GRP_NUM) {
		LOG_D("VpssGrp%d is out of rang[0,%d]. \n", vpssGrp, VPSS_MAX_GRP_NUM);
		return HI_FAILURE;
	}

	if (vpssChn < 0 || vpssChn > VPSS_MAX_CHN_NUM) {
		LOG_D("VpssChn%d is out of rang[0,%d]. \n", vpssChn, VPSS_MAX_CHN_NUM);
		return HI_FAILURE;
	}

	if (HI_NULL == vpssChnAttr && HI_NULL == vpssExtChnAttr) {
		LOG_D("null ptr.\n");
		return HI_FAILURE;
	}

	if (vpssChn < VPSS_MAX_PHY_CHN_NUM) {
		ret = HI_MPI_VPSS_SetChnAttr(vpssGrp, vpssChn, vpssChnAttr);
		if (ret != HI_SUCCESS) {
			LOG_E("HI_MPI_VPSS_SetChnAttr failed with %#x\n", ret);
			return HI_FAILURE;
		}

	} else if (vpssExtChnAttr) {
		ret = HI_MPI_VPSS_SetExtChnAttr(vpssGrp, vpssChn, vpssExtChnAttr);
		if (ret != HI_SUCCESS) {
			LOG_E("HI_MPI_VPSS_SetExtChnAttr failed with %#x\n", ret);
			return HI_FAILURE;
		}
	}

	if (vpssChn < VPSS_MAX_PHY_CHN_NUM && vpssChnMode) {
		ret = HI_MPI_VPSS_SetChnMode(vpssGrp, vpssChn, vpssChnMode);
		if (ret != HI_SUCCESS) {
			LOG_E("HI_MPI_VPSS_SetChnMode failed with %#x\n", ret);
			return HI_FAILURE;
		}     
	}

	ret = HI_MPI_VPSS_EnableChn(vpssGrp, vpssChn);
	if (ret != HI_SUCCESS) {
		LOG_E("HI_MPI_VPSS_EnableChn failed with %#x\n", ret);
		return HI_FAILURE;
	}

	return HI_SUCCESS;
}

int VideoProcessChannelDisable(VPSS_GRP vpssGroup, VPSS_CHN vpssChannel)
{
	int ret;

	if (vpssGroup < 0 || vpssGroup > VPSS_MAX_GRP_NUM) {
		printf("VpssGrp%d is out of rang[0,%d]. \n", vpssGroup, VPSS_MAX_GRP_NUM);
		return HI_FAILURE;
	}

	if (vpssChannel < 0 || vpssChannel > VPSS_MAX_CHN_NUM) {
		printf("VpssChn%d is out of rang[0,%d]. \n", vpssChannel, VPSS_MAX_CHN_NUM);
		return HI_FAILURE;
	}

	ret = HI_MPI_VPSS_DisableChn(vpssGroup, vpssChannel);
	if (ret != HI_SUCCESS) {
		LOG_E("HI_MPI_VPSS_DisableChn failed with %#x\n", ret);
		return HI_FAILURE;
	}

	return HI_SUCCESS;
}

int VideoProcessOutputBind(VENC_GRP GrpChn, VPSS_GRP VpssGrp, VPSS_CHN VpssChn)
{
	MPP_CHN_S sourceChannel;
	MPP_CHN_S destChannel;

	sourceChannel.enModId	= HI_ID_VPSS;
	sourceChannel.s32DevId	= VpssGrp;
	sourceChannel.s32ChnId	= VpssChn;

	destChannel.enModId		= HI_ID_GROUP;
	destChannel.s32DevId	= GrpChn;
	destChannel.s32ChnId	= 0;

	int ret = HI_MPI_SYS_Bind(&sourceChannel, &destChannel);
	if (ret != HI_SUCCESS) {
		LOG_D("Failed with %#x!\n", ret);
		return HI_FAILURE;
	}

	return ret;
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
			LOG_E("Vpss HI_MPI_SYS_SetMemConf ERR !\n");
			return HI_FAILURE;
		}
	}

	return HI_SUCCESS;
}
