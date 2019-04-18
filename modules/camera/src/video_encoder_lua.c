#include "media_lua.h"

typedef enum video_encoder_state_s 
{
	ENCODER_STATE_INIT = 0,
	ENCODER_STATE_STARTING, 
	ENCODER_STATE_RUNNING,
	ENCODER_STATE_STOPING,
	ENCODER_STATE_STOPPED
} video_encoder_state;

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

static int video_table_to_settings(lua_State *L, VideoSettings* settings) 
{
	memset(settings, 0, sizeof(VideoSettings));
	if (lua_isnil(L, -1)) {
		return 0;

	} else if (!lua_istable(L, -1)) {
		return luaL_error(L, "table expected");
	}

	settings->fBitrate 		= lua_opt_int(L, "bitrate", 	2000);
	settings->fBitrateMode 	= lua_opt_int(L, "bitrateMode", 0);
	settings->fCodecFormat 	= lua_opt_int(L, "codec", 		0);
	settings->fEnabled 		= lua_opt_int(L, "enabled", 	TRUE);
	settings->fFlags 		= lua_opt_int(L, "flags", 		0);
	settings->fFrameRate 	= lua_opt_int(L, "frameRate", 	25);
	settings->fGopLength 	= lua_opt_int(L, "gopLength", 	100);
	settings->fQuality 		= lua_opt_int(L, "quality", 	0);
	settings->fVideoHeight 	= lua_opt_int(L, "height", 		720);
	settings->fVideoNorm 	= lua_opt_int(L, "videoNorm", 	0);
	settings->fVideoWidth 	= lua_opt_int(L, "width", 		1280);

	settings->fIsMirror 	= lua_opt_int(L, "mirror", 		0);
	settings->fIsFlip 		= lua_opt_int(L, "flip", 		0);
	settings->fRotate 		= lua_opt_int(L, "rotate", 		0);
	settings->fChannel 		= lua_opt_int(L, "channel", 	-1);

  	return 0;
}

static int video_settings_to_table(lua_State *L, VideoSettings* settings) 
{
	if (settings == NULL) {
		return 0;
	}

	lua_newtable(L);

    lua_set_number(L, "bitrate", 	settings->fBitrate);
    lua_set_number(L, "bitrateMode",settings->fBitrateMode);
    lua_set_number(L, "codec", 		settings->fCodecFormat);
    lua_set_number(L, "enabled", 	settings->fEnabled);
    lua_set_number(L, "flags", 		settings->fFlags);
    lua_set_number(L, "frameRate", 	settings->fFrameRate);
    lua_set_number(L, "gopLength", 	settings->fGopLength);
    lua_set_number(L, "height", 	settings->fVideoHeight);
    lua_set_number(L, "quality", 	settings->fQuality);
    lua_set_number(L, "videoNorm", 	settings->fVideoNorm);
    lua_set_number(L, "width", 		settings->fVideoWidth);

    lua_set_number(L, "mirror", 	settings->fIsMirror);
    lua_set_number(L, "flip", 		settings->fIsFlip);
    lua_set_number(L, "rotate", 	settings->fRotate);

  	return 0;
}

///////////////////////////////////////////////////////////////////////////////
// callback

static void video_encoder_callback_release(lua_State* L, video_encoder_t* encoder)
{
	if (encoder == NULL) {
		return;
	}

	if (encoder->fCallback != LUA_NOREF) {
  		luaL_unref(L, LUA_REGISTRYINDEX, encoder->fCallback);
  		encoder->fCallback = LUA_NOREF;
  	}
}

static void video_encoder_callback_check(lua_State* L, video_encoder_t* encoder, int index) 
{
	if (encoder == NULL) {
		return;
	}

	video_encoder_callback_release(L, encoder);

  	luaL_checktype(L, index, LUA_TFUNCTION);
  	encoder->fCallback = luaL_ref(L, LUA_REGISTRYINDEX);
}

static void video_encoder_callback_call(lua_State* L, video_encoder_t* encoder, int nargs) 
{
	if (encoder == NULL) {
		return;
	}

  	int ref = encoder->fCallback;
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
      	fprintf(stderr, "Uncaught error in video encoder callback: %s\n", lua_tostring(L, -1));
    }
}


#define VISION_VIDEO_ENCODER "video_encoder_t"

static int video_encoder_new_buffer(lua_State* L, VideoSampleInfo* sample);

video_encoder_t* video_encoder_check(lua_State* L, int index)
{
	return luaL_checkudata(L, index, VISION_VIDEO_ENCODER);
}

int video_encoder_open(lua_State* L)
{
	int ret = 0;

	VideoSettings settings;
	memset(&settings, 0, sizeof(VideoSettings));
	video_table_to_settings(L, &settings);

	int channel = settings.fChannel;

	ret = VideoEncodeOpen(channel, &settings);
	if (ret < 0) {
		LOG_W("Open failed: %d (0x%x)", channel, ret);
		return 1;
	}

	video_encoder_t* encoder = NULL;
	encoder = lua_newuserdata(L, sizeof(*encoder));
	luaL_getmetatable(L, VISION_VIDEO_ENCODER);
	lua_setmetatable(L, -2);

	encoder->fChannel  		= ret;
	encoder->fAsyncState 	= 0;
	encoder->fThreadState 	= ENCODER_STATE_INIT;
	encoder->fCallback 		= LUA_NOREF;
  	encoder->fState 		= L;
  	encoder->fReference 	= LUA_NOREF;

 	// 保存对象的引用
	lua_pushvalue(L, -1);
	encoder->fReference     = luaL_ref(L, LUA_REGISTRYINDEX);

	return 1; // return video_encoder_t userdata for lua
}

// ----------------------------------------------------------------------------

static int video_encoder_close(lua_State* L)
{
	int ret = -1;
	video_encoder_t* video_encoder = video_encoder_check(L, 1);
	if (video_encoder == NULL) {
		lua_pushinteger(L, ret);
		return 1;
	}

	int channel = video_encoder->fChannel;

	// 释放引用
	if (video_encoder->fReference != LUA_NOREF) {
		luaL_unref(L, LUA_REGISTRYINDEX, video_encoder->fReference);
		video_encoder->fReference = LUA_NOREF;

		LOG_W("close");
	}

	if (channel > 0) {
		ret = VideoEncodeClose(channel);

	} else {
		ret = 0;
	}

	video_encoder->fChannel = -1;

	video_encoder_callback_release(L, video_encoder);

	if (video_encoder->fAsyncState == 1) {
		video_encoder->fAsyncState = 0;
		uv_handle_t* async = (uv_handle_t*)&(video_encoder->fAsync);
		if (!uv_is_closing(async)) {
			uv_close(async, NULL);
		}
	}

	video_encoder->fThreadState = 5;
	
	lua_pushinteger(L, ret);
	return 1;
}

static void video_encoder_read(lua_State* L, video_encoder_t* video_encoder)
{
	if (video_encoder == NULL) {
		return;
	}

	int channel = video_encoder->fChannel;
	
	while (TRUE) {
		struct VideoSampleInfo streamInfo;
		memset(&streamInfo, 0, sizeof(streamInfo));

		int ret = VideoEncodeGetStream(channel, &streamInfo);
		if (ret <= 0) {
			break;
		}

		//LOG_W("ret %d\r\n", ret);

		int count = 1;
		lua_pushinteger(L, ret);

		if (video_encoder_new_buffer(L, &streamInfo) > 0) {
			count = count + 3;
			video_encoder_callback_call(L, video_encoder, count);
		}

		//LOG_W("count %d\r\n", count);
		VideoEncodeReleaseStream(channel, &streamInfo);
	}
}

static int video_encoder_renew(lua_State* L)
{
	int ret = -1;
	video_encoder_t* video_encoder = video_encoder_check(L, 1);
	if (video_encoder) {
		int channel = video_encoder->fChannel;
		ret = VideoEncodeRenewStream(channel);

		video_encoder_read(L, video_encoder);
	}

	lua_pushinteger(L, ret);
	return 1;
}

static void video_encoder_async_callback(uv_async_t *async)
{
	if (async == NULL) {
		return;
	}

	//LOG_W("async\r\n");

	video_encoder_t* video_encoder = (video_encoder_t*)async->data;

	lua_State* L = video_encoder->fState;
	video_encoder_read(L, video_encoder);
}

static void video_encoder_thread(void* arg)
{
	if (arg == NULL) {
		return;
	}


	video_encoder_t* video_encoder = (video_encoder_t*)arg;
	if (video_encoder->fThreadState != ENCODER_STATE_STARTING) {
		return;
	}

	int channel = video_encoder->fChannel;
	LOG_W("enter (%d)\r\n", channel);

	video_encoder->fThreadState = ENCODER_STATE_RUNNING;

	while (video_encoder->fThreadState == ENCODER_STATE_RUNNING) {
		int channel = video_encoder->fChannel;

		int ret = VideoEncodeNextStream(channel, TRUE);
		if (ret < 0) {
			LOG_W("exit encode thread %d\r\n", ret);
			break;
		}

		// LOG_W("encode thread %d (%d)\r\n", channel, ret);
		if (ret >= 0) {
			uv_async_send(&video_encoder->fAsync);
		}
	}

	video_encoder->fThreadState = ENCODER_STATE_INIT;
	uv_async_send(&video_encoder->fAsync);
	LOG_W("exit\r\n");
}

static int video_encoder_start(lua_State* L)
{
	int ret = -1;
	video_encoder_t* video_encoder = video_encoder_check(L, 1);
	if (video_encoder == NULL) {
		lua_pushinteger(L, ret);
		return 1;
	}

	int channel = video_encoder->fChannel;
	int flags = luaL_optinteger(L, 2, 0);

	ret = VideoEncodeStart(channel, flags);

	if (lua_isfunction(L, 3)) {
		video_encoder_callback_check(L, video_encoder, 3);

		uv_loop_t* loop = media_uv_loop(L);

		//LOG_W("uv_async_init %d", video_encoder->fAsyncState);

		if (video_encoder->fAsyncState == 0) {
			uv_async_init(loop, &(video_encoder->fAsync), video_encoder_async_callback);
			video_encoder->fAsync.data = video_encoder;
			video_encoder->fAsyncState = 1;
		}

		//LOG_W("uv_thread_create: %d", video_encoder->fThreadState);

		if (video_encoder->fThreadState == ENCODER_STATE_INIT) {
			video_encoder->fThreadState = ENCODER_STATE_STARTING;
			uv_thread_create(&video_encoder->fThread, video_encoder_thread, video_encoder);
		}
	}

	lua_pushinteger(L, ret);
	return 1;
}

static int video_encoder_stop(lua_State* L)
{
	int ret = -1;
	video_encoder_t* video_encoder = video_encoder_check(L, 1);
	if (video_encoder) {
		int channel = video_encoder->fChannel;
		ret = VideoEncodeStop(channel);	

		if (video_encoder->fAsyncState == 1) {
			video_encoder->fAsyncState = 0;
			uv_handle_t* async = (uv_handle_t*)&(video_encoder->fAsync);

			uv_close(async, NULL);
		}

		if (video_encoder->fThreadState != ENCODER_STATE_INIT) {
			video_encoder->fThreadState = ENCODER_STATE_STOPING;
		}
	}

	lua_pushinteger(L, ret);
	return 1;
}

static int video_encoder_get_attributes(lua_State* L)
{
	int ret = -1;
	video_encoder_t* video_encoder = video_encoder_check(L, 1);
	if (video_encoder) {
		int channel = video_encoder->fChannel;

		VideoSettings settings;
		ret = VideoEncodeGetAttributes(channel, &settings);

		lua_pushinteger(L, ret);
		video_settings_to_table(L, &settings);
		return 2;
	}

	lua_pushinteger(L, ret);
	return 1;
}

static int video_encoder_set_attributes(lua_State* L)
{
	int ret = -1;
	video_encoder_t* video_encoder = video_encoder_check(L, 1);
	if (video_encoder) {
		int channel = video_encoder->fChannel;

		VideoSettings settings;
		video_table_to_settings(L, &settings);
		ret = VideoEncodeSetAttributes(channel, &settings);
	}

	lua_pushinteger(L, ret);
	return 1;
}

static int video_encoder_set_crop(lua_State* L)
{
	int ret = -1;
	video_encoder_t* video_encoder = video_encoder_check(L, 1);
	if (video_encoder) {
		int channel = video_encoder->fChannel;
		int l = luaL_checkinteger(L, 2);
		int t = luaL_checkinteger(L, 3);
		int w = luaL_checkinteger(L, 4);
		int h = luaL_checkinteger(L, 5);
		ret = VideoEncodeSetCrop(channel, l, t, w, h);
	}

	lua_pushinteger(L, ret);
	return 1;
}

static int video_encoder_new_buffer(lua_State* L, VideoSampleInfo* sample)
{
	if (sample == NULL) {
		return 0;
	}

	int packetCount = sample->fPacketCount;
	if (packetCount <= 0) {
		return 0;
	}

	int totalBytes = 0;
	int i = 0;
	for (i = 0; i < packetCount; i++) {
		totalBytes += sample->fPacketSize[i];
	}

	if (totalBytes <= 0) {
		return 0;
	}

	if (packetCount == 1) {
		char* data = (char*)sample->fPacketData[0];
		int size   = sample->fPacketSize[0];
		if (data == NULL || size <= 0) {
			return 0;
		}
		
		lua_pushlstring(L, data, size);

	} else {
		char* data = malloc(totalBytes + 4);
		char* p = data;
		for (i = 0; i < packetCount; i++) {
			char* src = (char*)sample->fPacketData[i];
			int size  = sample->fPacketSize[i];

			if (src && size > 0) {
				memcpy(p, src, size);
				p += size;
			}
		}

		lua_pushlstring(L, data, totalBytes);
		free(data);

		data = p = NULL;
	}

	lua_Integer sampleTime = sample->fSampleTime;
	lua_pushinteger(L, sampleTime);

	lua_Integer flags = sample->fFlags;
	lua_pushinteger(L, flags);

	return totalBytes;
}

static int video_encoder_tostring(lua_State* L) 
{
	video_encoder_t* video_encoder = video_encoder_check(L, 1);
    lua_pushfstring(L, "%s: %p", VISION_VIDEO_ENCODER, video_encoder);
  	return 1;
}

///////////////////////////////////////////////////////////////////////////////
// 

static const struct luaL_Reg video_encoder_methods[] = {
	{ "close",				video_encoder_close },
	{ "renew",				video_encoder_renew },
	{ "get_attributes",		video_encoder_get_attributes },
	{ "set_attributes",		video_encoder_set_attributes },
	{ "set_crop",	    	video_encoder_set_crop },
	{ "start",				video_encoder_start },
	{ "stop",				video_encoder_stop },
	{NULL, NULL},
};

int video_encoder_metatable(lua_State* L) 
{
    luaL_newmetatable(L, VISION_VIDEO_ENCODER);

    luaL_newlib(L, video_encoder_methods);
    lua_setfield(L, -2, "__index");

    lua_pushcfunction(L, video_encoder_close);
    lua_setfield(L, -2, "__gc");

    lua_pushcfunction(L, video_encoder_tostring);
    lua_setfield(L, -2, "__tostring");

    lua_pop(L, 1);

    return 0;
}

int video_encoder_newtable(lua_State* L)
{
	video_encoder_metatable(L);
	
	lua_newtable(L);

    lua_set_func(L, "open",     video_encoder_open);

    lua_set_number(L, "MEDIA_FORMAT_H264", 	MEDIA_FORMAT_H264);
    lua_set_number(L, "MEDIA_FORMAT_JPEG", 	MEDIA_FORMAT_JPEG);
    lua_set_number(L, "FLAG_IS_SYNC", 		FLAG_IS_SYNC);
    lua_set_number(L, "MAX_CHANNEL_COUNT", 	8);

	return 0;
}
