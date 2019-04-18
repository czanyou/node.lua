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
#include "message.c"

///////////////////////////////////////////////////////////////
// 

static void luv_usage_error(lua_State* L, const char* usage)
{
	lua_pushstring(L, usage);
	lua_error(L);
}

static const char* luv_arg_string(lua_State* L, int index, const char *def_val, const char* usage)
{
	if (lua_gettop(L) >= index) {
		const char* str = lua_tostring(L, index);
		if (str) {
			return str;
		}

	} else if (def_val) {
		return def_val;
	}

	luv_usage_error(L, usage);
	return NULL;
}

static int luv_arg_integer(lua_State* L, int index, int optional, int def_val, const char* usage)
{
	if (lua_gettop(L) >= index) {
		if (lua_isnumber(L, index)) {
			return (int)lua_tointeger(L, index);
		}

	} else if (optional) {
		return def_val;
	}

	luv_usage_error(L, usage);
	return 0;
}

///////////////////////////////////////////////////////////////
// 

#define LUV_QUEUE "uv_queue_t"

typedef struct luv_queue_s
{
	queue_t* queue;
} luv_queue_t;

static const char* queue_usage_send = "chan:send(string|number|boolean)";
static const char* queue_usage_recv = "chan:recv(timeout = -1)";
static const char* queue_usage_new  = "chan.new(name, limit = 0, callback)";
static const char* queue_usage_get  = "chan.get(name)";

static luv_queue_t* luv_queue_check(lua_State* L, int index)
{
	return (luv_queue_t*)luaL_checkudata(L, index, LUV_QUEUE);
}

static int luv_queue_close(lua_State* L)
{
	luv_queue_t* luv_queue = luv_queue_check(L, 1);
	if (luv_queue == NULL || luv_queue->queue == NULL) {
		return 0;
	}

	queue_t* queue = luv_queue->queue;
	luv_queue->queue = NULL;

	queue_unref(queue);
	return 0;
}

static int luv_queue_refs(lua_State* L)
{
	luv_queue_t* luv_queue = luv_queue_check(L, 1);
	if (luv_queue == NULL || luv_queue->queue == NULL) {
		return -1;
	}

	lua_pushinteger(L, luv_queue->queue->_ref_count);
	return 1;
}

static int luv_queue_push(lua_State* L, queue_t* queue)
{
	luv_queue_t* object = NULL;
	object = lua_newuserdata(L, sizeof(*object));
	memset(object, 0, sizeof(*object));
	object->queue = queue;

	luaL_getmetatable(L, LUV_QUEUE);
	lua_setmetatable(L, -2);

	return 0;
}

static int luv_queue_recv(lua_State* L)
{
	luv_queue_t* luv_queue = luv_queue_check(L, 1);
	if (luv_queue == NULL || luv_queue->queue == NULL) {
		return 0;
	}

	queue_t* queue = luv_queue->queue;

	int timeout = luv_arg_integer(L, 2, 1, 0, queue_usage_recv);
	queue_message_t* msg = queue_recv(queue, timeout);
	if (msg) {
		int ret = luv_thread_arg_push(L, &(msg->arg), 0);
		queue_message_release(queue, msg);
		return ret;

	} else {
		lua_pushnil(L);
		return 1;
	}
}

static int luv_queue_send(lua_State* L)
{
	luv_queue_t* luv_queue = luv_queue_check(L, 1);
	if (luv_queue == NULL || luv_queue->queue == NULL) {
		return 0;
	}

	queue_t* queue = luv_queue->queue;

	if (lua_gettop(L) < 2) {
		luv_usage_error(L, queue_usage_send);
	}

	queue_message_t* msg = (queue_message_t*)malloc(sizeof(queue_message_t));
	luv_thread_arg_set(L, &msg->arg, 2, lua_gettop(L), 1);
	// printf("chan_send: %d\r\n", ret);

	int ret = queue_send(queue, msg, 0);
	if (ret) {
		// notify
		if (queue->async_callback != LUA_REFNIL) {
			uv_async_send(&(queue->async));
		}

	} else {
		queue_message_release(queue, msg);
	}

	lua_pushboolean(L, ret);
	return 1;
}

static int luv_queue_stop(lua_State* L)
{
	luv_queue_t* luv_queue = luv_queue_check(L, 1);
	if (luv_queue == NULL || luv_queue->queue == NULL) {
		return 0;
	}

	queue_t* queue = luv_queue->queue;
	//printf("luv_queue_stop: %s\r\n", queue->name);

	queue_lock(queue);
	if (queue->async_callback != LUA_REFNIL) {
		uv_close((uv_handle_t*)&queue->async, NULL);
		queue->async_callback = LUA_REFNIL;
	}
	queue_unlock(queue);
	return 0;
}

static int luv_queue_tostring(lua_State* L)
{
	luv_queue_t* luv_queue = luv_queue_check(L, 1);
	lua_pushfstring(L, "%s: %p", LUV_QUEUE, luv_queue);
	return 0;
}

static const luaL_Reg luv_queue_methods[] = {
	{ "close", 	luv_queue_close },
	{ "recv", 	luv_queue_recv  },
	{ "send", 	luv_queue_send  },
	{ "stop", 	luv_queue_stop  },
	{ "refs", 	luv_queue_refs  },

	{ NULL,   	NULL }
};

static void luv_queue_init(lua_State* L) {
	luaL_newmetatable(L, LUV_QUEUE);

    luaL_newlib(L, luv_queue_methods);
    lua_setfield(L, -2, "__index");

	lua_pushcfunction(L, luv_queue_close);
	lua_setfield(L, -2, "__gc");

	lua_pushcfunction(L, luv_queue_tostring);
	lua_setfield(L, -2, "__tostring");	

	lua_pop(L, 1);
}

///////////////////////////////////////////////////////////////
// message

static int luv_queue_get(lua_State* L)
{
	const char* name = luv_arg_string(L, 1, NULL, queue_usage_get);
	queue_t* queue = queue_list_get(name);
	if (queue) {
		luv_queue_push(L, queue);
		return 1;

	} else {
		lua_pushnil(L);
		lua_pushstring(L, "not found");
		return 2;
	}
}

static int luv_queue_new(lua_State* L)
{
	const char* name = luv_arg_string (L, 1, NULL, queue_usage_new);
	int limit        = luv_arg_integer(L, 2, 1, 0, queue_usage_new);

	queue_t* queue = queue_create(name, limit);

	if (lua_gettop(L) >= 3) {
		// async callback
		lua_pushvalue(L, 3);
		queue->async_callback = luaL_ref(L, LUA_REGISTRYINDEX);

		uv_async_init(luv_loop(L), &queue->async, queue_async_callback);
		queue->async.data = queue;

	} else {
		queue->async_callback = LUA_REFNIL;
		queue->async.data = NULL;
	}

	queue->L = L;

	if (!queue_list_add(queue)) {
		queue_destroy(queue);
		lua_pushnil(L);
		lua_pushstring(L, "queue name duplicated");
		return 2;
	}

	luv_queue_push(L, queue);
	return 1;
}

static const luaL_Reg lmessage_functions[] = {
  	// message.c
  	{ "new_queue", luv_queue_new },
  	{ "get_queue", luv_queue_get },
  	{ NULL, 	   NULL}
};

LUALIB_API int luaopen_lmessage(lua_State *L) {
  	luaL_newlib(L, lmessage_functions);

  	queue_list_init();
  	luv_queue_init(L);

  	return 1;
}
