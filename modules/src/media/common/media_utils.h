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
#ifndef _NS_VISION_MEDIA_UTILS_H
#define _NS_VISION_MEDIA_UTILS_H

#include "base_types.h"

//_____________________________________________________________________________
///////////////////////////////////////////////////////////////////////////////
// Log

void LogWrite( uint32_t level, LPCSTR file, int line, LPCSTR function, LPCSTR fmt, ... );

#ifdef _WIN32

/** Send an ERROR log message. */
#define LOG_E(fmt, ...) \
	LogWrite(4, __FILE__, __LINE__, __FUNCTION__, fmt, __VA_ARGS__);

/** Send a WARN log message. */
#define LOG_W(fmt, ...) \
	LogWrite(3, __FILE__, __LINE__, __FUNCTION__, fmt, __VA_ARGS__);

/** Send an INFO log message. */
#define LOG_I(fmt, ...) \
	LogWrite(2, __FILE__, __LINE__, __FUNCTION__, fmt, __VA_ARGS__);

/** Send a DEBUG log message. */
#define LOG_D(fmt, ...) \
	LogWrite(1, __FILE__, __LINE__, __FUNCTION__, fmt, __VA_ARGS__);

#else

 /** Send an ERROR log message. */
#define LOG_E(fmt, args...) \
	LogWrite(4, __FILE__, __LINE__, __FUNCTION__, fmt, ##args);

/** Send a WARN log message. */
#define LOG_W(fmt, args...) \
	LogWrite(3, __FILE__, __LINE__, __FUNCTION__, fmt, ##args);

/** Send an INFO log message. */
#define LOG_I(fmt, args...) \
	LogWrite(2, __FILE__, __LINE__, __FUNCTION__, fmt, ##args);

/** Send a DEBUG log message. */
#define LOG_D(fmt, args...) \
	LogWrite(1, __FILE__, __LINE__, __FUNCTION__, fmt, ##args);

#endif

INT64 MediaGetTickCount();

#endif // _NS_VISION_MEDIA_UTILS_H
