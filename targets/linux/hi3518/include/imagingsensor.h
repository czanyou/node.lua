#ifndef   _IMAGEINTSENSOR_H_
#define   _IMAGEINTSENSOR_H_

#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <unistd.h>
#include <string.h>
#include <stdlib.h>

#include "head.h"

#ifdef __cplusplus
extern "C" {
#endif


typedef INT  SetViSensorFunc(INT port, VI_LENS_SENSOR_S *pViSensor, INT Mask);
typedef INT  SetViSceneFunc(INT port, VI_LENS_SCENE_S *pViScene, INT Mask);
typedef INT  Get_SupportViSensor();
typedef INT  Get_SupportViScene();
typedef	VOID getViDefultParam(VI_CONFIG_S *pVideoInCfg);
typedef	VOID checkViParam(VI_CONFIG_S *pVideoInCfg);
typedef	VOID transformViParam(VI_CONFIG_S *pVideoInCfg, INT bOldToNew);
typedef INT  InitFun(VOID *pArg, INT cputype, INT checksensortype);
typedef	VOID SetDayDefultParam(VI_CONFIG_S *pVideoInCfg);
typedef	VOID SetNightDefultParam(VI_CONFIG_S *pVideoInCfg);

typedef struct _VIDEO_IN_ST
{
	VIDEO_SENSOR_TYPE_E		eSensorType;
	InitFun                 *pfInitSensor;
	Get_SupportViSensor 	*pfGetSupportViSensor;
	Get_SupportViScene 		*pfGetSupportViScene;
	SetViSensorFunc			*pfSetViSensor;
	SetViSceneFunc			*pfSetViScene;
	getViDefultParam		*pfGetDefultParam;
	SetDayDefultParam		*pfSetDayDefultParam;
	SetNightDefultParam		*pfSetNightDefultParam;
	checkViParam			*pfCheckViParam;
	transformViParam		*pftransformViParam;
}VIDEO_IN_ST, *PVIDEO_IN_ST;


/*--------------------SS_SENSOR_Init   sensor 初始化  --------------------
输入参数
eSensor:       	 sensor类型VIDEO_SENSOR_TYPE_E   sony138  sony122 ov9712
bDvs:            		 默认值0
bIR:              		 默认值0
nVideoNum:  	 默认值1
bPAL:            	 默认值1
cputype:       		 海思芯片类型CUP_TYPE_E     3518A  3518C  3516C
checksensortype: 3518C时值为1，其他为0
---------------------------------------------------------------------*/
INT  SS_SENSOR_Init(VIDEO_SENSOR_TYPE_E eSensor,INT bDvs,INT bIR,INT nVideoNum, INT bPAL, INT cputype, INT checksensortype);


//获取参数默认值
VOID SS_SENSOR_GetDefultParam(VI_CONFIG_S *pVideoInCfg);

//获取支持的功能，返回所支持的VI_SENSOR_E中元素的或值
INT  SS_SENSOR_GetSupportViSensor();

//获取支持的功能，返回所支持的VI_SCENE_E中元素的或值
INT  SS_SENSOR_GetSupportViScene();


/*-------------SS_SENSOR_SetViSensor   ViSensor设置  --------------------
输入参数
port:            		 默认值0
pViSensor:   		 需要设置的当前VI_LENS_SENSOR_S结构体变量
Mask:  	 		 需要设置的VI_SENSOR_E中元素的值或者设置多个时的或值
---------------------------------------------------------------------*/
INT  SS_SENSOR_SetViSensor(INT port, VI_LENS_SENSOR_S *pViSensor, INT Mask);


/*-------------SS_SENSOR_SetViScene  ViScene设置  --------------------
输入参数
port:            		 默认值0
pViSensor:   		 需要设置的当前VI_LENS_SCENE_S结构体变量
Mask:  	 		 需要设置的VI_SCENE_E中元素的值或者设置多个时的或值
---------------------------------------------------------------------*/
INT  SS_SENSOR_SetViScene(INT port, VI_LENS_SCENE_S *pViScene, INT Mask);


/*--------------------SS_SENSOR_SetCtB   彩转黑黑转彩设置  --------------------
输入参数
nValue:       	 	 彩转黑使能，转黑白1，转彩色0
nWdrd:            	 默认值0
nInfraredmode:    默认值0
nBrightness:  	 默认值0
byContrast:          默认值0
nSaturation:         当前饱和度的值
cputype:       		 海思芯片类型CUP_TYPE_E     3518A  3518C  3516C
checksensortype: 3518C时值为1，其他为0
---------------------------------------------------------------------*/
INT SS_SENSOR_SetCtB(int nValue, int nWdrd, int nInfraredmode, int nBrightness, int byContrast, int nSaturation, int cputype);


INT SS_SENSOR_SetDRC(int nValue, int nWdrd,int cputype);


/*---SS_SENSOR_GetAgcCount5   获取数字增益模拟增益曝光时间  ----
输入参数
pAnaLogGain:               获取数字增益
pDigitalGain:            	 获取模拟增益
pExposureTime:           获取曝光时间
---------------------------------------------------------------------*/
INT SS_SENSOR_GetAgcCount5(unsigned int *pAnaLogGain, unsigned int *pDigitalGain, unsigned int *pExposureTime , unsigned int *pExposure,int cputype);

INT SS_SENSOR_GetNewAIStatus(VI_LENS_SCENE_S *pViScene,int cputype);


/*---SS_SENSOR_SetInfraredDayOrNight   获取数字增益模拟增益曝光时间  ----
输入参数
nValue:                         当前模式，彩色模式0，红外黑白模式1
cputype:       		         海思芯片类型CUP_TYPE_E     3518A  3518C  3516C
---------------------------------------------------------------------*/
INT SS_SENSOR_SetInfraredDayOrNight(int nValue, int cputype);


VOID SS_SENSOR_Set_DayDefultParam(VI_CONFIG_S *pVideoInCfg);
VOID SS_SENSOR_Set_NightDefultParam(VI_CONFIG_S *pVideoInCfg);


/*---SS_SENSOR_ISO_SetGrpParam    根据不同ISO设置视频部分参数---
输入参数
sensortype:       	 sensor类型VIDEO_SENSOR_TYPE_E   sony138  sony122 ov9712
---------------------------------------------------------------------*/
INT SS_SENSOR_ISO_SetGrpParam(unsigned int sensortype);


VOID SS_SENSOR_CheckViParam(VI_CONFIG_S *pVideoInCfg);
VOID SS_SENSOR_TransformViParam(VI_CONFIG_S *pVideoInCfg, int bOldToNew);


#ifdef __cplusplus
}
#endif

#endif
