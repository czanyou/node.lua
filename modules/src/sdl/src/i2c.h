#ifndef _VISION_I2C_H
#define _VISION_I2C_H

#include "common.h"

//=== Preprocessing directives (#define) 

#define	ERROR_I2C_OPEN		-1
#define	ERROR_I2C_READ		-4
#define	ERROR_I2C_SETUP		-2
#define	ERROR_I2C_WRITE		-8

//=== Global function prototypes 

int i2c_close (int fd);
int i2c_error (int i2cError);
int i2c_open  (const char *deviceName);
int i2c_read  (int fd, uint8_t* buffer, uint8_t length);
int i2c_setup (int fd, int mode, uint8_t address);
int i2c_write (int fd, const uint8_t* data, size_t numberOfBytes);
int i2c_write2(int fd, uint8_t byte1, uint8_t byte2);

uint8_t i2c_sht20_crc(const uint8_t *data, size_t numberOfBytes);

#endif // _VISION_I2C_H
