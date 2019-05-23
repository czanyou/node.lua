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
#include <lua.h>
#include <lauxlib.h>

#include "ts_reader.h"


///////////////////////////////////////////////////////////////////////////////
// callback

static void lts_callback_release(lua_State* L, ts_reader_t* reader)
{
	if (reader == NULL) {
		return;
	}

	int callback = reader->fCallback;
	reader->fCallback = LUA_NOREF;

	if (callback != LUA_NOREF) {
  		luaL_unref(L, LUA_REGISTRYINDEX, callback);
  	}
}

static int lts_callback_check(lua_State* L, ts_reader_t* reader, int index) 
{
	if (reader == NULL) {
		return -1;
	}

  	luaL_checktype(L, index, LUA_TFUNCTION);
  	reader->fCallback = luaL_ref(L, LUA_REGISTRYINDEX);

  	return 0;
}

static void lts_callback_call(lua_State* L, ts_reader_t* reader, int nargs) 
{
	if (reader == NULL) {
		return;
	}

  	int ref = reader->fCallback;
  	if (ref == LUA_NOREF) {
    	lua_pop(L, nargs);
    	return;
 	}

    // Get the callback
    lua_rawgeti(L, LUA_REGISTRYINDEX, ref);

    // And insert it before the args if there are any.
    if (nargs) {
      	lua_insert(L, -1 - nargs);
    }

    if (lua_pcall(L, nargs, 0, -2 - nargs)) {
      	fprintf(stderr, "Uncaught error in TS reader callback: %s\n", lua_tostring(L, -1));
    }
}

///////////////////////////////////////////////////////////////////////////////
// ts

#define LUA_TS_READER "ts_reader_t"

static ts_reader_t* lts_reader_check(lua_State* L, int index)
{
	ts_reader_t* reader = luaL_checkudata(L, index, LUA_TS_READER);
	return reader;
}

int lts_reader_new(lua_State* L) 
{
	ts_reader_t* reader = NULL;
	reader = lua_newuserdata(L, sizeof(*reader));
	luaL_getmetatable(L, LUA_TS_READER);
	lua_setmetatable(L, -2);

	ts_reader_init(reader);

  	reader->fCallback 	= LUA_NOREF;
  	reader->fState 		= L;

	return 1;
}

int lts_reader_open(lua_State* L) 
{
	luaL_checktype(L, 1, LUA_TFUNCTION);
  	int callback = luaL_ref(L, LUA_REGISTRYINDEX);

	ts_reader_t* reader = NULL;
	reader = lua_newuserdata(L, sizeof(*reader));
	luaL_getmetatable(L, LUA_TS_READER);
	lua_setmetatable(L, -2);

	ts_reader_init(reader);

	reader->fCallback 	= callback;
  	reader->fState 		= L;

	return 1;
}

static int lts_reader_close(lua_State* L)
{
	int ret = 0;
	ts_reader_t* reader = lts_reader_check(L, 1);
	if (reader) {
		ret = 1;
	}

	lts_callback_release(L, reader);
	ts_reader_release(reader);

	lua_pushinteger(L, ret);
	return 1;
}

static int lts_reader_start(lua_State* L) 
{
	int ret = 0;
	ts_reader_t* reader = lts_reader_check(L, 1);

	lts_callback_check(L, reader, 2);
    
    lua_pushinteger(L, ret);
  	return 1;
}

static int lts_reader_tostring(lua_State* L)
{
	ts_reader_t* reader = lts_reader_check(L, 1);
    lua_pushfstring(L, "%s: %p", LUA_TS_READER, reader);
  	return 1;
}

static int lts_reader_read(lua_State* L)
{
	int ret = 0;
	ts_reader_t* reader = lts_reader_check(L, 1);

	size_t dataSize = 0;
	uint8_t* data = (uint8_t*)luaL_checklstring(L, 2, &dataSize);

	int flags = luaL_optinteger(L, 3, 0);

	ret = ts_reader_read(reader, data, dataSize, flags);
    lua_pushinteger(L, ret);

  	return 1;
}

///////////////////////////////////////////////////////////////////////////////
// 

static const struct luaL_Reg lts_reader_methods[] = {
	{ "close" , 	lts_reader_close },		// function(reader)
	{ "start" , 	lts_reader_start },  	// function(reader, callback)
	{ "read" , 		lts_reader_read  },		// function(reader, data, sampleTime)

	{NULL, NULL},
};

int lts_reader_init(lua_State* L) 
{
    luaL_newmetatable(L, LUA_TS_READER);

    luaL_newlib(L, lts_reader_methods);
    lua_setfield(L, -2, "__index");

    lua_pushcfunction(L, lts_reader_close);
    lua_setfield(L, -2, "__gc");

    lua_pushcfunction(L, lts_reader_tostring);
    lua_setfield(L, -2, "__tostring");

    lua_pop(L, 1);

    return 0;
}

///////////////////////////////////////////////////////////////////////////////
// Callbacks

int ts_reader_is_sync(const uint8_t* data, uint32_t length, int flags )
{
	if (length < 5) {
		return 0;
	}

	if (flags & MUXER_FLAG_IS_AUDIO) {
		return 1;
	}

	if (flags & MUXER_FLAG_IS_START) {
		int offset = 0;
		if (data[0] == 0x00 && data[1] == 0x00) {
			if (data[2] == 0x01) {
				offset = 3;

			} else if (data[2] == 0x00 && data[3] == 0x01) {
				offset = 4;
			}
		}

		int nalType = data[offset] & 0x1f;
		if (nalType == 0x01) {
			return 0;
			
		} else if (nalType == 0x07 || nalType == 0x08 || nalType == 0x05) {
			return 1;
		}
	}

	return 0;
}

/** 
 * 当解析得到新的数据包. 
 * @param data 数据包内容
 * @param length 数据包长度
 * @param sampleTime 数据包时间戳
 * @param flags 标记
 */
int ts_reader_on_sample( ts_reader_t* reader, const uint8_t* data, uint32_t length, int64_t sampleTime, int flags )
{
	if (reader == NULL) {
		return 0;

	} else if (data == NULL || length <= 0) {
		return 0;
	}

	if (ts_reader_is_sync(data, length, flags)) {
		flags |= MUXER_FLAG_IS_SYNC;
	}

	lua_State* L = (lua_State*)reader->fState;
	lua_pushlstring(L, (char*)data, length);
	lua_pushinteger(L, sampleTime);
	lua_pushinteger(L, flags);

	lts_callback_call(L, reader, 3);
	return 0;
}

static const luaL_Reg lts_reader_functions[] = {
	{ "new",  lts_reader_new },
	{ "open", lts_reader_open },

	{ NULL, NULL }
};

#define lua_set_number(L, name, f) \
    lua_pushnumber(L, f); \
    lua_setfield(L, -2, name); 


LUALIB_API int luaopen_lts_reader(lua_State *L) 
{
	luaL_newlib(L, lts_reader_functions);
	lua_set_number(L, "FLAG_IS_START", 	MUXER_FLAG_IS_START);
 	lua_set_number(L, "FLAG_IS_END", 	MUXER_FLAG_IS_END);
	lua_set_number(L, "FLAG_IS_SYNC", 	MUXER_FLAG_IS_SYNC);
	lua_set_number(L, "FLAG_IS_AUDIO", 	MUXER_FLAG_IS_AUDIO);

	lts_reader_init(L);

	return 1;
}
