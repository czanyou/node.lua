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
#include "luv.h"

#include "lthreadpool.h"


//////////////////////////////////////////////////////////////////////////
// thread arg

static int luv_thread_arg_set(lua_State* L, luv_thread_arg_t* args, int idx, int top, int flags) {
  int i;
  idx = idx > 0 ? idx : 1;
  i = idx;
  while (i <= top && i <= LUV_THREAD_MAXNUM_ARG + idx)
  {
    luv_val_t *arg = args->argv + i - idx;
    arg->type = lua_type(L, i);
    switch (arg->type)
    {
    case LUA_TNIL:
      break;
    case LUA_TBOOLEAN:
      arg->val.boolean = lua_toboolean(L, i);
      break;
    case LUA_TNUMBER:
      arg->val.num = lua_tonumber(L, i);
      break;
    case LUA_TLIGHTUSERDATA:
      arg->val.userdata = lua_touserdata(L, i);
      break;
    case LUA_TSTRING:
    {
      const char* p = lua_tolstring(L, i, &arg->val.str.len);
      arg->val.str.base = (const char*)malloc(arg->val.str.len);
      if (arg->val.str.base == NULL)
      {
        perror("out of memory");
        return 0;
      }
      memcpy((void*)arg->val.str.base, p, arg->val.str.len);
      break;
    }
    case LUA_TUSERDATA:
    default:
      fprintf(stderr, "Error: thread arg not support type '%s' at %d",
        lua_typename(L, arg->type), i);
      exit(-1);
      break;
    }
    i++;
  }
  args->argc = i - idx;
  return args->argc;
}

static void luv_thread_arg_clear(lua_State* L, luv_thread_arg_t* args, int flags) {
  int i;
  if (args->argc == 0)
    return;

  for (i = 0; i < args->argc; i++) {
    const luv_val_t* arg = args->argv + i;
    switch (arg->type) {
    case LUA_TSTRING:
      free((void*)arg->val.str.base);
      break;
    case LUA_TUSERDATA:
    default:
      break;
    }
  }
  memset(args, 0, sizeof(*args));
  args->argc = 0;
}

static int luv_thread_arg_push(lua_State* L, const luv_thread_arg_t* args, int flags) {
  int i = 0;
  while (i < args->argc) {
    const luv_val_t* arg = args->argv + i;
    switch (arg->type) {
    case LUA_TNIL:
      lua_pushnil(L);
      break;
    case LUA_TBOOLEAN:
      lua_pushboolean(L, arg->val.boolean);
      break;
    case LUA_TLIGHTUSERDATA:
      lua_pushlightuserdata(L, arg->val.userdata);
      break;
    case LUA_TNUMBER:
      lua_pushnumber(L, arg->val.num);
      break;
    case LUA_TSTRING:
      lua_pushlstring(L, arg->val.str.base, arg->val.str.len);
      break;
    case LUA_TUSERDATA:
    default:
      fprintf(stderr, "Error: thread arg not support type %s at %d",
        lua_typename(L, arg->type), i + 1);
    }
    i++;
  };
  return i;
}

//////////////////////////////////////////////////////////////////////////
// message queue

typedef struct queue_message_s
{
	luv_thread_arg_t arg;
	struct queue_message_s* next;
} queue_message_t;

/** 
 * 
 * 代表一个消息队列。
 */
typedef struct queue_s
{
	char* name;			/* queue name */
	int async_callback; /* ref, call when async message received */
	int bucket;			/* bucket */
	int _msg_count;		/* message _msg_count */
	int _msg_limit;		/* message limit */
	int _ref_count;		/* refs */

	lua_State* L;       /* Lua vm */
	queue_message_t* _msg_head;
	queue_message_t* _msg_tail;

	struct queue_s* next; 
	struct queue_s* prev;

	uv_async_t async;		/* async handler */
	uv_cond_t  recv_sig;	/* recv cond  */
	uv_cond_t  send_sig;	/* send cond */
	uv_mutex_t lock;		/* lock */

} queue_t;


//////////////////////////////////////////////////////////////////////////
// queue

static void queue_list_remove(queue_t* queue);
static queue_message_t* 
			queue_recv	(queue_t* queue, int timeout);
static int  queue_lock	(queue_t* queue);
static int  queue_unlock(queue_t* queue);
static long queue_addref(queue_t* queue);
static long queue_unref (queue_t* queue);

static queue_message_t* queue_message_pop(queue_t* queue)
{
	if (queue == NULL || queue->_msg_count <= 0) {
		return NULL;
	}

	queue_message_t* msg = queue->_msg_head;
	if (msg) {
		queue->_msg_head = msg->next;
		queue->_msg_count--;
		
		msg->next = NULL;

		if (queue->_msg_head == NULL) {
			queue->_msg_tail = NULL;
			queue->_msg_count = 0;
		}
	}
	
	uv_cond_signal(&queue->send_sig);

	return msg;
}

static int queue_message_put(queue_t* queue, queue_message_t* msg)
{
	if (queue == NULL || msg == NULL) {
		return -1;
	}

	msg->next = NULL;

	// tail
	if (queue->_msg_tail) {
		queue->_msg_tail->next = msg;
	}
	queue->_msg_tail = msg;

	// head
	if (queue->_msg_head == NULL) {
		queue->_msg_head = msg;
	}

	queue->_msg_count++;
	uv_cond_signal(&queue->recv_sig);
	return 0;
}

static void queue_message_release(queue_t* queue, queue_message_t* message)
{
	lua_State* L = queue->L;
	if (L == NULL) {
		printf("null L");
		return;
	}

	if (message) {
		luv_thread_arg_clear(L, &(message->arg), 0);
		free(message);
		message = NULL;
	}
}

static void queue_async_callback(uv_async_t *handle)
{
	if (handle == NULL) {
		return;
	}

	queue_t* queue = (queue_t*)handle->data;
	if (queue == NULL) {
		printf("null queue");
		return;
	}

	lua_State* L = queue->L;
	if (L == NULL) {
		printf("null L");
		return;
	}

	queue_addref(queue);

	while (1) {
		queue_message_t* message = queue_recv(queue, 0);
		if (message == NULL) {
			break;
		}

		// callback
		lua_rawgeti(L, LUA_REGISTRYINDEX, queue->async_callback);
		if (lua_isnil(L, -1)) {
			queue_message_release(queue, message);
			continue;
		}

		// args
		int argc = luv_thread_arg_push(L, &(message->arg), 0);
		if (lua_pcall(L, argc, 0, 0)) {
			fprintf(stderr, "Uncaught Error in thread async: %s\n", lua_tostring(L, -1));
		}

		queue_message_release(queue, message);
		message = NULL;
	}

	queue_unref(queue);
}

static queue_t* queue_create(const char* name, int limit)
{
	if (name == NULL || *name == '\0') {
		return NULL;
	}

	size_t name_len = strlen(name);
	queue_t* queue = (queue_t*)malloc(sizeof(queue_t) + name_len + 1);
	queue->name = (char*)queue + sizeof(queue_t);

	memcpy(queue->name, name, name_len + 1);
	queue->_msg_count 	= 0;
	queue->_msg_head 	= NULL;
	queue->_msg_limit 	= limit;
	queue->_msg_tail 	= NULL;
	queue->_ref_count 	= 1;
	queue->next 		= NULL;
	queue->prev 		= NULL;

	uv_mutex_init(&queue->lock);

	uv_cond_init(&queue->send_sig);
	uv_cond_init(&queue->recv_sig);

	// printf("queue_create: %s, limit=%d\n", name, limit);
	return queue;
}

static long queue_addref(queue_t* queue)
{
	long refs = -1;
	if (queue) {
		queue_lock(queue);
		refs = ++queue->_ref_count;
		queue_unlock(queue);
	}
	return refs;
}

static int queue_destroy(queue_t* queue)
{
	if (queue == NULL) {
		return -1;
	}

	// close async
	if (queue->async_callback != LUA_REFNIL) {
		uv_close((uv_handle_t*)&queue->async, NULL);
		queue->async_callback = LUA_REFNIL;
	}

	// clear message
	queue_message_t *msgs = queue->_msg_head;
	queue_message_t *last = NULL;

	// printf("queue_destroy: %s\n", queue->name);
	while (msgs) {
		last = msgs;
		msgs = msgs->next;
		queue_message_release(queue, last);
	}

	uv_mutex_destroy(&queue->lock);

	free(queue);
	queue = NULL;
	return 0;	
}

static int queue_lock(queue_t* queue)
{
	if (queue) {
		uv_mutex_lock(&queue->lock);
	}
	return 0;
}

/**
 * @param timeout 0 表示立即返回, 负数表示一直等待
 */
static queue_message_t* queue_recv(queue_t* queue, int timeout)
{
	if (queue == NULL) {
		return NULL;
	}

	queue_message_t* msg = NULL;

	queue_lock(queue);
	
	if (queue->_msg_limit >= 0) {
		queue->_msg_limit++;
		uv_cond_signal(&queue->send_sig);
	}

	// wait
	while (timeout != 0) {
		if (queue->_msg_count > 0) {
			break;
		}

		if (timeout > 0) {
			int64_t waittime = timeout;
			waittime = waittime * 1000000L;
			if (uv_cond_timedwait(&queue->recv_sig, &queue->lock, waittime) != 0) {
				break;
			}

		} else {
			uv_cond_wait(&queue->recv_sig, &queue->lock);
		}
	}

	// pop
	msg = queue_message_pop(queue);

	if (queue->_msg_limit > 0) {
		queue->_msg_limit--;
	}

	queue_unlock(queue);
	return msg;
}

/**
 * @param msg
 * @param timeout 0 表示立即返回, 负数表示一直等待
 */
static int queue_send(queue_t* queue, queue_message_t* msg, int timeout)
{
	if (queue == NULL || msg == NULL) {
		return 0;
	}

	queue_lock(queue);

	// wait
	while (timeout != 0) {
		if (queue->_msg_limit < 0 || queue->_msg_count < queue->_msg_limit) {
			break;
		}
		
		if (timeout > 0) {
			int64_t waittime = timeout;
			waittime = waittime * 1000000L;
			if (uv_cond_timedwait(&queue->send_sig, &queue->lock, waittime) != 0) {
				break;
			}

		} else {
			uv_cond_wait(&queue->send_sig, &queue->lock);
		}
	}

	// printf("queue: %d/%d", queue->_msg_limit, queue->_msg_count);
	if (queue->_msg_limit < 0 || queue->_msg_count < queue->_msg_limit) {
		queue_message_put(queue, msg);

	} else {
		msg = NULL;
	}

	queue_unlock(queue);
	return msg ? 1 : 0;
}

static int queue_unlock(queue_t* queue)
{
	if (queue) {
		uv_mutex_unlock(&queue->lock);
	}
	return 0;	
}

static long queue_unref(queue_t* queue)
{
	if (queue == NULL) {
		return -1;
	}

	long refs = -1;
	queue_lock(queue);
	refs = --queue->_ref_count;
	queue_unlock(queue);

	if (refs == 0) {
		queue_list_remove(queue);
		queue_destroy(queue);
	}

	return refs;
}

///////////////////////////////////////////////////////////////
// queue list

#define BUCKET_SIZE 16

struct queue_entry_t
{
	queue_t* head;
	queue_t* tail;
};

static int 					s_queue_count = -1;
static struct queue_entry_t s_queue_list[BUCKET_SIZE];
static uv_mutex_t 			s_queue_list_lock;

static int queue_list_init()
{
	if (s_queue_count < 0) {
		// printf("queue_list_init\r\n");

		uv_mutex_init(&s_queue_list_lock);

		s_queue_count = 0;
		memset(s_queue_list, 0, sizeof(s_queue_list));
	}

	return 0;
}

static int queue_list_hash(const char* name)
{
	if (name == NULL) {
		return 0;
	}

	int hash = 0;
	char ch;
	while ((ch = *name++) != 0) {
		hash += ch;
		hash &= 0xff;
	}

	return hash % BUCKET_SIZE;
}

static queue_t* queue_list_search(int bucket, const char* name)
{
	if (bucket < 0 || bucket >= BUCKET_SIZE) {
		return NULL;

	} else if (name == NULL) {
		return NULL;
	}

	queue_t* queue = s_queue_list[bucket].head;
	for (; queue; queue = queue->next) {
		if (strcmp(queue->name, name) == 0) {
			return queue;
		}
	}
	return NULL;
}

static int queue_list_add(queue_t* queue)
{
	if (queue == NULL) {
		return 0;
	}

	int hash = queue_list_hash(queue->name);
	//printf("queue_list_add: %s:%d\n", queue->name, hash);

	uv_mutex_lock(&s_queue_list_lock);
	if (queue_list_search(hash, queue->name)) {
		uv_mutex_unlock(&s_queue_list_lock);
		return 0;
	}

	struct queue_entry_t* entry = &s_queue_list[hash];

	queue->next 	= NULL;
	queue->bucket 	= hash;
	queue->prev 	= entry->tail;

	// tail
	if (entry->tail) {
		entry->tail->next = queue;
	}
	entry->tail = queue;

	// head
	if (!entry->head) {
		entry->head = queue;
	}

	s_queue_count++;

	uv_mutex_unlock(&s_queue_list_lock);
	return 1;
}

static queue_t* queue_list_get(const char* name)
{
	if (name == NULL) {
		return NULL;
	}

	int hash = queue_list_hash(name);
	queue_t* queue = NULL;

	uv_mutex_lock(&s_queue_list_lock);
	queue = queue_list_search(hash, name);
	if (queue) {
		queue_addref(queue);
	}
	uv_mutex_unlock(&s_queue_list_lock);
	return queue;
}

/** 删除一个消息队列. */
static void queue_list_remove(queue_t* queue)
{
	if (queue == NULL) {
		return;
	}

	queue_t* prev = queue->prev;
	queue_t* next = queue->next;
	int bucket    = queue->bucket;
	if (bucket < 0 || bucket >= BUCKET_SIZE) {
		return;
	}

	uv_mutex_lock(&s_queue_list_lock);

	if (prev) {
		prev->next = next;

	} else {
		s_queue_list[bucket].head = next;
	}

	if (next) {
		next->prev = prev;

	} else {
		s_queue_list[bucket].tail = prev;
	}

	queue->next = queue->prev = NULL;
	queue->bucket = -1;

	s_queue_count--;

	uv_mutex_unlock(&s_queue_list_lock);
}

