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
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <math.h>

#include "media_queue.h"

queue_buffer_t* queue_buffer_malloc(int length)
{
	queue_buffer_t* buffer = malloc(sizeof(queue_buffer_t));
	memset(buffer, 0, sizeof(queue_buffer_t));
	buffer->length = length;
	buffer->data   = malloc(length);
	return buffer;
}

queue_buffer_t* queue_buffer_malloc2(uint8_t* data, int length)
{
	queue_buffer_t* buffer = malloc(sizeof(queue_buffer_t));
	memset(buffer, 0, sizeof(queue_buffer_t));
	buffer->length = length;
	buffer->data   = data;
	return buffer;
}

void queue_buffer_free(queue_buffer_t* buffer)
{
	if (buffer == NULL) {
		return;
	}

	if (buffer->data) {
		free(buffer->data);
	}

	free(buffer);
}

int queue_init(queue_t* self, int length)
{
	if (length <= 0) {
		length = 512;
	}

	self->data 		= malloc(sizeof(void*) * length);
	self->length 	= length;
	self->head 		= 0;
	self->tail 		= 0;
	self->flags 	= 0;

	uv_mutex_init(&self->lock);
	return 0;
}

int queue_lock(queue_t* self)
{
	if (self) {
		uv_mutex_lock(&self->lock);
	}
	return 0;
}

int queue_unlock(queue_t* self)
{
	if (self) {
		uv_mutex_unlock(&self->lock);
	}
	return 0;	
}

int queue_size(queue_t* self)
{
	queue_lock(self);

	int ret = 0;
	if (self->head >= self->tail) {
		ret = self->head - self->tail;

	} else {
		ret = self->length - self->tail + self->head;
	}

	queue_unlock(self);

	return ret;
}

int queue__is_empty(queue_t* self)
{
	return self->head == self->tail;
}

int queue__is_full(queue_t* self)
{
	int head = (self->head + 1);
	if (head >= self->length) {
		head = 0;
	}

	return head == self->tail;
}

int queue_is_empty(queue_t* self)
{
	queue_lock(self);
	int ret = queue__is_empty(self);
	queue_unlock(self);

	return ret;
}

int queue_is_full(queue_t* self)
{
	queue_lock(self);
	int ret = queue__is_full(self);
	queue_unlock(self);

	return ret;
}

int queue_push(queue_t* self, void* data)
{
	queue_lock(self);

	int ret = -1;
	if (!queue__is_full(self)) {
		self->data[self->head] = data;
		int head = (self->head + 1);
		self->head = (head >= self->length) ? 0 : head;

		ret = 0;
	}

	queue_unlock(self);

	return ret;
}

void* queue_pop(queue_t* self)
{
	queue_lock(self);

	void* data = NULL;
	if (!queue__is_empty(self)) {
		data = self->data[self->tail];
		self->data[self->tail] = NULL;

		int tail = (self->tail + 1);
		self->tail = (tail >= self->length) ? 0 : tail;
	}

	queue_unlock(self);

	return data;
}

