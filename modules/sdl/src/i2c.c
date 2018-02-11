
#include "common.h"
#include "i2c.h"

//--------------------------------------------------------------------------------------------------
// Name:	  i2c_open 
// Function:  Open device/port
//			  Raspberry Hardwarerevision 1.0	P1 = /dev/i2c-0
//			  Raspberry Hardwarerevision 2.0	P1 = /dev/i2c-1
//            
// Parameter: Devicename (String)
// Return:    
//--------------------------------------------------------------------------------------------------
int i2c_open(const char *deviceName)
{
	int fd = -1;
	if (deviceName == NULL || *deviceName == '\0') {
		return fd;
	}

	#ifdef __linux__
	if ((fd = open(deviceName, O_RDWR)) < 0) {
		return ERROR_I2C_OPEN;
	}
	#endif

	return fd;
}	

//--------------------------------------------------------------------------------------------------
// Name:      i2c_close
// Function:  Close port/device
//            
// Parameter: -
// Return:    -
//--------------------------------------------------------------------------------------------------
int i2c_close(int fd)
{
	#ifdef __linux__
	if (fd > 0) {
		close(fd);
	}
	#endif

	return 0;
}

//--------------------------------------------------------------------------------------------------
// Name:      i2c_setup
// Function:  Setup port for communication
//            
// Parameter: mode (typical "I2C_SLAVE"), Device address (typical slave address from device) 
// Return:    -
//--------------------------------------------------------------------------------------------------
int i2c_setup(int fd, int mode, uint8_t address)	
{
	#ifdef __linux__
	if (ioctl(fd, mode, address) < 0) {
		return ERROR_I2C_SETUP;	
	}
	#endif

	return 0;
}

//--------------------------------------------------------------------------------------------------
// Name:      i2c_write1
// Function:  Write a singel byte to I2C-Bus
//            
// Parameter: Byte to send
// Return:    -
//--------------------------------------------------------------------------------------------------
int i2c_write(int fd, const uint8_t* data, size_t numberOfBytes)
{
	if (data == NULL || numberOfBytes <= 0) {
		return ERROR_I2C_WRITE;
	}

	#ifdef __linux__
	if ((write(fd, data, numberOfBytes)) != numberOfBytes) {
		return ERROR_I2C_WRITE;
	}
	#endif

	return 0;
}

//--------------------------------------------------------------------------------------------------
// Name:      i2c_write2
// Function:  Write two bytes to I2C
//            
// Parameter: First byte, second byte
// Return:    -
//--------------------------------------------------------------------------------------------------
int i2c_write2(int fd, uint8_t d0, uint8_t d1)
{
	#ifdef __linux__
	uint8_t buf[2];
	
	buf[0] = d0;
	buf[1] = d1;
	if ((write(fd, buf, 2)) != 2) {
		return ERROR_I2C_WRITE;
	}	
	#endif
	
	return 0;
}

//--------------------------------------------------------------------------------------------------
// Name:      i2c_read
// Function:  Read a number of bytes
//            
// Parameter: Pointer to buffer, Number of bytes to read
// Return:    -
//--------------------------------------------------------------------------------------------------
int i2c_read(int fd, uint8_t *buffer, uint8_t length)
{
	if (buffer == NULL || length <= 0) {
		return ERROR_I2C_READ;
	}

	#ifdef __linux__
	if (read(fd, buffer, length) != length) {
		return ERROR_I2C_READ;		
	}
	#endif

	return 0;
}

//--------------------------------------------------------------------------------------------------
// Name:      i2c_error
// Function:  Print error flags as readable text.
//            
// Parameter: -
// Return:    -
//--------------------------------------------------------------------------------------------------
int i2c_error(int i2cError)
{	
	if (i2cError & ERROR_I2C_OPEN) {
		printf("Failed to open I2C-Port\r\n");
	}

	if (i2cError & ERROR_I2C_SETUP) {
		printf("Failed to setup I2C-Port\r\n");
	}

	if (i2cError & ERROR_I2C_READ) {
		printf("I2C read error\r\n");
	}

	if (i2cError & ERROR_I2C_WRITE) {
		printf("I2C write error\r\n");
	}

	return 0;
}

uint8_t i2c_sht20_crc(const uint8_t *data, size_t numberOfBytes)
{
	if (data == NULL || numberOfBytes <= 0) {
		return 0;
	}

	// CRC
	//const u16t POLYNOMIAL = 0x131; //P(x)=x^8+x^5+x^4+1 = 100110001
	uint8_t bit, crc;
	size_t byteCtr;
	crc = 0;

	//calculates 8-Bit checksum with given polynomial
	for (byteCtr = 0; byteCtr < numberOfBytes; ++byteCtr) { 
		crc ^= (data[byteCtr]);
		for (bit = 8; bit > 0; --bit) {
			if (crc & 0x80) {
				crc = (crc << 1) ^ 0x131;

			} else {
				crc = (crc << 1);
			}
		}
	}

	return (crc);
}
