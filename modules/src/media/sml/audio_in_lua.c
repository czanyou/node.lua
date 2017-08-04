#include "media_lua.h"

///////////////////////////////////////////////////////////////////////////////
// audio input

typedef struct audio_in_s
{
	int  fChannel;
	int  fCallback;
	int  fAsyncState;
	int  fThreadState;
	int  fIsClosed;
	int  fReference;

	lua_State*  fState;
	uv_async_t  fAsync;		/* async handler */
	uv_thread_t fThread;
	AudioSettings fAudioSettings;

} audio_in_t;

typedef enum AudioInState 
{
	AUDIO_IN_STATE_INIT = 0,
	AUDIO_IN_STATE_STARTING, 
	AUDIO_IN_STATE_RUNNING,
	AUDIO_IN_STATE_STOPING,
	AUDIO_IN_STATE_STOPPED
} AudioInState;

///////////////////////////////////////////////////////////////////////////////
// callback

static int lua_opt_int(lua_State *L, const char* name, int defaultValue) 
{
	int result = defaultValue;
	lua_pushstring(L, name);
	lua_gettable(L, -2);  /* get table[key] */
	if (!lua_isnil(L, -1)) {
		result = (int)lua_tointeger(L, -1);
	}
	lua_pop(L, 1);  /* remove number */
	return result;
}

static int audio_table_to_settings(lua_State *L, AudioSettings* settings) 
{
	memset(settings, 0, sizeof(AudioSettings));
	if (lua_isnil(L, -1)) {
		return 0;

	} else if (!lua_istable(L, -1)) {
		return luaL_error(L, "table expected");
	}

	settings->fBitrate 		= lua_opt_int(L, "bitrate", 	16);
	settings->fBitrateMode 	= lua_opt_int(L, "bitrateMode", 0);
	settings->fCodecFormat 	= lua_opt_int(L, "codec", 		0);
	settings->fEnabled 		= lua_opt_int(L, "enabled", 	TRUE);
	settings->fFlags 		= lua_opt_int(L, "flags", 		0);
	settings->fNumChannels 	= lua_opt_int(L, "channels", 	1);
	settings->fQuality 		= lua_opt_int(L, "quality", 	0);
	settings->fSampleBits 	= lua_opt_int(L, "sampleBits", 	16);
	settings->fSampleRate 	= lua_opt_int(L, "sampleRate", 	8000);

  	return 0;
}


///////////////////////////////////////////////////////////////////////////////
// callback

static void audio_callback_release(audio_in_t* audio_in)
{
	if (audio_in == NULL) {
		return;
	}

	lua_State* L = audio_in->fState;

	if (audio_in->fCallback != LUA_NOREF) {
  		luaL_unref(L, LUA_REGISTRYINDEX, audio_in->fCallback);
  		audio_in->fCallback = LUA_NOREF;
  	}
}

static void audio_callback_check(audio_in_t* audio_in, int index) 
{
	if (audio_in == NULL) {
		return;
	}

	lua_State* L = audio_in->fState;
	audio_callback_release(audio_in);

  	luaL_checktype(L, index, LUA_TFUNCTION);
  	audio_in->fCallback = luaL_ref(L, LUA_REGISTRYINDEX);
}

static void audio_callback_call(audio_in_t* audio_in, int nargs) 
{
	if (audio_in == NULL) {
		return;
	}

	lua_State* L = audio_in->fState;

  	int ref = audio_in->fCallback;
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
      	LOG_W("Uncaught  error in audio in callback: %s\n", lua_tostring(L, -1));
      	return;
    }
}


#define VISION_AUDIO_INPUT "audio_in_t"

static audio_in_t* audio_in_check(lua_State* L, int index)
{
	return luaL_checkudata(L, index, VISION_AUDIO_INPUT);
}

static int audio_in_clear(audio_in_t* audio_in)
{
	if (audio_in->fThreadState == AUDIO_IN_STATE_INIT) {
		int channel  = audio_in->fChannel;
		if (channel > 0) {
			AudioInClose(channel);
		}

		if (audio_in->fAsyncState == 1) {
			audio_in->fAsyncState = 0;
			uv_handle_t* async = (uv_handle_t*)&(audio_in->fAsync);
			if (!uv_is_closing(async)) {
				uv_close(async, NULL);
			}
		}
	}	

	audio_callback_release(audio_in);
	return 0;
}

static int audio_in_close(lua_State* L)
{
	int ret = -1;
	
	audio_in_t* audio_in = audio_in_check(L, 1);
	if (audio_in == NULL) {
		lua_pushinteger(L, ret);
		return 1;
	}

	// 释放引用
	if (audio_in->fReference != LUA_NOREF) {
		luaL_unref(L, LUA_REGISTRYINDEX, audio_in->fReference);
		audio_in->fReference = LUA_NOREF;
	}	

	audio_in->fIsClosed = TRUE;
	audio_in->fChannel  = -1;

	if (audio_in->fThreadState != AUDIO_IN_STATE_INIT) {
		audio_in->fThreadState = AUDIO_IN_STATE_STOPING;
		uv_thread_join(&audio_in->fThread);
	}

	audio_in_clear(audio_in);

	ret = 0;
	lua_pushinteger(L, ret);
	return 1;
}

static int audio_in_gc(lua_State* L)
{
	LOG_W("audio_in_gc");

	return audio_in_close(L);
}

static int audio_in_open(lua_State* L)
{
	int channel = luaL_checkinteger(L, 1);

	AudioSettings audioSettings;
	memset(&audioSettings, 0, sizeof(audioSettings));

	if (lua_istable(L, -1)) {
		audio_table_to_settings(L, &audioSettings);

	} else {
		int format  = luaL_optinteger(L, 2, 0);
		audioSettings.fCodecFormat 	= format;
		audioSettings.fSampleRate 	= 8000;
		audioSettings.fSampleBits 	= 16;
		audioSettings.fNumChannels 	= 1;
	}

	//LOG_I("channel=%d", channel);
	int ret = AudioInOpen(channel, &audioSettings);
	if (ret < 0) {
		lua_pushnil(L);
		lua_pushinteger(L, ret);
		return 2;
	}

	audio_in_t* audio_in = NULL;
	audio_in = lua_newuserdata(L, sizeof(*audio_in));
	luaL_getmetatable(L, VISION_AUDIO_INPUT);
	lua_setmetatable(L, -2);

	memset(audio_in, 0, sizeof(*audio_in));

	audio_in->fAudioSettings 	= audioSettings;
	audio_in->fCallback 		= LUA_NOREF;
	audio_in->fChannel  		= channel;
	audio_in->fReference 		= LUA_NOREF;
	audio_in->fState 			= L;

 	// 保存对象的引用
	lua_pushvalue(L, -1);
	audio_in->fReference     	= luaL_ref(L, LUA_REGISTRYINDEX);
 	
	return 1;
}

static int audio_in_new_buffer(lua_State* L, AudioSampleInfo* sample)
{
	if (sample == NULL) {
		return 0;
	}

	int totalBytes = sample->fPacketSize;
	if (totalBytes <= 0) {
		return 0;
	}

	char* data = (char*)sample->fPacketData;
	int size   = sample->fPacketSize;
	lua_pushlstring(L, data, size);

	lua_Integer sampleTime = sample->fSampleTime;
	lua_pushinteger(L, sampleTime);

	lua_Integer flags = 0x8001; // Audio & Sync
	lua_pushinteger(L, flags);

	return totalBytes;
}

static void audio_in_async_callback(uv_async_t *async)
{
	if (async == NULL) {
		return;
	}

	audio_in_t* audio_in = (audio_in_t*)async->data;
	lua_State* L = audio_in->fState;

	int channel = audio_in->fChannel;

	struct AudioSampleInfo streamInfo;
	memset(&streamInfo, 0, sizeof(streamInfo));

	while (TRUE) {
		int ret = AudioInGetStream(channel, &streamInfo);
		if (ret < 0) {
			break;
		}

		int count = 1;
		lua_pushinteger(L, ret);
		if (audio_in_new_buffer(L, &streamInfo) > 0) {
			count = count + 3;
		}

		AudioInReleaseStream(channel, &streamInfo);
		audio_callback_call(audio_in, count);
	}
}

static void audio_in_thread(void* arg)
{
	if (arg == NULL) {
		return;
	}

	LOG_W("enter\r\n");

	audio_in_t* audio_in = (audio_in_t*)arg;
	audio_in->fThreadState = AUDIO_IN_STATE_RUNNING;

	while (audio_in->fThreadState == AUDIO_IN_STATE_RUNNING) {
		int ret = AudioInNextStream(audio_in->fChannel);
		if (ret < 0) {
			LOG_W("AudioInNextStream: %d", ret);
			break;
		}

		if (ret > 0) {
			uv_async_send(&audio_in->fAsync);
		}
	}

	LOG_W("exit %d\r\n", audio_in->fThreadState);

	audio_in->fThreadState = AUDIO_IN_STATE_INIT;
	uv_async_send(&audio_in->fAsync);
}

static int audio_in_start(lua_State* L)
{
	int ret = -1;
	audio_in_t* audio_in = audio_in_check(L, 1);
	if (audio_in) {
		int channel = audio_in->fChannel;
		ret = 0;
	}

	int index = -1;
	if (lua_isfunction(L, 2)) {
		index = 2;

	} else if (lua_isfunction(L, 3)) {
		index = 3;
	}

	if (index > 0) {
		audio_callback_check(audio_in, index);

		uv_loop_t* loop = media_uv_loop(L);

		//LOG_W("uv_async_init %d", audio_in->fAsyncState);
		if (audio_in->fAsyncState == 0) {
			uv_async_init(loop, &(audio_in->fAsync), audio_in_async_callback);
			audio_in->fAsync.data = audio_in;
			audio_in->fAsyncState = 1;
		}

		//LOG_W("uv_thread_create: %d", audio_in->fThreadState);
		if (audio_in->fThreadState == AUDIO_IN_STATE_INIT) {
			audio_in->fThreadState = AUDIO_IN_STATE_STARTING;
			uv_thread_create(&audio_in->fThread, audio_in_thread, audio_in);
		}
	}

	lua_pushinteger(L, ret);
	return 1;
}

static int audio_in_stop(lua_State* L)
{
	int ret = -1;
	audio_in_t* audio_in = audio_in_check(L, 1);
	if (audio_in) {
		int channel = audio_in->fChannel;
		ret = AudioInStop(audio_in->fChannel);

		if (audio_in->fThreadState == AUDIO_IN_STATE_RUNNING) {
			audio_in->fThreadState = AUDIO_IN_STATE_STOPING;

		} else if (audio_in->fThreadState == AUDIO_IN_STATE_STARTING) {
			audio_in->fThreadState = AUDIO_IN_STATE_STOPING;
		}
	}

	lua_pushinteger(L, ret);
	return 1;
}

static int audio_in_tostring(lua_State* L) 
{
	audio_in_t* audio_in = audio_in_check(L, 1);
    lua_pushfstring(L, "%s: %p", VISION_AUDIO_INPUT, audio_in);
  	return 1;
}

static const struct luaL_Reg audio_in_methods[] = {
	{ "close",		audio_in_close },
	{ "start",		audio_in_start },
	{ "stop",		audio_in_stop },

	{ NULL, NULL },
};

static int audio_in_newclass(lua_State* L) 
{
    luaL_newmetatable(L, VISION_AUDIO_INPUT);

    luaL_newlib(L, audio_in_methods);
    lua_setfield(L, -2, "__index");

    lua_pushcfunction(L, audio_in_gc);
    lua_setfield(L, -2, "__gc");

    lua_pushcfunction(L, audio_in_tostring);
    lua_setfield(L, -2, "__tostring");   

    lua_pop(L, 1);

    return 0;
}

static int audio_in_init(lua_State* L)
{
	int ret = AudioInInit();
	lua_pushinteger(L, ret);
	return 1;
}

static int audio_in_release(lua_State* L)
{
	int ret = AudioInRelease();
	lua_pushinteger(L, ret);
	return 1;
}

int audio_in_newtable(lua_State* L)
{
	audio_in_newclass(L);
	
	lua_newtable(L);

    lua_set_func(L, "init",     audio_in_init);
    lua_set_func(L, "open",     audio_in_open);
    lua_set_func(L, "release",  audio_in_release);

    lua_set_number(L, "MAX_CHANNEL_COUNT", 1);
    lua_set_number(L, "MEDIA_FORMAT_AAC", MEDIA_FORMAT_AAC);
    lua_set_number(L, "MEDIA_FORMAT_PCM", MEDIA_FORMAT_PCM);

	return 0;
}
