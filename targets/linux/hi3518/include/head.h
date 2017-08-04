#ifndef   _SENSOR_HEAD_H_
#define   _SENSOR_HEAD_H_

#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <unistd.h>
#include <string.h>
#include <stdlib.h>


#ifdef __cplusplus
extern "C" {
#endif

typedef unsigned char           BYTE;
typedef unsigned short          WORD;
typedef unsigned int            DWORD;
typedef          int            INT;
typedef void					VOID;
typedef          char           CHAR;

#define PASS_LEVEL_0      0
#define PASS_LEVEL_1      1
#define PASS_LEVEL_2      2
#define PASS_LEVEL_3      3

#define TRUE			  1
#define FALSE			  0

//��Ƶ�������ã����Ͷ���
typedef enum _VI_SENSOR_E
{
	//ǹ����������
	VCT_BRIGHTNESS	=	0X00000001,		//����
	VCT_HUE			=	0X00000002,		//ɫ��
	VCT_CONTRAST	=	0X00000004,		//�Աȶ�
	VCT_SATURATION	=	0X00000008,		//���Ͷ�
	VCT_SHARPNESS	=	0X00000010,		//���
	
	VCT_AUTODAGC	=	0X00000020,		
	VCT_HANDAAGC	=	0X00000040,		//�ֶ�ģ������
	VCT_HANDDAGC	=	0X00000080,		//�ֶ���������
	VCT_GAMMA		=	0X00000100,		//Gamma

	VCT_AUTOAWB		=	0X00000200,		//�Զ���ƽ��
	VCT_AWBRED		=	0X00000400,		//��ƽ�� ��
	VCT_AWBGREEN	=	0X00000800,		//��ƽ�� ��
	VCT_AWBBLUE		=	0X00001000,		//��ƽ�� ��

	//��о��������
	VCT_AUTOAGC		=	0X00002000,		////�Զ�����
	VCT_AGCLEVEL	=	0X00004000,		////����ֵ
	VCT_AUTOBLC		=	0X00008000,		////�Զ�����
	VCT_BLCLEVEL	=	0X00010000,		////����ֵ
	VCT_AUTOEXPOSURE=	0X00020000,		////�Զ��ع� 
	VCT_EXPOSURETIME=	0X00040000,		////�ֶ��ع�ʱ�� 
	VCT_SHUTTERFIRST=	0X00080000,		
	VCT_AUTOSHUTTER	=	0X00100000,		
	VCT_SHUTTERSPEED=	0X00200000,		////�����ٶ�
	VCT_SLOWSHUTTER	=	0X00400000,		////������
	VCT_SLOWSHUTTERLEVEL=0X00800000,	////�������ٶ�
	VCT_AUTOAWBMODE =	0X01000000,		////1080p Hispeed�Զ���ƽ��ģʽ

	//ǹ����������
	VCT_MAXAGC		=   0X02000000,		//�������ֵ			 
	VCT_EXPTIMEMAX	=   0X04000000,		//�Զ��ع�������ֵ  
	VCT_ANTIFOG	    =   0x08000000,     //ȥ��
	VCT_ANTIFLASECOLOR =    0x10000000, //ȥα��
	VCT_ANTIDIS			=   0x20000000, //ȥ����
	VCT_ROTATE	    =   0x40000000,     //90�� 270����ת
	VCT_GAMAMODE	=   0x80000000,     //gamaģʽѡ��
	VCT_SENSOR_ALL	=	0xFFFFFFFF,		//�������в���
}VI_SENSOR_E;

//��Ƶ�������ã����Ͷ���
typedef enum _VI_SCENE_E
{
	//ǹ����������
	VCT_AUTOIRIS	=	0X00000001,		//�Զ���Ȧ
	VCT_IRISLEVEL	=	0X00000002,		

	//��о��������
	VCT_AUTOFOCUS	=	0X00000004,		////�Զ��۽�
	VCT_FOCUSLEVEL	=	0X00000008,		
	VCT_ZOOMSPEED	=	0X00000010,		////�䱶�ٶ�
	VCT_AUTOPTZSPEED=	0X00000020,		
	VCT_AUTOALC		=	0X00000040,		
	VCT_ALCLEVEL	=	0X00000080,		

	//ǹ����������
	VCT_CTB			=	0X00000100,		//��ת�� 
	VCT_SCENE		=	0X00000200,		
	VCT_MIRROR		=	0X00000400,		//����
	VCT_FLIP		=	0X00000800,		//��ת

	//��о��������
	VCT_AUTOFLIP	=	0X00001000,		////�Զ���ת

	//ǹ����������
	VCT_PWDFREQ1	=	0X00002000,		//����Ƶ��1VCT_FLICKERCTRL1

	//��о��������
	VCT_PWDFREQ2	=	0X00004000,		
	VCT_IREXIST		=	0X00008000,		
	VCT_IRCFMODE	=	0X00010000,		////IRCFģʽ
	VCT_IRLIGHTTYPE	=	0X00020000,		////���������

	//ǹ����������
	VCT_WDR 		=	0X00040000,		//�Ƿ��п�̬
	VCT_WDRLEVEL	=	0X00080000,		//��̬��ֵ

	//��о��������
	VCT_LOWILLUM	=	0X00100000,		////���ն�
	VCT_IMAGEMODE	=	0X00200000,		////ͼ��ģʽ
	VCT_VI_SIZE     =   0X00400000,		////��Ƶ����ߴ�

	//ǹ����������
	VCT_CTBLEVEL 	= 	0X00800000,		//��ת�ڷ�ֵ������ת��Ϊ�Զ�ʱ��Ч
	VCT_MINFOCUSLEN =   0X01000000,		
	VCT_IRLEVEL 	=   0X02000000,		
	VCT_LENSCORRECTION =0X04000000,		//��ͷУ��		
	VCT_SMARTNR     = 	0x08000000,		
	VCT_3DNR   	    =	0X10000000,		//3D����		
	VCT_3DNRLEVEL	= 	0x20000000,		//3D����ֵ
	VCT_IRISCORRECTION=	0x40000000,		
	VCT_INFRAREDETECT=	0x80000000,		
	VCT_SCENE_ALL	=	0xFFFFFFFF,		//�������в���
}VI_SCENE_E;

typedef enum _VIDEO_SENSOR_TYPE_E
{
	//ǹ������
	VI_SENSOR_CMOS_720P_OV9712		= 0x11,		
	VI_SENSOR_CMOS_720P_IMX138		= 0x13,		
	VI_SENSOR_CMOS_1080P_IMX122		= 0x20,		

	//��о����
	VI_HISPEED_CCD_720P_SC110		= 0x50, 	
	VI_HISPEED_CMOS_1080P_SC220 	= 0x51, 	
	VI_HISPEED_CMOS_1080P_SONY6300	= 0x52, 	
	VI_HISPEED_CMOS_1080P_PE2203	= 0x53, 	

}VIDEO_SENSOR_TYPE_E;

typedef enum _CUP_TYPE_E
{
	CUP_TYPE_HI3518A  = 1,						 
	CUP_TYPE_HI3518C  = 2,						 
	CUP_TYPE_HI3516C  = 3,		
	
}CUP_TYPE_E;


//ʱ��: ����
typedef struct _DATE_TIME_S
{
	DWORD			second : 6;							//��:  0 ~ 59
	DWORD			minute : 6;							//��:  0 ~ 59
	DWORD			hour : 5;							//ʱ:  0 ~ 23
	DWORD			day : 5;							//��:  1 ~ 31
	DWORD			month : 4;							//��:  1 ~ 12
	DWORD			year : 6;							//��:  2000 ~ 2063
}DATE_TIME_S;


//����:  ��Ƶ������������
//˵��: ��д		 
typedef struct _VI_LENS_SENSOR_S
{
	VI_SENSOR_E			eValidSupport;					//��Ч֧�ֵĲ������ò�������ʱ����Ч  �ڻ�ȡ��ʱ����Ч�������ж��豸�Ƿ�֧�ָò���

	VI_SENSOR_E			eValidSetting;					//������Ч�Ĳ������ò�����ȡʱ����Ч  �����õ�ʱ����Ч������ָ���������õĲ���

	BYTE				byBrightness;					//���� 			0 ~ 255 
	BYTE				byBrightnessDefault;			//����ȱʡֵ 		    
	BYTE				byBrightnessStep;				//���ȵ��ڲ��� 		    

	BYTE				byHue;							//ɫ��			0 ~ 255 
	BYTE				byHueDefault;					//ɫ��ȱʡֵ;	 
	BYTE				byHueStep;						//ɫ�ȵ��ڲ���  
		
	BYTE				byContrast;						//�Աȶ�		0 ~ 255 
	BYTE				byContrastDefault;				//�Աȶ�ȱʡֵ 
	BYTE				byContrastStep;					//�Աȶȵ��ڲ��� 

	BYTE				bySaturation;					//���Ͷ�		0 ~ 255 
	BYTE				bySaturationDefault;			//���Ͷ�ȱʡֵ  
	BYTE				bySaturationStep;				//���Ͷȵ��ڲ���  

	BYTE				bySharpness;					//���			0 ~ 255 
	BYTE				bySharpnessDefault;				//���ȱʡֵ  
	BYTE				bySharpnessStep;				//��ȵ��ڲ���  

	BYTE				byRed;							
	BYTE				byRedDefault;					 
	BYTE				byRedStep;						  

	BYTE				byGreen;						
	BYTE				byGreenDefault;					
	BYTE				byGreenStep;					

	BYTE				byBlue;							
	BYTE				byBlueDefault;					
	BYTE				byBlueStep;						  

	BYTE				byGamma;						//gamma			0 ~ 255 
	BYTE				byGammaDefault;					//gammaȱʡֵ  
	BYTE				byGammaStep;					//gamma���ڲ���  

	BYTE				byAutoAwb;						//�Զ���ƽ�� 	0�Զ�, 1 �ֶ� 
	
	BYTE				byAwbRed;						//��ƽ�� �� 	0 ~ 255 
	BYTE				byAwbRedDefault;				//��ƽ�� ��ȱʡֵ  
	BYTE				byAwbRedStep;					//��ƽ�� ����ڲ���  

	BYTE				byAwbGreen;						//��ƽ�� �� 	0 ~ 255 
	BYTE				byAwbGreenDefault;				//��ƽ�� ��ȱʡֵ  
	BYTE				byAwbGreenStep;					//��ƽ�� �̵��ڲ���  

	BYTE				byAwBblue;						//��ƽ�� �� 	0 ~ 255 
	BYTE				byAwBblueDefault;				//��ƽ�� ��ȱʡֵ  
	BYTE				byAwBblueStep;					//��ƽ�� �����ڲ���  

	BYTE				byAutoAgc;						////�Զ����� 		0�Զ�, 1 �ֶ� 
	BYTE				byAgcLevel;						////����ֵ 		0 ~ 255 
	BYTE				byAgcLevelDefault;				////����ֵȱʡֵ  
	BYTE				byAgcLevelStep;					////����ֵ���ڲ���  

	BYTE				byAutoBlc;						////�Զ�����;		0�Զ�, 1 �ֶ� 
	BYTE				byBlcLevel;						////����ֵ;		0 ~ 255 
	BYTE				byBlcLevelDefault;				////����ֵȱʡֵ; 
	BYTE				byBlcLevelStep;					////����ֵ���ڲ���; 

	BYTE				byAutoExposure;					////0�Զ� 1 �ֶ� 
	WORD				wExpoSuretime;					/*////�ֶ��ع�ʱ��	F1.6=16
																		F2.2=22
																		F3.2=32
																		F4.4=44
																		F6.4=64
																		F8.8=88
																		F12.0=120
																		F17.0=170
																		F24.0=240
																		F34.0=340	*/
										 
	BYTE				byShutterFirst;					
	BYTE				byAutoShutter;					
	WORD				wShutterSpeed;					/*////�����ٶ�;		1		= 1
																		1/2		= 2
																		1/4		= 4
																		1/8		= 8
																		1/16	= 16
																		1/25	= 25
																		1/50	= 50
																		1/100	= 100
																		1/150	= 150
																		1/200	= 200
																		1/250	= 250
																		1/300	= 300
																		1/400	= 400
																		1/1000	= 1000
																		1/2000	= 2000
																		1/4000	= 4000
																		1/10000	= 10000 */
											 
	BYTE				bySlowShutter;					////������ 	0��,   1 �� 

	BYTE				bySlowShutterLevel;				////�������ٶ�0 ~ 255 
	BYTE				bySlowShutterLevelDefault;		////�������ٶ�ȱʡֵ 
	BYTE				bySlowShutterLevelStep;			////�������ٶȵ��ڲ���  

	BYTE				byAwbAutoMode;					////�Զ���ƽ��ģʽ,������ƽ��Ϊ�Զ�ʱ��Ч

	BYTE				byMaxAgc;						//�������ֵ          
	WORD				wExpTimeMax;					//�Զ��ع�������ֵ  

	BYTE			    byAntiFog;						//ȥ��
	BYTE                byAntiFalseColor;               //ȥα��
	BYTE                byAntiDIS;                      //ȥ��
	BYTE                byRotate;                       //90�� 270����ת

	BYTE 				byAutoDGainMax;					
	BYTE 				byManualAGain;					//�ֶ�ģ������
	BYTE				byManualDGain;					//�ֶ���������
	BYTE				byManualAGainEnable;			//�ֶ�ģ������ʹ��
	BYTE				byManualDGainEnable;			// �ֶ���������ʹ��
	
	BYTE				byGammaMode;					//Gammaģʽ   1--ͨ͸ģʽ  0--���ģʽ  
	BYTE				byISO;						    //ISOֵ���ݸ�ֵ����gama����  
	
	BYTE				byRes[17];								
}VI_LENS_SENSOR_S;


//����: ��Ƶ������������
//˵��: ��д		 
typedef struct _VI_LENS_SCENE_S
{
	VI_SCENE_E			eValidSupport;					//��Ч֧�ֵĲ������ò�������ʱ����Ч �ڻ�ȡ��ʱ����Ч�������ж��豸�Ƿ�֧�ָò���

	VI_SCENE_E			eValidSetting;					//������Ч�Ĳ������ò�����ȡʱ����Ч �����õ�ʱ����Ч������ָ���������õĲ���

	BYTE				byAutoIris;						//�Զ���Ȧ		0�Զ�, 1 �ֶ� 

	BYTE				byIrisLevel;					//��Ȧ��ƽ 		0 ~ 255 
	BYTE				byIrisLevelDefault;				//��Ȧ��ƽȱʡֵ  
	BYTE				byIrisLevelStep;				//��Ȧ��ƽ���ڲ���  

	BYTE				byAutoFocus;					////�Զ��۽� 		0�Զ�, 1 �ֶ� 

	BYTE				byFocusLevel;					
	BYTE				byFocusLevelDefault;			
	BYTE				byFocusLevelStep;				

	BYTE				byZoomSpeed;					////�䱶�ٶ� 		0 ����,  1 �����ٶ� 
	BYTE				byAutoPtzSpeed;					

	BYTE				byAutoAlc;						 

	BYTE				byAlcLevel;						
	BYTE				byAlcLevelDefault;				
	BYTE				byAlcLevelStep;						 

	BYTE				byCtb;							//��ת�� 		0��,   1 �� 

	BYTE				byScene;						
	BYTE				byMirror;						//����			0��,   1 �� 
	BYTE				byFlip;							//��ת 			0��,   1 �� 
	BYTE				byAutoFlip;						//�Զ���ת 		0��,  1 �� 
	BYTE				byPwdFreq1;						//����Ƶ��1 	0 60HZ,	1 50HZ 
	BYTE				byPwdFreq2;						 

	BYTE				byIRExist;						 
	BYTE				byIRCFMode;						////IRcfģʽ;		0 OUT=>IN, 1 IN=>OUT 
	BYTE				byInfraredLampType;				////���������;	0 ������,  1 850mm,   2 950mm 

	BYTE				byWDR;							//��̬		0��,   1 �� 
	BYTE				byWDRLevel;						//��̬		0 ~ 255 
	BYTE				byLowIllumination;				////���ն�		1Ĭ��AF
														////				2���ն�AF�Ż�����
														////				3���նȵ��ԴAF�Ż�����
										 
	BYTE				byImageMode;					////ͼ��ģʽ		0 ģʽ 1��  1 ģʽ 2  

	WORD      			u16ViWidth;						////��Ƶ���� ��� 
	WORD 				u16ViHeight;					////��Ƶ���� �߶� 
	BYTE 				byCtbLevel;						////��ת�ڷ�ֵ���Զ���ת��ʱ��Ч 
	BYTE 				byMinFocusLen;					 
	BYTE 				byIRLevel;						   
	BYTE				byLensCorrection;				//��ͷУ��		0: ��   1: ��  	 

	BYTE				bySmartNR;						
	BYTE				bySmartNRDefault;				
	BYTE 				by3DNR; 						//3D ����		0: ��	1: ��     
	BYTE				by3DNRLevel;					//3D����ֵ  

	BYTE				byInfraredDetectMode;			//0-- ��Ƶ���   1-- ʱ�����        2 --�������
	BYTE				byTRCutLevel;					//IRCUT�л�             0 --�͵�ƽ��Ч 1 --�ߵ�ƽ��Ч           Ϊҹ��ģʽ
	BYTE				byphotoresistorLevel;			//��������            0 --�͵�ƽ��Ч 1 --�ߵ�ƽ��Ч 		Ϊ��ҹ
	BYTE				byInfraredLamp;		     		//������л�      0 --�͵�ƽ��Ч 1-- �ߵ�ƽ��Ч           �򿪺����
	DATE_TIME_S			uDayDetecttime;			        //ת������ʱ��
	DATE_TIME_S			uNigntDetecttime;			    //תҹ����ʱ��
	BYTE				byirtime;				        //��������ģʽ  ��ת���л�ʱ��0��60��

	BYTE				byWDR2;						   
	BYTE				WDRLevel2;						
	BYTE				bySDKSet;					  
	
	BYTE				byirCtoBtime;					//��������ģʽ��ת���л�ʱ��0��60��

	BYTE				byRes[31];
	
}VI_LENS_SCENE_S;


typedef struct _VIDEO_IN_CFG_S
{
	DWORD				dwSize;		    /*�ṹ��С*/
	VI_LENS_SENSOR_S	struViSensor;	/*��Ƶ��������*/
	VI_LENS_SCENE_S		struViScene;	/*��Ƶ���볡���������*/
}VI_CONFIG_S,*LPVIDEO_IN_CFG_S;


#ifdef __cplusplus
}
#endif

#endif

