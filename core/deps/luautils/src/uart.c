#include <errno.h>
#include <fcntl.h>

#ifndef _WIN32

#include <termios.h>
#include <unistd.h>

static unsigned baud_to_constant(unsigned baudRate)
{
    switch (baudRate)
    {
    case 50:
        return B50;
    case 75:
        return B75;
    case 110:
        return B110;
    case 134:
        return B134;
    case 150:
        return B150;
    case 200:
        return B200;
    case 300:
        return B300;
    case 600:
        return B600;
    case 1200:
        return B1200;
    case 1800:
        return B1800;
    case 2400:
        return B2400;
    case 4800:
        return B4800;
    case 9600:
        return B9600;
    case 19200:
        return B19200;
    case 38400:
        return B38400;
    case 57600:
        return B57600;
    case 115200:
        return B115200;
    case 230400:
        return B230400;
    }
    return B0;
}

static int databits_to_constant(int dataBits)
{
    switch (dataBits)
    {
    case 8:
        return CS8;
    case 7:
        return CS7;
    case 6:
        return CS6;
    case 5:
        return CS5;
    }
    return -1;
}

int lnode_uart_set(int fd, int baudRate, int dataBits)
{
    struct termios options;
    tcgetattr(fd, &options);
    options.c_cflag = CLOCAL | CREAD;
    options.c_cflag |= (tcflag_t)baud_to_constant(baudRate);
    options.c_cflag |= (tcflag_t)databits_to_constant(dataBits);
    options.c_iflag = IGNPAR;
    options.c_oflag = 0;
    options.c_lflag = 0;
    tcflush(fd, TCIFLUSH);
    tcsetattr(fd, TCSANOW, &options);

    return 0;
}

#endif
