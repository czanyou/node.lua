/*
 *  Copyright 2015 The Lnode Authors. All Rights Reserved.
 *
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 *
 */

#include "buffer.h"


static int buffer_init(luv_buffer_t* buffer, int length)
{
	if (buffer == NULL) {
		return 0;
	}

	buffer->data 	 		= NULL;
	buffer->flags 	 		= 0;
	buffer->limit 			= 1;
	buffer->position 		= 1;
	buffer->length 	 		= 0;
	buffer->time_seconds 	= 0;
	buffer->time_useconds 	= 0;
	buffer->type 	 		= LUV_BUFFER_FLAG;
	buffer->lock 			= NULL;

	if (length > 0) {
		buffer->data = malloc(length + 2);
		buffer->length = length;
	}

	buffer->lock = malloc(sizeof(uv_mutex_t));
	uv_mutex_init(buffer->lock);

	return 1;
}

static int buffer_lock(luv_buffer_t* buffer)
{
	if (buffer && buffer->lock) {
		uv_mutex_lock(buffer->lock);
		return 1;
	}

	return 0;
}

static int buffer_unlock(luv_buffer_t* buffer)
{
	if (buffer && buffer->lock) {
		uv_mutex_unlock(buffer->lock);
		return 1;
	}

	return 0;
}

static int buffer_close(luv_buffer_t* buffer)
{
	if (buffer && buffer->data) {
		free(buffer->data);

		//printf("ppp_buffer_free: %d\r\n", buffer->length);

		buffer->data 	 = NULL;
		buffer->length 	 = 0;
		buffer->position = 1;
		buffer->limit 	 = 1;

		uv_mutex_t* lock = buffer->lock;
		buffer->lock = NULL;

		if (lock) {
			uv_mutex_destroy(lock);
			free(lock);
		}

		return 1;
	}

	return 0;	
}

static int buffer_copy(luv_buffer_t* buffer, luv_buffer_t* source, int position, int offset, int length)
{
	lua_Integer ret = 0;
	
	if (buffer == NULL || buffer->data == NULL) {
		return 0;
	}

	if (source == NULL || source->data == NULL) {
		return 0;
	}

	lua_Integer buffer_size = buffer->length;
	lua_Integer source_size = source->length;

	if (position < 1 || position > buffer_size) {
		return 0;

	} else if (offset < 1 || offset > source_size) {
		return 0;

	} else if (length <= 0) {
		return 0;

	} else if (position + length > buffer_size + 1) {
		return 0; // 缓存区不足

	} else if (offset + length > source_size + 1) {
		return 0; // 要复制的数据不足	
	}		

	char* dest_buffer = buffer->data + position - 1;
	char* src_buffer  = source->data + offset - 1;
	memcpy(dest_buffer, src_buffer, length);
	return length;
}

static int buffer_fill(luv_buffer_t* buffer, int value, int position, int length)
{
	if (buffer == NULL || buffer->data == NULL) {
		return 0;
	}

	int bufferSize = buffer->length;
	if (bufferSize <= 0) {
		return -1;

	} else if (length <= 0) {
		return -2;

	} else if (position < 1 || position + length > bufferSize + 1) {
		return -3;
	}

	memset(buffer->data + position - 1, value, length);
	return length;
}


static int buffer_get_byte(luv_buffer_t* buffer, int position)
{
	if (buffer && buffer->data) {
		// position 为 1 到 size
		if (position >= 1 && position <= buffer->length) {
			char* data = buffer->data + position - 1;
			return (unsigned char)(*data);
		}
	}

	return 0;
}


static char* buffer_get_bytes(luv_buffer_t* buffer, int position, int length, int limit)
{
	if (buffer && buffer->data) {
		if (length > 0 && (position >= 1) && (position <= limit)) {
			char* data = buffer->data + position - 1;
			return data;
		}
	}

	return NULL;
}

static int buffer_move(luv_buffer_t* buffer, int position, int offset, int length)
{
	if (buffer == NULL ||  buffer->data == NULL) {
		return 0;
	}

	lua_Integer buffer_size = buffer->length;

	if (position < 1 || position > buffer_size) {
		return 0;

	} else if (offset < 1 || offset > buffer_size) {
		return 0;

	} else if (length <= 0) {
		return 0;

	} else if (position + length > buffer_size + 1) {
		return 0;

	} else if (offset + length > buffer_size + 1) {
		return 0;			
	}

	char* dest_buffer = buffer->data + position - 1;
	char* src_buffer  = buffer->data + offset - 1;
	memmove(dest_buffer, src_buffer, length);
	return length;
}

static int buffer_put_byte(luv_buffer_t* buffer, int position, int value)
{
	if (buffer && buffer->data) {
		// position, offset 为 1 到 size
		if (position >= 1 && position <= buffer->length) {
			char* data = buffer->data + position - 1;
			*data = (unsigned char)value;
			return 1;
		}
	}

	return 0;
}

static int buffer_put_bytes(luv_buffer_t* buffer, int position, char* source_data, int data_size, int offset, int length)
{
	if (buffer == NULL || buffer->data == NULL) {
		return 0;
	}


	lua_Integer buffer_size = buffer->length;
	if (buffer_size <= 0) {
		return -1;

	} else if (length <= 0) {
		return -2;

	} else if (position < 1 || position + length > buffer_size + 1) {
		return -3;

	} else if (data_size <= 0) {
		return -4;

	} else if (offset < 1 || offset + length > data_size + 1) {
		return -5;
	}

	char* dest_buffer = buffer->data + position - 1;
	memcpy(dest_buffer, source_data + offset - 1, length);
	return length;
}

