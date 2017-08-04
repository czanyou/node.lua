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


/*--------------------SS_SENSOR_Init   sensor ��ʼ��  --------------------
�������
eSensor:       	 sensor����VIDEO_SENSOR_TYPE_E   sony138  sony122 ov9712
bDvs:            		 Ĭ��ֵ0
bIR:              		 Ĭ��ֵ0
nVideoNum:  	 Ĭ��ֵ1
bPAL:            	 Ĭ��ֵ1
cputype:       		 ��˼оƬ����CUP_TYPE_E     3518A  3518C  3516C
checksensortype: 3518CʱֵΪ1������Ϊ0
---------------------------------------------------------------------*/
INT  SS_SENSOR_Init(VIDEO_SENSOR_TYPE_E eSensor,INT bDvs,INT bIR,INT nVideoNum, INT bPAL, INT cputype, INT checksensortype);


//��ȡ����Ĭ��ֵ
VOID SS_SENSOR_GetDefultParam(VI_CONFIG_S *pVideoInCfg);

//��ȡ֧�ֵĹ��ܣ�������֧�ֵ�VI_SENSOR_E��Ԫ�صĻ�ֵ
INT  SS_SENSOR_GetSupportViSensor();

//��ȡ֧�ֵĹ��ܣ�������֧�ֵ�VI_SCENE_E��Ԫ�صĻ�ֵ
INT  SS_SENSOR_GetSupportViScene();


/*-------------SS_SENSOR_SetViSensor   ViSensor����  --------------------
�������
port:            		 Ĭ��ֵ0
pViSensor:   		 ��Ҫ���õĵ�ǰVI_LENS_SENSOR_S�ṹ�����
Mask:  	 		 ��Ҫ���õ�VI_SENSOR_E��Ԫ�ص�ֵ�������ö��ʱ�Ļ�ֵ
---------------------------------------------------------------------*/
INT  SS_SENSOR_SetViSensor(INT port, VI_LENS_SENSOR_S *pViSensor, INT Mask);


/*-------------SS_SENSOR_SetViScene  ViScene����  --------------------
�������
port:            		 Ĭ��ֵ0
pViSensor:   		 ��Ҫ���õĵ�ǰVI_LENS_SCENE_S�ṹ�����
Mask:  	 		 ��Ҫ���õ�VI_SCENE_E��Ԫ�ص�ֵ�������ö��ʱ�Ļ�ֵ
---------------------------------------------------------------------*/
INT  SS_SENSOR_SetViScene(INT port, VI_LENS_SCENE_S *pViScene, INT Mask);


/*--------------------SS_SENSOR_SetCtB   ��ת�ں�ת������  --------------------
�������
nValue:       	 	 ��ת��ʹ�ܣ�ת�ڰ�1��ת��ɫ0
nWdrd:            	 Ĭ��ֵ0
nInfraredmode:    Ĭ��ֵ0
nBrightness:  	 Ĭ��ֵ0
byContrast:          Ĭ��ֵ0
nSaturation:         ��ǰ���Ͷȵ�ֵ
cputype:       		 ��˼оƬ����CUP_TYPE_E     3518A  3518C  3516C
checksensortype: 3518CʱֵΪ1������Ϊ0
---------------------------------------------------------------------*/
INT SS_SENSOR_SetCtB(int nValue, int nWdrd, int nInfraredmode, int nBrightness, int byContrast, int nSaturation, int cputype);


INT SS_SENSOR_SetDRC(int nValue, int nWdrd,int cputype);


/*---SS_SENSOR_GetAgcCount5   ��ȡ��������ģ�������ع�ʱ��  ----
�������
pAnaLogGain:               ��ȡ��������
pDigitalGain:            	 ��ȡģ������
pExposureTime:           ��ȡ�ع�ʱ��
---------------------------------------------------------------------*/
INT SS_SENSOR_GetAgcCount5(unsigned int *pAnaLogGain, unsigned int *pDigitalGain, unsigned int *pExposureTime , unsigned int *pExposure,int cputype);

INT SS_SENSOR_GetNewAIStatus(VI_LENS_SCENE_S *pViScene,int cputype);


/*---SS_SENSOR_SetInfraredDayOrNight   ��ȡ��������ģ�������ع�ʱ��  ----
�������
nValue:                         ��ǰģʽ����ɫģʽ0������ڰ�ģʽ1
cputype:       		         ��˼оƬ����CUP_TYPE_E     3518A  3518C  3516C
---------------------------------------------------------------------*/
INT SS_SENSOR_SetInfraredDayOrNight(int nValue, int cputype);


VOID SS_SENSOR_Set_DayDefultParam(VI_CONFIG_S *pVideoInCfg);
VOID SS_SENSOR_Set_NightDefultParam(VI_CONFIG_S *pVideoInCfg);


/*---SS_SENSOR_ISO_SetGrpParam    ���ݲ�ͬISO������Ƶ���ֲ���---
�������
sensortype:       	 sensor����VIDEO_SENSOR_TYPE_E   sony138  sony122 ov9712
---------------------------------------------------------------------*/
INT SS_SENSOR_ISO_SetGrpParam(unsigned int sensortype);


VOID SS_SENSOR_CheckViParam(VI_CONFIG_S *pVideoInCfg);
VOID SS_SENSOR_TransformViParam(VI_CONFIG_S *pVideoInCfg, int bOldToNew);


#ifdef __cplusplus
}
#endif

#endif
