/***
 * The content of this file or document is CONFIDENTIAL and PROPRIETARY
 * to ChengZhen(Anyou).  It is subject to the terms of a
 * License Agreement between Licensee and ChengZhen(Anyou).
 * restricting among other things, the use, reproduction, distribution
 * and transfer.  Each of the embodiments, including this information and
 * any derivative work shall retain this copyright notice.
 *
 * Copyright (c) 2014-2015 ChengZhen(Anyou). All Rights Reserved.
 *
 */
#ifndef _NS_VISION_CORE_BASE_TYPES_H
#define _NS_VISION_CORE_BASE_TYPES_H

/**
这个头文件主要用于:

- 包含常用的系统库头文件
- 定义基本的数据类型
- 定义常用的宏常量

*/

/** 常用的 C 语言标准库头文件. */

#include <assert.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>

#include <ctype.h>
#include <errno.h>
#include <fcntl.h>
#include <math.h>
#include <string.h>

#ifdef _WIN32

/* Windows 独有的头文件 */
#include <WinSock2.h>
#include <time.h>

#else

/* 类 *nux 系统的常用头文件 */

#include <arpa/inet.h>		// inet_addr,inet_aton
#include <dirent.h>
#include <pthread.h>
#include <net/if.h>
#include <netdb.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <semaphore.h>
#include <signal.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <sys/un.h>
#include <sys/select.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <sys/times.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <syslog.h>
#include <unistd.h>

#if __linux

/* Linux 独有的头文件 */

#include <linux/soundcard.h>
#include <net/if_arp.h>
#include <sys/epoll.h>
#include <sys/reboot.h>
#include <sys/sysinfo.h>
#include <sys/vfs.h>
#include <dirent.h>
#include <mntent.h>
#endif

#endif

//_____________________________________________________________________________
///////////////////////////////////////////////////////////////////////////////
// API

#if defined(_WIN32)

#define snprintf			_snprintf
#define strncasecmp			_strnicmp

#elif __linux

#elif __IPHONE_OS_VERSION_MAX_ALLOWED
#define __iphone_os			1

#elif defined(__APPLE__)
#define __mac_os			1

#else 

#endif

//_____________________________________________________________________________
///////////////////////////////////////////////////////////////////////////////
// Types (platform dependent)
// 定义 WINAPI 风格的数据类型
#ifdef _WIN32

typedef unsigned long long	uint64_t;	///< 64bit uint
typedef unsigned int        uint32_t;	///< 32bit uint
typedef unsigned short      uint16_t;	///< 16bit uint
typedef unsigned char       uint8_t;	///< 8bit uint

#else

typedef unsigned long long	QWORD;	///< 64bit uint
typedef unsigned int        DWORD;	///< 32bit uint
typedef unsigned short      WORD;	///< 16bit uint
typedef unsigned char       BYTE;	///< 8bit uint

typedef unsigned long		ULONG;
typedef unsigned int        UINT;	///< 32bit uint

typedef signed int          INT;	///< 32bit int
typedef signed long long	INT64;	///< 64bit int

typedef const char *		LPCSTR;
typedef char *				LPSTR;

#ifdef __linux
typedef int                 BOOL;

#else
typedef signed char         BOOL;
#endif

#endif

#ifdef __cplusplus
typedef wchar_t				WCHAR;
typedef const wchar_t *		LPCWSTR;		
typedef wchar_t *			LPWSTR;	
#endif

//_____________________________________________________________________________
///////////////////////////////////////////////////////////////////////////////
// Quick functions

#ifndef MAKEWORD
#define MAKEWORD(a, b)      ((WORD)(((BYTE)(a)) | ((WORD) ((BYTE)(b))) << 8))
#define MAKELONG(a, b)      ((LONG)(((WORD)(a)) | ((DWORD)((WORD)(b))) << 16))
#define LOWORD(l)           ((WORD)(l))
#define HIWORD(l)           ((WORD)(((DWORD)(l) >> 16) & 0xFFFF))
#define LOBYTE(w)           ((BYTE)((w) & 0xFF))
#define HIBYTE(w)           ((BYTE)(((WORD)(w) >> 8) & 0xFF))
#endif

#ifndef MAX
#define MAX(a, b) ((a) > (b) ? (a) : (b))
#endif

#ifndef MIN
#define MIN(a, b) ((a) < (b) ? (a) : (b))
#endif

#ifndef RANGE
#define RANGE(p, min, max) ((p) < (min) ? (min) : ((p) > (max) ? (max) : (p) ))
#endif

//_____________________________________________________________________________
///////////////////////////////////////////////////////////////////////////////
// Constants

#ifndef FALSE
#  define FALSE             0
#endif

#ifndef TRUE
#  define TRUE              1
#endif

#ifndef MAX_PATH
#  define MAX_PATH			256
#endif

#endif // !defined(_NS_VISION_CORE_BASE_TYPES_H)
