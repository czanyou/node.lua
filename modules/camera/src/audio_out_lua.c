#include "media_lua.h"

///////////////////////////////////////////////////////////////////////////////
// audio output

typedef struct audio_out_s
{
	int  fChannel;
	int  fCallback;
	lua_State*  fState;


} audio_out_t;



///////////////////////////////////////////////////////////////////////////////
// callback

static void audio_callback_release(audio_out_t* audio_out)
{
	if (audio_out == NULL) {
		return;
	}

	lua_State* L = (lua_State*)audio_out->fState;

	if (audio_out->fCallback != LUA_NOREF) {
  		luaL_unref(L, LUA_REGISTRYINDEX, audio_out->fCallback);
  		audio_out->fCallback = LUA_NOREF;
  	}
}

static void audio_callback_check(audio_out_t* audio_out, int index) 
{
	if (audio_out == NULL) {
		return;
	}

	lua_State* L = (lua_State*)audio_out->fState;
	audio_callback_release(audio_out);

  	luaL_checktype(L, index, LUA_TFUNCTION);
  	audio_out->fCallback = luaL_ref(L, LUA_REGISTRYINDEX);
}

static void audio_callback_call(audio_out_t* audio_out, int nargs) 
{
	if (audio_out == NULL) {
		return;
	}

	lua_State* L = (lua_State*)audio_out->fState;
  	int ref = audio_out->fCallback;
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
      	fprintf(stderr, "Uncaught  error in audio out callback: %s\n", lua_tostring(L, -1));
    }
}

///////////////////////////////////////////////////////////////////////////////
// audio_out

#define VISION_AUDIO_OUTPUT "audio_out_t"

static audio_out_t* audio_out_check(lua_State* L, int index)
{
	return luaL_checkudata(L, index, VISION_AUDIO_OUTPUT);
}

int AudioOutOnFrame(int channel, void* context, BYTE* data, UINT length)
{
	audio_out_t* audio_out = (audio_out_t*)context;
	//LOG_W("AudioOutOnFrame: %x:%d", audio_out, length);

	int flags = 0x100;

	lua_State* L = (lua_State*)audio_out->fState;
	lua_pushlstring(L, (char*)data, length);
	lua_pushinteger(L, length);
	lua_pushinteger(L, flags);

	audio_callback_call(audio_out, 3);

	return 0;
}

int audio_out_open(lua_State* L)
{
	int channel = luaL_optinteger(L, 1, 0);
	int format  = luaL_optinteger(L, 2, 0);
	int ret = 0;

	AudioOutOpen(channel, format);

	audio_out_t* audio_out = NULL;
	audio_out = lua_newuserdata(L, sizeof(*audio_out));
	luaL_getmetatable(L, VISION_AUDIO_OUTPUT);
	lua_setmetatable(L, -2);

	audio_out->fChannel  = channel;
	audio_out->fState    = L;
	audio_out->fCallback = LUA_NOREF;

	return 1;
}

static int audio_out_start(lua_State* L)
{
	int ret = -1;
	audio_out_t* audio_out = audio_out_check(L, 1);
	if (audio_out) {
		if (lua_isfunction(L, 2)) {
			audio_callback_check(audio_out, 2);
		}

		ret = 0;
	}

	lua_pushinteger(L, ret);
	return 1;
}

static int audio_out_close(lua_State* L)
{
	int ret = -1;
	audio_out_t* audio_out = audio_out_check(L, 1);
	if (audio_out) {
		int channel = audio_out->fChannel;

		if (channel > 0) {
			ret = AudioOutClose(channel);

		} else {
			ret = 0;
		}

		audio_out->fChannel  = -1;

		audio_callback_release(audio_out);
	}

	lua_pushinteger(L, ret);
	return 1;
}

static int audio_out_write(lua_State* L)
{
	int ret = -1;
	audio_out_t* audio_out = audio_out_check(L, 1);
	if (audio_out) {
		int channel  = audio_out->fChannel;

		size_t data_size = 0;
		uint8_t* data = (uint8_t*)luaL_checklstring(L, 2, &data_size);

		//LOG_W("audio_out_write: %x:%d", data, data_size);

		if (channel < 0) {
			ret = -3;

		} else if (data == NULL || data_size <= 0) {
			ret = -2;

		} else {
			AudioSampleInfo streamInfo;
			streamInfo.fPacketData 	= data;
			streamInfo.fPacketSize 	= data_size;
			streamInfo.fSequence 	= 0;
			streamInfo.fSampleTime 	= 0;
			streamInfo.fPrivateData = audio_out;

			//LOG_W("audio_out_write: %x:%d", audio_out, channel);

			ret = AudioOutWriteSample(channel, &streamInfo);
		}
	}

	lua_pushinteger(L, ret);
	return 1;
}

static int audio_out_tostring(lua_State* L) 
{
	audio_out_t* audio_out = audio_out_check(L, 1);
    lua_pushfstring(L, "%s: %p", VISION_AUDIO_OUTPUT, audio_out);
  	return 1;
}

static const struct luaL_Reg audio_out_methods[] = {
	{ "close",	audio_out_close },
	{ "write",	audio_out_write },
	{ "start",	audio_out_start },

	{NULL, NULL},
};

int audio_out_metatable(lua_State* L) 
{
    luaL_newmetatable(L, VISION_AUDIO_OUTPUT);

    luaL_newlib(L, audio_out_methods);
    lua_setfield(L, -2, "__index");

    lua_pushcfunction(L, audio_out_close);
    lua_setfield(L, -2, "__gc");

    lua_pushcfunction(L, audio_out_tostring);
    lua_setfield(L, -2, "__tostring");   

    lua_pop(L, 1);

    return 0;
}

int audio_out_init(lua_State* L)
{
	int ret = AudioOutInit();
	lua_pushinteger(L, ret);
	return 1;
}

int audio_out_release(lua_State* L)
{
	int ret = AudioOutRelease();
	lua_pushinteger(L, ret);
	return 1;
}

int audio_out_newtable(lua_State* L)
{
	audio_out_metatable(L);

	lua_newtable(L);

    lua_set_func(L, "init",     audio_out_init);
    lua_set_func(L, "open",     audio_out_open);
    lua_set_func(L, "release",  audio_out_release);

    lua_set_number(L, "MAX_CHANNEL_COUNT", 1);
    lua_set_number(L, "MEDIA_FORMAT_AAC", MEDIA_FORMAT_AAC);
    lua_set_number(L, "MEDIA_FORMAT_PCM", MEDIA_FORMAT_PCM);
    
	return 0;
}
