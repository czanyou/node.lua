#ifndef  _HARDWARE_API_H_
#define  _HARDWARE_API_H_

#ifdef __cplusplus
extern "C" {
#endif

// hardware init
int hardware_init(void);

//read GPIO Reset status
//return 0  low level
//		1 high level
int hardware_Read_ResetStatus(void);

// read GPIO alarm in status
// return  0 low level
//		  1 high level
int hardware_Read_AlarmIn(void);

// read GPIO alarm out contorl
//The init is a low level
// status  0 output low level
//		  1 output high level
int hardware_AlarmOut_Contorl(int status);

// read GPIO IRCut contorl
//The init is a high level
// status  0 output low level
//		  1 output high level
int hardware_IRCut_Contorl(int status);

// read GPIO photosensitive status
// return  0 low level
//		  1 high level
int hardware_Read_photosensitive(void);

// read GPIO rs485 contorl
// status  0 output low level
//		  1 output high level
int hardware_rs485_Contorl(int status);

// the GPIO InfraredLamp contorl
// status  0 output low level
//		  1 output high level
int hardware_InfraredLamp_Contorl(int status);

#ifdef __cplusplus
}
#endif

#endif

