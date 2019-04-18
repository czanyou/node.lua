#include "base_types.h"

#include "lua.h"
#include "lauxlib.h"

#include "uv.h"

#include "media_comm.h"

///////////////////////////////////////////////////////////////////////////////
// video input

typedef struct video_in_s
{
	int  fChannel;
	int  fVideoWidth;
	int  fVideoHeight;
	int  fFrameRate;
	int  fReference;

} video_in_t;


///////////////////////////////////////////////////////////////////////////////
// video encoder

typedef struct video_encoder_s
{
	int  fChannel;
	int  fCallback;
	int  fAsyncState;
	int  fThreadState;
	int  fReference;

	lua_State* fState;
	uv_async_t fAsync;		/* async handler */
	uv_thread_t fThread;

} video_encoder_t;


#define lua_set_func(L, name, f) \
    lua_pushcfunction(L, f); \
    lua_setfield(L, -2, name);

#define lua_set_number(L, name, f) \
    lua_pushnumber(L, f); \
    lua_setfield(L, -2, name);


uv_loop_t* media_uv_loop(lua_State* L);

int audio_in_newtable       (lua_State* L);
int audio_out_newtable      (lua_State* L);

int media_system_init	  	(lua_State* L);
int media_system_release	(lua_State* L);
int media_system_type      	(lua_State* L);
int media_system_version   	(lua_State* L);

int video_encoder_newtable  (lua_State* L);
int video_in_newtable       (lua_State* L);
