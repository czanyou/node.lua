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

//视频参数设置，类型定义
typedef enum _VI_SENSOR_E
{
	//枪机部分设置
	VCT_BRIGHTNESS	=	0X00000001,		//亮度
	VCT_HUE			=	0X00000002,		//色度
	VCT_CONTRAST	=	0X00000004,		//对比度
	VCT_SATURATION	=	0X00000008,		//饱和度
	VCT_SHARPNESS	=	0X00000010,		//锐度
	
	VCT_AUTODAGC	=	0X00000020,		
	VCT_HANDAAGC	=	0X00000040,		//手动模拟增益
	VCT_HANDDAGC	=	0X00000080,		//手动数字增益
	VCT_GAMMA		=	0X00000100,		//Gamma

	VCT_AUTOAWB		=	0X00000200,		//自动白平衡
	VCT_AWBRED		=	0X00000400,		//白平衡 红
	VCT_AWBGREEN	=	0X00000800,		//白平衡 绿
	VCT_AWBBLUE		=	0X00001000,		//白平衡 蓝

	//机芯部分设置
	VCT_AUTOAGC		=	0X00002000,		////自动增益
	VCT_AGCLEVEL	=	0X00004000,		////增益值
	VCT_AUTOBLC		=	0X00008000,		////自动补偿
	VCT_BLCLEVEL	=	0X00010000,		////补偿值
	VCT_AUTOEXPOSURE=	0X00020000,		////自动曝光 
	VCT_EXPOSURETIME=	0X00040000,		////手动曝光时间 
	VCT_SHUTTERFIRST=	0X00080000,		
	VCT_AUTOSHUTTER	=	0X00100000,		
	VCT_SHUTTERSPEED=	0X00200000,		////快门速度
	VCT_SLOWSHUTTER	=	0X00400000,		////慢快门
	VCT_SLOWSHUTTERLEVEL=0X00800000,	////慢快门速度
	VCT_AUTOAWBMODE =	0X01000000,		////1080p Hispeed自动白平衡模式

	//枪机部分设置
	VCT_MAXAGC		=   0X02000000,		//最大增益值			 
	VCT_EXPTIMEMAX	=   0X04000000,		//自动曝光快门最大值  
	VCT_ANTIFOG	    =   0x08000000,     //去雾
	VCT_ANTIFLASECOLOR =    0x10000000, //去伪彩
	VCT_ANTIDIS			=   0x20000000, //去抖动
	VCT_ROTATE	    =   0x40000000,     //90度 270度旋转
	VCT_GAMAMODE	=   0x80000000,     //gama模式选择
	VCT_SENSOR_ALL	=	0xFFFFFFFF,		//设置所有参数
}VI_SENSOR_E;

//视频参数设置，类型定义
typedef enum _VI_SCENE_E
{
	//枪机部分设置
	VCT_AUTOIRIS	=	0X00000001,		//自动光圈
	VCT_IRISLEVEL	=	0X00000002,		

	//机芯部分设置
	VCT_AUTOFOCUS	=	0X00000004,		////自动聚焦
	VCT_FOCUSLEVEL	=	0X00000008,		
	VCT_ZOOMSPEED	=	0X00000010,		////变倍速度
	VCT_AUTOPTZSPEED=	0X00000020,		
	VCT_AUTOALC		=	0X00000040,		
	VCT_ALCLEVEL	=	0X00000080,		

	//枪机部分设置
	VCT_CTB			=	0X00000100,		//彩转黑 
	VCT_SCENE		=	0X00000200,		
	VCT_MIRROR		=	0X00000400,		//镜向
	VCT_FLIP		=	0X00000800,		//翻转

	//机芯部分设置
	VCT_AUTOFLIP	=	0X00001000,		////自动翻转

	//枪机部分设置
	VCT_PWDFREQ1	=	0X00002000,		//照明频率1VCT_FLICKERCTRL1

	//机芯部分设置
	VCT_PWDFREQ2	=	0X00004000,		
	VCT_IREXIST		=	0X00008000,		
	VCT_IRCFMODE	=	0X00010000,		////IRCF模式
	VCT_IRLIGHTTYPE	=	0X00020000,		////红外灯类型

	//枪机部分设置
	VCT_WDR 		=	0X00040000,		//是否有宽动态
	VCT_WDRLEVEL	=	0X00080000,		//宽动态的值

	//机芯部分设置
	VCT_LOWILLUM	=	0X00100000,		////低照度
	VCT_IMAGEMODE	=	0X00200000,		////图像模式
	VCT_VI_SIZE     =   0X00400000,		////视频输入尺寸

	//枪机部分设置
	VCT_CTBLEVEL 	= 	0X00800000,		//彩转黑阀值，当彩转黑为自动时有效
	VCT_MINFOCUSLEN =   0X01000000,		
	VCT_IRLEVEL 	=   0X02000000,		
	VCT_LENSCORRECTION =0X04000000,		//镜头校正		
	VCT_SMARTNR     = 	0x08000000,		
	VCT_3DNR   	    =	0X10000000,		//3D降噪		
	VCT_3DNRLEVEL	= 	0x20000000,		//3D降噪值
	VCT_IRISCORRECTION=	0x40000000,		
	VCT_INFRAREDETECT=	0x80000000,		
	VCT_SCENE_ALL	=	0xFFFFFFFF,		//设置所有参数
}VI_SCENE_E;

typedef enum _VIDEO_SENSOR_TYPE_E
{
	//枪机部分
	VI_SENSOR_CMOS_720P_OV9712		= 0x11,		
	VI_SENSOR_CMOS_720P_IMX138		= 0x13,		
	VI_SENSOR_CMOS_1080P_IMX122		= 0x20,		

	//机芯部分
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


//时间: 日期
typedef struct _DATE_TIME_S
{
	DWORD			second : 6;							//秒:  0 ~ 59
	DWORD			minute : 6;							//分:  0 ~ 59
	DWORD			hour : 5;							//时:  0 ~ 23
	DWORD			day : 5;							//日:  1 ~ 31
	DWORD			month : 4;							//月:  1 ~ 12
	DWORD			year : 6;							//年:  2000 ~ 2063
}DATE_TIME_S;


//功能:  视频参数部分设置
//说明: 读写		 
typedef struct _VI_LENS_SENSOR_S
{
	VI_SENSOR_E			eValidSupport;					//有效支持的参数，该参数设置时候无效  在获取的时候有效，用以判断设备是否支持该参数

	VI_SENSOR_E			eValidSetting;					//设置有效的参数，该参数获取时候无效  在设置的时候有效，用以指定具体设置的参数

	BYTE				byBrightness;					//亮度 			0 ~ 255 
	BYTE				byBrightnessDefault;			//亮度缺省值 		    
	BYTE				byBrightnessStep;				//亮度调节步长 		    

	BYTE				byHue;							//色度			0 ~ 255 
	BYTE				byHueDefault;					//色度缺省值;	 
	BYTE				byHueStep;						//色度调节步长  
		
	BYTE				byContrast;						//对比度		0 ~ 255 
	BYTE				byContrastDefault;				//对比度缺省值 
	BYTE				byContrastStep;					//对比度调节步长 

	BYTE				bySaturation;					//饱和度		0 ~ 255 
	BYTE				bySaturationDefault;			//饱和度缺省值  
	BYTE				bySaturationStep;				//饱和度调节步长  

	BYTE				bySharpness;					//锐度			0 ~ 255 
	BYTE				bySharpnessDefault;				//锐度缺省值  
	BYTE				bySharpnessStep;				//锐度调节步长  

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
	BYTE				byGammaDefault;					//gamma缺省值  
	BYTE				byGammaStep;					//gamma调节步长  

	BYTE				byAutoAwb;						//自动白平衡 	0自动, 1 手动 
	
	BYTE				byAwbRed;						//白平衡 红 	0 ~ 255 
	BYTE				byAwbRedDefault;				//白平衡 红缺省值  
	BYTE				byAwbRedStep;					//白平衡 红调节步长  

	BYTE				byAwbGreen;						//白平衡 绿 	0 ~ 255 
	BYTE				byAwbGreenDefault;				//白平衡 绿缺省值  
	BYTE				byAwbGreenStep;					//白平衡 绿调节步长  

	BYTE				byAwBblue;						//白平衡 蓝 	0 ~ 255 
	BYTE				byAwBblueDefault;				//白平衡 蓝缺省值  
	BYTE				byAwBblueStep;					//白平衡 蓝调节步长  

	BYTE				byAutoAgc;						////自动增益 		0自动, 1 手动 
	BYTE				byAgcLevel;						////增益值 		0 ~ 255 
	BYTE				byAgcLevelDefault;				////增益值缺省值  
	BYTE				byAgcLevelStep;					////增益值调节步长  

	BYTE				byAutoBlc;						////自动补偿;		0自动, 1 手动 
	BYTE				byBlcLevel;						////补偿值;		0 ~ 255 
	BYTE				byBlcLevelDefault;				////补偿值缺省值; 
	BYTE				byBlcLevelStep;					////补偿值调节步长; 

	BYTE				byAutoExposure;					////0自动 1 手动 
	WORD				wExpoSuretime;					/*////手动曝光时间	F1.6=16
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
	WORD				wShutterSpeed;					/*////快门速度;		1		= 1
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
											 
	BYTE				bySlowShutter;					////慢快门 	0关,   1 开 

	BYTE				bySlowShutterLevel;				////慢快门速度0 ~ 255 
	BYTE				bySlowShutterLevelDefault;		////慢快门速度缺省值 
	BYTE				bySlowShutterLevelStep;			////慢快门速度调节步长  

	BYTE				byAwbAutoMode;					////自动白平衡模式,仅当白平衡为自动时有效

	BYTE				byMaxAgc;						//最大增益值          
	WORD				wExpTimeMax;					//自动曝光快门最大值  

	BYTE			    byAntiFog;						//去雾
	BYTE                byAntiFalseColor;               //去伪彩
	BYTE                byAntiDIS;                      //去抖
	BYTE                byRotate;                       //90度 270度旋转

	BYTE 				byAutoDGainMax;					
	BYTE 				byManualAGain;					//手动模拟增益
	BYTE				byManualDGain;					//手动数字增益
	BYTE				byManualAGainEnable;			//手动模拟增益使能
	BYTE				byManualDGainEnable;			// 手动数字增益使能
	
	BYTE				byGammaMode;					//Gamma模式   1--通透模式  0--真彩模式  
	BYTE				byISO;						    //ISO值根据该值调整gama曲线  
	
	BYTE				byRes[17];								
}VI_LENS_SENSOR_S;


//功能: 视频参数部分设置
//说明: 读写		 
typedef struct _VI_LENS_SCENE_S
{
	VI_SCENE_E			eValidSupport;					//有效支持的参数，该参数设置时候无效 在获取的时候有效，用以判断设备是否支持该参数

	VI_SCENE_E			eValidSetting;					//设置有效的参数，该参数获取时候无效 在设置的时候有效，用以指定具体设置的参数

	BYTE				byAutoIris;						//自动光圈		0自动, 1 手动 

	BYTE				byIrisLevel;					//光圈电平 		0 ~ 255 
	BYTE				byIrisLevelDefault;				//光圈电平缺省值  
	BYTE				byIrisLevelStep;				//光圈电平调节步长  

	BYTE				byAutoFocus;					////自动聚焦 		0自动, 1 手动 

	BYTE				byFocusLevel;					
	BYTE				byFocusLevelDefault;			
	BYTE				byFocusLevelStep;				

	BYTE				byZoomSpeed;					////变倍速度 		0 高速,  1 正常速度 
	BYTE				byAutoPtzSpeed;					

	BYTE				byAutoAlc;						 

	BYTE				byAlcLevel;						
	BYTE				byAlcLevelDefault;				
	BYTE				byAlcLevelStep;						 

	BYTE				byCtb;							//彩转黑 		0关,   1 开 

	BYTE				byScene;						
	BYTE				byMirror;						//镜向			0关,   1 开 
	BYTE				byFlip;							//翻转 			0关,   1 开 
	BYTE				byAutoFlip;						//自动翻转 		0关,  1 开 
	BYTE				byPwdFreq1;						//照明频率1 	0 60HZ,	1 50HZ 
	BYTE				byPwdFreq2;						 

	BYTE				byIRExist;						 
	BYTE				byIRCFMode;						////IRcf模式;		0 OUT=>IN, 1 IN=>OUT 
	BYTE				byInfraredLampType;				////红外灯类型;	0 正常光,  1 850mm,   2 950mm 

	BYTE				byWDR;							//宽动态		0无,   1 有 
	BYTE				byWDRLevel;						//宽动态		0 ~ 255 
	BYTE				byLowIllumination;				////低照度		1默认AF
														////				2低照度AF优化开启
														////				3低照度点光源AF优化开启
										 
	BYTE				byImageMode;					////图像模式		0 模式 1，  1 模式 2  

	WORD      			u16ViWidth;						////视频输入 宽度 
	WORD 				u16ViHeight;					////视频输入 高度 
	BYTE 				byCtbLevel;						////彩转黑阀值，自动彩转黑时有效 
	BYTE 				byMinFocusLen;					 
	BYTE 				byIRLevel;						   
	BYTE				byLensCorrection;				//镜头校正		0: 关   1: 开  	 

	BYTE				bySmartNR;						
	BYTE				bySmartNRDefault;				
	BYTE 				by3DNR; 						//3D 降噪		0: 关	1: 开     
	BYTE				by3DNRLevel;					//3D降噪值  

	BYTE				byInfraredDetectMode;			//0-- 视频检测   1-- 时间控制        2 --光敏检测
	BYTE				byTRCutLevel;					//IRCUT切换             0 --低电平有效 1 --高电平有效           为夜晚模式
	BYTE				byphotoresistorLevel;			//光敏电阻            0 --低电平有效 1 --高电平有效 		为黑夜
	BYTE				byInfraredLamp;		     		//红外灯切换      0 --低电平有效 1-- 高电平有效           打开红外灯
	DATE_TIME_S			uDayDetecttime;			        //转白天检测时间
	DATE_TIME_S			uNigntDetecttime;			    //转夜晚检测时间
	BYTE				byirtime;				        //光敏电阻模式  黑转彩切换时间0到60秒

	BYTE				byWDR2;						   
	BYTE				WDRLevel2;						
	BYTE				bySDKSet;					  
	
	BYTE				byirCtoBtime;					//光敏电阻模式彩转黑切换时间0到60秒

	BYTE				byRes[31];
	
}VI_LENS_SCENE_S;


typedef struct _VIDEO_IN_CFG_S
{
	DWORD				dwSize;		    /*结构大小*/
	VI_LENS_SENSOR_S	struViSensor;	/*视频输入设置*/
	VI_LENS_SCENE_S		struViScene;	/*视频输入场景相关设置*/
}VI_CONFIG_S,*LPVIDEO_IN_CFG_S;


#ifdef __cplusplus
}
#endif

#endif

