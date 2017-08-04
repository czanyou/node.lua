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

#include "ts_writer.h"

///////////////////////////////////////////////////////////////////////////////
// callback

static void lts_callback_release(lua_State* L, ts_writer_t* writer)
{
	if (writer == NULL) {
		return;
	}

	if (writer->fCallback != LUA_NOREF) {
  		luaL_unref(L, LUA_REGISTRYINDEX, writer->fCallback);
  		writer->fCallback 	= LUA_NOREF;
  	}
}

static void lts_callback_check(lua_State* L, ts_writer_t* writer, int index) 
{
	if (writer == NULL) {
		return;
	}

  	luaL_checktype(L, index, LUA_TFUNCTION);
  	writer->fCallback = luaL_ref(L, LUA_REGISTRYINDEX);
}

static void lts_callback_call(lua_State* L, ts_writer_t* writer, int nargs) 
{
	if (writer == NULL) {
		return;
	}

  	int ref = writer->fCallback;
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
      	fprintf(stderr, "Uncaught error in TS writer callback: %s\n", lua_tostring(L, -1));
    }
}

///////////////////////////////////////////////////////////////////////////////
// ts

#define LUA_TS_WRITER "ts_writer_t"

static ts_writer_t* lts_writer_check(lua_State* L, int index)
{
	ts_writer_t* writer = luaL_checkudata(L, index, LUA_TS_WRITER);
	return writer;
}

int lts_writer_new(lua_State* L) 
{
	ts_writer_t* writer = NULL;
	writer = lua_newuserdata(L, sizeof(*writer));
	luaL_getmetatable(L, LUA_TS_WRITER);
	lua_setmetatable(L, -2);

	ts_writer_init(writer);

	writer->fCallback 	= LUA_NOREF;
  	writer->fState 		= L;

	return 1;
}

int lts_writer_open(lua_State* L) 
{
	int index = 1;
	int flags = 0x00;
	if (lua_isnumber(L, index)) {
		flags = luaL_checkinteger(L, index);
		index++;
	}

	luaL_checktype(L, index, LUA_TFUNCTION);
  	int callback = luaL_ref(L, LUA_REGISTRYINDEX);

	ts_writer_t* writer = NULL;
	writer = lua_newuserdata(L, sizeof(*writer));
	luaL_getmetatable(L, LUA_TS_WRITER);
	lua_setmetatable(L, -2);

	ts_writer_init(writer);

	writer->fCallback 	= callback;
  	writer->fState 		= L;

  	if ((flags & 0x01) != 0) {
  		writer->fVideoID = 0;
  	}

  	if ((flags & 0x02) != 0) {
  		writer->fAudioID = 0;
  	}

  	if ((flags & 0x10) != 0) {
  		writer->fAudioCodec = STREAM_TYPE_AUDIO_LPCM;
  	}

	return 1;
}

static int lts_writer_close(lua_State* L)
{
	int ret = 0;
	ts_writer_t* writer = lts_writer_check(L, 1);
	if (writer) {
		ret = 1;
	}

	lts_callback_release(L, writer);
	ts_writer_release(writer);

	lua_pushinteger(L, ret);
	return 1;	
}

static int lts_writer_start(lua_State* L) 
{
	int ret = 0;
	ts_writer_t* writer = lts_writer_check(L, 1);

	lts_callback_check(L, writer, 2);
    
    lua_pushinteger(L, ret);
  	return 1;
}

static int lts_writer_write(lua_State* L) 
{
	int ret = 0;
	ts_writer_t* writer = lts_writer_check(L, 1);

	size_t sampleSize = 0;
	uint8_t* data = (uint8_t*)luaL_checklstring(L, 2, &sampleSize);

	int64_t sampleTime  = luaL_checkinteger(L, 3);
	int flags  = luaL_optinteger(L, 4, 0);
	if (flags & MUXER_FLAG_IS_SYNC) {
		ts_writer_write_sync_info(writer, sampleTime);
	}

	int sampleFlags = MUXER_FLAG_IS_END;
	if (flags & MUXER_FLAG_IS_AUDIO) {
		sampleFlags |= MUXER_FLAG_IS_AUDIO;
	}

	ts_writer_write_sample(writer, data, sampleSize, sampleTime, sampleFlags);

    lua_pushinteger(L, ret);
  	return 1;
}

static int lts_writer_tostring(lua_State* L) 
{
	ts_writer_t* writer = lts_writer_check(L, 1);
    lua_pushfstring(L, "%s: %p", LUA_TS_WRITER, writer);
  	return 1;
}

///////////////////////////////////////////////////////////////////////////////
// 

static const struct luaL_Reg lts_writer_methods[] = {
	{ "close" , lts_writer_close },	// function(writer)
	{ "start" , lts_writer_start }, // function(writer, callback)
	{ "write" , lts_writer_write },	// function(writer, sampleData, sampleTime)
	{NULL, NULL},
};

int lts_writer_init(lua_State* L) 
{
    luaL_newmetatable(L, LUA_TS_WRITER);

    luaL_newlib(L, lts_writer_methods);
    lua_setfield(L, -2, "__index");

    lua_pushcfunction(L, lts_writer_close);
    lua_setfield(L, -2, "__gc");

    lua_pushcfunction(L, lts_writer_tostring);
    lua_setfield(L, -2, "__tostring");   

    lua_pop(L, 1);

    return 0;
}

///////////////////////////////////////////////////////////////////////////////
// Callbacks

/** 
 * 写入指定的 TS 包. 
 * @param data
 * @param length 
 */
int ts_writer_on_ts_packet( ts_writer_t* writer, uint8_t* data, uint32_t length, int64_t sampleTime, int flags )
{
	lua_State* L = (lua_State*)writer->fState;
	lua_pushlstring(L, (char*)data, length);
	lua_pushinteger(L, sampleTime);
	lua_pushinteger(L, flags);

	lts_callback_call(L, writer, 3);
	return 0;
}

static const luaL_Reg lts_writer_functions[] = {
	{ "new",  lts_writer_new },
	{ "open", lts_writer_open },

	{ NULL, NULL }
};


#define lua_set_number(L, name, f) \
    lua_pushnumber(L, f); \
    lua_setfield(L, -2, name); 

LUALIB_API int luaopen_lts_writer(lua_State *L) 
{
	luaL_newlib(L, lts_writer_functions);
	lua_set_number(L, "FLAG_IS_START", 	MUXER_FLAG_IS_START);
 	lua_set_number(L, "FLAG_IS_END", 	MUXER_FLAG_IS_END);
	lua_set_number(L, "FLAG_IS_SYNC", 	MUXER_FLAG_IS_SYNC);
	lua_set_number(L, "FLAG_IS_AUDIO", 	MUXER_FLAG_IS_AUDIO);

	lts_writer_init(L);

	return 1;
}
