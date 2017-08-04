#ifndef LUTILS_BUFFER_H
#define LUTILS_BUFFER_H

#include "uv.h"

#define LUV_BUFFER_FLAG 100

#define LUV_BUFFER "luv_buffer_t"

typedef struct luv_buffer_s {
	int   type;
	char* data;
	int   length;
	int   position;
	int   limit;
	int   flags;
	int   time_seconds;
	int   time_useconds;
	uv_mutex_t* lock;		/* lock */

} luv_buffer_t;

#endif // LUTILS_BUFFER_H
