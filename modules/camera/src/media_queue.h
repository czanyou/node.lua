#ifndef LUTILS_QUEUE_H
#define LUTILS_QUEUE_H

#include "uv.h"

#ifndef TRUE
#define TRUE 1
#endif

#ifndef FALSE
#define FALSE 0
#endif


#define LUV_QUEUE "luv_queue_t"

typedef struct queue_buffer_s {
	uint8_t* data;
	uint32_t  length;
	uint32_t  flags;
	int64_t timestamp;
	uint32_t  sequence;

} queue_buffer_t;

typedef struct queue_s {
	void** data;
	int   length;
	int   head;
	int   tail;
	int   flags;
	uv_mutex_t lock;		/* lock */

} queue_t;

int   queue_init	(queue_t* self, int length);
int   queue_size	(queue_t* self);
int   queue_is_empty(queue_t* self);
int   queue_is_full	(queue_t* self);
int   queue_push	(queue_t* self, void* data);
void* queue_pop		(queue_t* self);

queue_buffer_t* queue_buffer_malloc(int length);
queue_buffer_t* queue_buffer_malloc2(uint8_t* data, int length);

void queue_buffer_free(queue_buffer_t* buffer);

#endif
