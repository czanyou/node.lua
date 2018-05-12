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

static const char *memfind (const char *s1, size_t l1, const char *s2, size_t l2) {
  if (l2 == 0) return s1;  /* empty strings are everywhere */
  else if (l2 > l1) return NULL;  /* avoids a negative 'l1' */
  else {
    const char *init;  /* to search for a '*s2' inside 's1' */
    l2--;  /* 1st char will be checked by 'memchr' */
    l1 = l1-l2;  /* 's2' cannot be found after that */
    while (l1 > 0 && (init = (const char *)memchr(s1, *s2, l1)) != NULL) {
      init++;   /* 1st char is already checked */
      if (memcmp(init, s2+1, l2) == 0)
        return init-1;
      else {  /* correct 'l1' and 's1' to try again */
        l1 -= init-s1;
        s1 = init;
      }
    }
    return NULL;  /* not found */
  }
}

static void *memrchr(const void *s, int c, size_t n)
{
	const char* begin = (const char*) s;
	char* ptr = (char*) s + n - 1;

	while (ptr >= begin) {
		if (*ptr == c) {
			return ptr;
		}

		ptr--;
	}

	return NULL;
}

static const char *memrfind (const char *s1, size_t l1, const char *s2, size_t l2) {
  if (l2 == 0) return s1;  /* empty strings are everywhere */
  else if (l2 > l1) return NULL;  /* avoids a negative 'l1' */
  else {
    const char *init;  /* to search for a '*s2' inside 's1' */
    l1 = l1 - l2;  /* 's2' cannot be found after that */

	const char* begin = (const char*) s1;
	char* ptr = (char*) s1 + l1;

    while (ptr >= begin) {
		if (*ptr == *s2) {
			if (memcmp(ptr, s2, l2) == 0) {
        		return ptr;
			}
		}

		ptr--;
	}
    
    return NULL;  /* not found */
  }
}

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

static int  buffer_get_size(luv_buffer_t* buffer)
{
	if ((buffer == NULL) || (buffer->data == NULL) || (buffer->length <= 0)) {
		return 0;
	}

	return (buffer->limit - buffer->position);
}

static int buffer_expand(luv_buffer_t* buffer, int size)
{
	if (size == 0) {
		return 0;
	}

	int newLimit = (buffer->limit + size);
	if (newLimit < buffer->position) {
        return 0;

	} else if (newLimit > (buffer->length + 1)) {
        return 0;
	}

	buffer->limit = newLimit;

    if (buffer->limit == buffer->position) {
        buffer->limit = 1;
		buffer->position = 1;
	}

    return size;
}

static int  buffer_get_length(luv_buffer_t* buffer, int offset, int end)
{
	if ((buffer == NULL) || (buffer->data == NULL) || (buffer->length <= 0)) {
		return 0;
	}

	if (offset < 1) {
		offset = 1;
	}

	if (end < 1) {
		end = buffer_get_size(buffer);
	}

	return (end - offset) + 1;
}

static char* buffer_get_data(luv_buffer_t* buffer, int offset)
{
	if ((buffer == NULL) || (buffer->data == NULL) || (buffer->length <= 0)) {
		return NULL;
	}

	if (offset < 1) {
		offset = 1;
	}

	if (offset > buffer_get_size(buffer)) {
		return NULL;
	}

	return buffer->data + (buffer->position - 1) + (offset - 1);
}

static int buffer_index_of(luv_buffer_t* buffer, const char* data, int size, int offset)
{
	char* destBuffer = buffer_get_data(buffer, offset);
	int destSize = buffer_get_size(buffer);

	const char* find = memfind(destBuffer, destSize, data, size);
	if (find) {
		return find - destBuffer + 1;
	}

	return -1;
}

static int buffer_last_index_of(luv_buffer_t* buffer, const char* data, int size, int offset)
{
	char* destBuffer = buffer_get_data(buffer, offset);
	int destSize = buffer_get_size(buffer);

	const char* find = memrfind(destBuffer, destSize, data, size);
	if (find) {
		return find - destBuffer + 1;
	}

	return -1;
}

static int buffer_copy(luv_buffer_t* buffer, luv_buffer_t* source, int targetStart, int sourceStart, int sourceEnd)
{
	char* destBuffer = buffer_get_data(buffer, targetStart);
	char* srcBuffer  = buffer_get_data(source, sourceStart);

	int length = buffer_get_length(source, sourceStart, sourceEnd);
	if (length <= 0) {
		return 0;
	}

	if ((destBuffer == NULL) || (srcBuffer == NULL)) {
		return 0;
	}

	// copy
	memcpy(destBuffer, srcBuffer, length);
	return length;
}

static int buffer_compare(luv_buffer_t* buffer, luv_buffer_t* source, int targetStart, int targetEnd, int sourceStart, int sourceEnd)
{
	lua_Integer ret = 0;

	char* destBuffer = buffer_get_data(buffer, targetStart);
	char* srcBuffer  = buffer_get_data(source, sourceStart);

	int destLength = buffer_get_length(buffer, targetStart, targetEnd);
	int srcLength  = buffer_get_length(source, sourceStart, sourceEnd);
		
	if (destLength <= 0 || srcLength <= 0) {
		return 0;
	}

	if ((destBuffer == NULL) || (srcBuffer == NULL)) {
		return 0;
	}

	if (destLength > srcLength) {
		return memcmp(destBuffer, srcBuffer, srcLength);

	} else {
		return memcmp(destBuffer, srcBuffer, destLength);
	}
}

static int buffer_fill(luv_buffer_t* buffer, int value, int targetStart, int targetEnd)
{
	int length = buffer_get_length(buffer, targetStart, targetEnd);
	char* destBuffer = buffer_get_data(buffer, targetStart);
	if (destBuffer == NULL || length <= 0) {
		return -2;
	}

	memset(destBuffer, value, length);
	return length;
}

static int buffer_get_byte(luv_buffer_t* buffer, int targetStart)
{
	char* destBuffer = buffer_get_data(buffer, targetStart);
	if (destBuffer) {
		return (unsigned char)(*destBuffer);
	}

	return 0;
}


static char* buffer_get_bytes(luv_buffer_t* buffer, int targetStart, int *length)
{
	char* destBuffer = buffer_get_data(buffer, targetStart);
	if (destBuffer && length) {
		int totalSize = buffer_get_length(buffer, targetStart, 0);

		if (*length < 1) {
			*length = totalSize;
		}

		if (*length <= totalSize) {
			return destBuffer;
		}
	}

	return NULL;
}

static int buffer_compress(luv_buffer_t* buffer)
{
	if (buffer == NULL) {
		return 0;

	} else if (buffer->position == buffer->limit) {
		return 0;

	} else if (buffer->position <= 1) {
		return 0;
	}

	char* destBuffer = buffer_get_data(buffer, 1);
	char* srcBuffer  = buffer_get_data(buffer, buffer->position);
	int length = buffer_get_size(buffer);

	memmove(destBuffer, srcBuffer, length);

	buffer->position = 1;
	buffer->limit    = length + 1;

	return length;
}

static int buffer_move(luv_buffer_t* buffer, int targetStart, int offset, int length)
{
	char* destBuffer = buffer_get_data(buffer, targetStart);
	char* srcBuffer  = buffer_get_data(buffer, offset);

	int position = (targetStart > offset) ? targetStart : offset;
	int remainSize = buffer_get_length(buffer, position, 0);
	// printf("buffer_move: %d, %d, %d - %d, %d\r\n", targetStart, offset, length, position, remainSize);

	if (length > remainSize) {
		return 0;
	}

	// move
	memmove(destBuffer, srcBuffer, length);
	return length;
}

static int buffer_put_byte(luv_buffer_t* buffer, int targetStart, int value)
{
	char* destBuffer = buffer_get_data(buffer, targetStart);
	if (destBuffer) {
		*destBuffer = (unsigned char)value;
		return 1;
	}

	return 0;
}

static int buffer_put_bytes(luv_buffer_t* buffer, int targetStart, char* source_data, int data_size)
{
	if (source_data == NULL || data_size <= 0) {
		return 0;
	}

	char* destBuffer = buffer_get_data(buffer, targetStart);
	if (destBuffer == NULL) {
		return 0;
	}

	int remainSize = buffer_get_length(buffer, targetStart, 0);
	if (data_size > remainSize) {
		data_size = remainSize;
	}

	memcpy(destBuffer, source_data, data_size);
	return data_size;
}

static int  buffer_skip(luv_buffer_t* buffer, int size)
{
	if (size == 0) {
		return 0;
	}

	int newPosition = (buffer->position + size);
	if (newPosition < 1) {
        return 0;

	} else if (newPosition > (buffer->limit)) {
        return 0;
	}

	buffer->position = newPosition;

    if (buffer->limit == buffer->position) {
        buffer->limit = 1;
		buffer->position = 1;
	}

    return size;
}

