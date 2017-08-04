/******************************************************************************

  Copyright (C), 2001-2011, Hisilicon Tech. Co., Ltd.

 ******************************************************************************
  File Name     : hi_comm_vpss.h
  Version       : Initial Draft
  Author        : Hisilicon multimedia software group
  Created       : 
  Last Modified :
  Description   : common struct definition for vpss
  Function List :
  History       :
  1.Date        : 20130508
    Author      : l00183122
    Modification: Create
  
 
******************************************************************************/

#ifndef __HI_COMM_VPSS_H__
#define __HI_COMM_VPSS_H__


#ifdef __cplusplus
#if __cplusplus
extern "C"{
#endif
#endif /* __cplusplus */

#include "hi_type.h"
#include "hi_common.h"
#include "hi_errno.h"
#include "hi_comm_video.h"

#define HI_ERR_VPSS_NULL_PTR        HI_DEF_ERR(HI_ID_VPSS, EN_ERR_LEVEL_ERROR, EN_ERR_NULL_PTR)
#define HI_ERR_VPSS_NOTREADY        HI_DEF_ERR(HI_ID_VPSS, EN_ERR_LEVEL_ERROR, EN_ERR_SYS_NOTREADY)
#define HI_ERR_VPSS_INVALID_DEVID   HI_DEF_ERR(HI_ID_VPSS, EN_ERR_LEVEL_ERROR, EN_ERR_INVALID_DEVID)
#define HI_ERR_VPSS_INVALID_CHNID   HI_DEF_ERR(HI_ID_VPSS, EN_ERR_LEVEL_ERROR, EN_ERR_INVALID_CHNID)
#define HI_ERR_VPSS_EXIST           HI_DEF_ERR(HI_ID_VPSS, EN_ERR_LEVEL_ERROR, EN_ERR_EXIST)
#define HI_ERR_VPSS_UNEXIST         HI_DEF_ERR(HI_ID_VPSS, EN_ERR_LEVEL_ERROR, EN_ERR_UNEXIST)
#define HI_ERR_VPSS_NOT_SUPPORT     HI_DEF_ERR(HI_ID_VPSS, EN_ERR_LEVEL_ERROR, EN_ERR_NOT_SUPPORT)
#define HI_ERR_VPSS_NOT_PERM        HI_DEF_ERR(HI_ID_VPSS, EN_ERR_LEVEL_ERROR, EN_ERR_NOT_PERM)
#define HI_ERR_VPSS_NOMEM           HI_DEF_ERR(HI_ID_VPSS, EN_ERR_LEVEL_ERROR, EN_ERR_NOMEM)
#define HI_ERR_VPSS_NOBUF           HI_DEF_ERR(HI_ID_VPSS, EN_ERR_LEVEL_ERROR, EN_ERR_NOBUF)
#define HI_ERR_VPSS_ILLEGAL_PARAM   HI_DEF_ERR(HI_ID_VPSS, EN_ERR_LEVEL_ERROR, EN_ERR_ILLEGAL_PARAM)
#define HI_ERR_VPSS_BUSY            HI_DEF_ERR(HI_ID_VPSS, EN_ERR_LEVEL_ERROR, EN_ERR_BUSY)
#define HI_ERR_VPSS_BUF_EMPTY       HI_DEF_ERR(HI_ID_VPSS, EN_ERR_LEVEL_ERROR, EN_ERR_BUF_EMPTY)


typedef   HI_S32 VPSS_GRP;
typedef   HI_S32 VPSS_CHN;

#define VPSS_INVALID_FRMRATE  (-1UL)
#define VPSS_CHN0               0     
#define VPSS_CHN1               1
#define VPSS_CHN2               2
#define VPSS_CHN3               3
#define VPSS_INVALID_CHN       -1 

/*Define de-interlace mode*/    
typedef enum  hiVPSS_DIE_MODE_E
{
    VPSS_DIE_MODE_AUTO      = 0,
    VPSS_DIE_MODE_NODIE     = 1,
    VPSS_DIE_MODE_DIE       = 2,
    VPSS_DIE_MODE_BUTT
}VPSS_DIE_MODE_E;

/*Define attributes of vpss channel*/
typedef struct hiVPSS_CHN_ATTR_S
{
    HI_BOOL bSpEn;              /*Sharpen enable*/         
    HI_BOOL bBorderEn;          /*Frame enable*/
    HI_BOOL bMirror;            /*mirror enable*/
    HI_BOOL bFlip;              /*flip   enable*/
    HI_S32  s32SrcFrameRate;    /* source frame rate */
    HI_S32  s32DstFrameRate;    /* dest  frame rate */   
    BORDER_S  stBorder;     
}VPSS_CHN_ATTR_S;

typedef struct hiVPSS_GRP_PARAM_S
{
    HI_U32 u32Contrast;     /*strength of dymanic contrast improve*/
    
    HI_S32 s32GlobalStrength; /*strength of whole 3DNR*/
    HI_S32 s32IeStrength;     /*strength of image enhance*/
    HI_S32 s32YSFStrength;   /*strength of space filter*/
    HI_S32 s32YTFStrength;   /*strength of time filter*/
    HI_S32 s32CSFStrength;   /*strength of chroma filter*/
    HI_S32 s32CTFStrength;   /*strength of chroma filter*/    
    HI_S32 s32MotionLimen;   /*limen for motion*/    
}VPSS_GRP_PARAM_S;

typedef struct hiVPSS_GRP_VPPNRS_S
{
  int  tss,      sfc, tfc;
  int  sfs, tfs, mdz, ies;

}VPSS_GRP_VPPNRS_S;

typedef struct hiVPSS_GRP_VPPNRZ_S
{
    int  SFS,  SFS1, SPS1,SPT1,  TFP1,TFR1,SBF1,  MDDZ, MAAT,  SFC;
    int  TFS,  SFS2, SPS2,SPT2,  TFP2,TFR2,SBF2,  MATH, MATW,  TFC;

}VPSS_GRP_VPPNRZ_S;

typedef struct hiVPSS_GRP_VPPNRX_S
{
  int  StStrength, StProSpati, StProTempo, StBaseFreq;
  int  TFS,   TFP, TFQ, TFR,     SHP,      MDDZ, MATH;
   
}VPSS_GRP_VPPNRX_S;

typedef struct hiVPSS_GRP_LEVEL2_PARAM_S
{    
    VPSS_GRP_VPPNRS_S *pNrS;
    VPSS_GRP_VPPNRZ_S *pNrZ;
    VPSS_GRP_VPPNRX_S *pNrX;
}VPSS_GRP_LEVEL2_PARAM_S;

typedef struct hiVPSS_GRP_VPPNRXCORE_S
{
    HI_U8  SBS ;
    HI_U8  SDS , _reserved_b_ : 6;
    HI_U8  SBF:2;
    
    HI_U8  MiBaTFP;    
    HI_U8  MiDaTFP;

    HI_U8  HiBaTFP;
    HI_U8  HiDaTFP, _reserved_B_[3];

    HI_U16  MDDZ : 7;
    HI_U16  TFP   : 6, _reserved_b0_ : 1;
    HI_U16  MaTFP : 2;

    HI_U16  TFR : 5;
    HI_U16  TFS : 4;
    
    HI_U16  SHP : 7;
    HI_U16  MaTFR : 5;
    
    HI_U16  MaTFS : 4;
    HI_U16  MaSHP : 7;
} VPSS_GRP_VPPNRXCORE_S;  

typedef struct hiVPSS_GRP_VPPNRXEX_S
{
    HI_U32 ISO;

    VPSS_GRP_VPPNRXCORE_S stUnit[3];
    
    HI_U8  SFC;
    HI_U8  PostSBS;
    HI_U8  PostSDS;
    HI_U8  PostSHP;
    
    HI_U8  PostROW : 5, _reserved_b1_ : 3;    
    HI_U8  PostSFS : 4,  _reserved_b2_ : 1;
    HI_U8   MATW : 3;    
    HI_U16  MATH : 9;
    HI_U16  MABW : 1;
    HI_U16  TFC  : 6;
}VPSS_GRP_VPPNRXEX_S;

/*Define coordinate mode*/
typedef enum hiVPSS_CROP_COORDINATE_E   
{
    VPSS_CROP_RATIO_COOR = 0,   /*Ratio coordinate*/
    VPSS_CROP_ABS_COOR          /*Absolute coordinate*/
}VPSS_CROP_COORDINATE_E;

/*Define attributes of CLIP function*/
typedef struct hiVPSS_CROP_INFO_S
{
    HI_BOOL bEnable;        /*CROP enable*/
    VPSS_CROP_COORDINATE_E  enCropCoordinate;   /*Coordinate mode of the crop start point*/
    RECT_S  stCropRect;     /*CROP rectangular*/
}VPSS_CROP_INFO_S;

typedef struct hiVPSS_LDC_ATTR_S
{
    HI_BOOL bEnable;                    /* Whether LDC is enbale */
    LDC_ATTR_S stAttr;                  /* LDC Attribute */
}VPSS_LDC_ATTR_S;

/*Define attributes of vpss GROUP*/
typedef struct hiVPSS_GRP_ATTR_S
{
    /*statistic attributes*/
    HI_U32  u32MaxW;  /*MAX width of the group*/                    
    HI_U32  u32MaxH;  /*MAX height of the group*/
    PIXEL_FORMAT_E enPixFmt; /*Pixel format*/
    
    HI_BOOL bIeEn;    /*Image enhance enable*/
    HI_BOOL bDciEn;   /*Dynamic contrast Improve enable*/
    HI_BOOL bNrEn;    /*Noise reduce enable*/
    HI_BOOL bHistEn;  /*Hist enable*/
    VPSS_DIE_MODE_E enDieMode; /*De-interlace enable*/
}VPSS_GRP_ATTR_S;

/*Define vpss channel's work mode*/
typedef enum hiVPSS_CHN_MODE_E   
{
    VPSS_CHN_MODE_AUTO = 0, /*Auto mode*/
    VPSS_CHN_MODE_USER  =1 /*User mode*/
}VPSS_CHN_MODE_E;

/*Define attributes of vpss channel's work mode*/
typedef struct hiVPSS_CHN_MODE_S
{
    VPSS_CHN_MODE_E  enChnMode;   /*Vpss channel's work mode*/
    HI_U32 u32Width;              /*Width of target image*/
    HI_U32 u32Height;             /*Height of target image*/
    HI_BOOL bDouble;              /*Field-frame transfer£¬only valid for VPSS_PRE0_CHN*/
    PIXEL_FORMAT_E  enPixelFormat;/*Pixel format of target image*/
    COMPRESS_MODE_E enCompressMode;   /*Compression mode of the output*/

}VPSS_CHN_MODE_S;

typedef struct hiVPSS_FRAME_TIMEOUT_S
{
    VIDEO_FRAME_INFO_S stVideoFrame;
    HI_S32 s32MilliSec;
}VPSS_FRAME_TIMEOUT_S;

typedef struct hiVPSS_GET_GRP_FRAME_S
{
    HI_U32 u32FrameIndex;   /*reserved*/
    VIDEO_FRAME_INFO_S *pstVideoFrame;
}VPSS_GET_GRP_FRAME_S;

/*Define detailed params for channel image process*/
typedef struct hiVPSS_CHN_PARAM_S
{
    HI_U32 u32SpStrength;
} VPSS_CHN_PARAM_S;

/*Define vpss frame control info*/
typedef struct hiVPSS_FRAME_RATE_S
{
    HI_S32  s32SrcFrmRate;        /* Input frame rate of a  group*/
    HI_S32  s32DstFrmRate;        /* Output frame rate of a channel group */
} VPSS_FRAME_RATE_S;

/*Define attributes of vpss extend channel*/
typedef struct hiVPSS_EXT_CHN_ATTR_S
{
    VPSS_CHN        s32BindChn;             /*channel bind to*/
    HI_U32          u32Width;               /*Width of target image*/
    HI_U32          u32Height;              /*Height of target image*/
    HI_S32          s32SrcFrameRate;        /*Frame rate of source*/
    HI_S32          s32DstFrameRate;        /*Frame rate of extend chn input&output*/
    PIXEL_FORMAT_E  enPixelFormat;          /*Pixel format of target image*/    
    COMPRESS_MODE_E enCompressMode;   /*Compression mode of the output*/
}VPSS_EXT_CHN_ATTR_S;

typedef struct hiVPSS_REGION_INFO_S
{
    RECT_S *pstRegion;    /*region attribute*/
    HI_U32 u32RegionNum;       /*count of the region*/
}VPSS_REGION_INFO_S;

typedef struct hiVPSS_GET_REGION_LUMA_S
{
    VPSS_REGION_INFO_S stRegionInfo;  /*Information of the region*/
    HI_U32* pu32LumaData;             /*Luma data of the region*/
    HI_S32 s32MilliSec;               /*time parameter.less than 0 means waiting until get the luma data,
                                             equal to 0 means get the luma data no matter whether it can or not,
                                             more than 0 means waiting how long the time parameter it is*/
}VPSS_GET_REGION_LUMA_S;


typedef enum hiVPSS_COVER_TYPE_E
{
    VPSS_AREA_RECT = 0,
    VPSS_AREA_QUAD_RANGLE,
    VPSS_AREA_BUTT
} VPSS_COVER_TYPE_E;

typedef enum hiVPSS_REF_SEL_MODE_E   
{
    VPSS_REF_FROM_RFR  = 0, /*reference frame from the rfr frame */
    VPSS_REF_FROM_CHN0 = 1, /*reference frame from the CHN0   */
    VPSS_REF_FROM_BUTT  
    
}VPSS_REF_SEL_MODE_E;

typedef struct hiVPSS_LOW_DELAY_INFO_S
{
    HI_BOOL bEnable;
    HI_U32 u32LineCnt;

}VPSS_LOW_DELAY_INFO_S;

#ifdef __cplusplus
#if __cplusplus
}
#endif
#endif /* __cplusplus */
#endif /* __HI_COMM_VPSS_H__ */


