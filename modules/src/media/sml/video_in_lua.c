#include "media_lua.h"

extern video_encoder_t* video_encoder_check(lua_State* L, int index);

int video_in_init(lua_State* L)
{
	int flags = luaL_optinteger(L, 1, 1);
	int ret = VideoInInit(flags);

	lua_pushinteger(L, ret);
	return 1;
}

int video_in_release(lua_State* L)
{
	int ret = VideoInRelease();

	lua_pushinteger(L, ret);
	return 1;
}

///////////////////////////////////////////////////////////////////////////////
// video input

#define VISION_VIDEO_INPUT "video_in_t"

video_in_t* video_in_check(lua_State* L, int index)
{
	return luaL_checkudata(L, index, VISION_VIDEO_INPUT);
}

static int video_in_close(lua_State* L)
{
	int ret = -1;
	video_in_t* video_in = video_in_check(L, 1);
	if (video_in) {
		int channel = video_in->fChannel;
		if (channel >= 0) {
			ret = VideoInClose(channel);
			video_in->fChannel = -1;

		} else {
			ret = 0;
		}

		// 释放引用
		if (video_in->fReference != LUA_NOREF) {
			luaL_unref(L, LUA_REGISTRYINDEX, video_in->fReference);
			video_in->fReference = LUA_NOREF;

			LOG_W("close");
		}
	}

	lua_pushinteger(L, ret);
	return 1;
}

static int video_in_connect(lua_State* L)
{
	int ret = -1;
	video_in_t*      video_in      = video_in_check(L, 1);
	video_encoder_t* video_encoder = video_encoder_check(L, 2);
	if (video_in && video_encoder) {
		int channel = video_encoder->fChannel;
		int source  = video_in->fChannel;

		//LOG_W("%d - %d", channel, source);
		ret = VideoEncodeBind(channel, source);
	}

	lua_pushinteger(L, ret);
	return 1;
}

static int video_in_get_framerate(lua_State* L)
{
	int ret = -1;
	video_in_t* video_in = video_in_check(L, 1);
	if (video_in) {
		int channel = video_in->fChannel;
		ret = VideoInGetFrameRate(channel);
	}

	lua_pushinteger(L, ret);
	return 1;
}

int video_in_open(lua_State* L)
{
	int channel = luaL_optinteger(L, 1, 0);
	int width 	= luaL_optinteger(L, 2, 0);
	int height 	= luaL_optinteger(L, 3, 0);
	int flags 	= luaL_optinteger(L, 4, 0);

	int ret = VideoInOpen(channel, width, height, flags);

	video_in_t* video_in = NULL;
	video_in = lua_newuserdata(L, sizeof(*video_in));
	luaL_getmetatable(L, VISION_VIDEO_INPUT);
	lua_setmetatable(L, -2);

	video_in->fChannel     = channel;
	video_in->fVideoWidth  = width;
	video_in->fVideoHeight = height;
	video_in->fFrameRate   = 0;

	// 保存对象的引用
	lua_pushvalue(L, -1);
	video_in->fReference     = luaL_ref(L, LUA_REGISTRYINDEX);

	return 1; // return video_in_t userdata for lua
}

static int video_in_set_framerate(lua_State* L)
{
	int ret = -1;
	video_in_t* video_in = video_in_check(L, 1);
	if (video_in) {
		int channel = video_in->fChannel;
		int frameRate = luaL_checkinteger(L, 2);
		ret = VideoInSetFrameRate(channel, frameRate);

		video_in->fFrameRate = frameRate;
	}

	lua_pushinteger(L, ret);
	return 1;
}

static int video_in_tostring(lua_State* L) 
{
	video_in_t* video_in = video_in_check(L, 1);
    lua_pushfstring(L, "%s: %p", VISION_VIDEO_INPUT, video_in);
  	return 1;
}

static const struct luaL_Reg video_in_methods[] = {
	{ "close",			video_in_close },
	{ "connect",		video_in_connect },
	{ "get_framerate",	video_in_get_framerate },
	{ "set_framerate",	video_in_set_framerate },
	{NULL, NULL},
};

int video_in_metatable(lua_State* L) 
{
    luaL_newmetatable(L, VISION_VIDEO_INPUT);

    luaL_newlib(L, video_in_methods);
    lua_setfield(L, -2, "__index");

    lua_pushcfunction(L, video_in_close);
    lua_setfield(L, -2, "__gc");

    lua_pushcfunction(L, video_in_tostring);
    lua_setfield(L, -2, "__tostring");   

    lua_pop(L, 1);

    return 0;
}

int video_in_newtable(lua_State* L)
{
	video_in_metatable(L);
	
	lua_newtable(L);

    lua_set_func(L, "init",     video_in_init);
    lua_set_func(L, "open",     video_in_open);
    lua_set_func(L, "release",  video_in_release);

    lua_set_number(L, "MAX_CHANNEL_COUNT", 	1);
    lua_set_number(L, "FLAG_MIRROR", 		0x10);
    lua_set_number(L, "FLAG_FLIP", 			0x20);

	return 0;
}
