#include "base_types.h"

#include <lua.h>
#include <lauxlib.h>

#include "media_comm.h"
#include "media_lua.h"

///////////////////////////////////////////////////////////////////////////////
// lmedia functions

static const luaL_Reg lmedia_functions[] = {
	{ "init",		  media_system_init    },
	{ "release",	media_system_release },
	{ "version",	media_system_version },
	{ "type",		  media_system_type    },

	{ NULL, NULL }
};

///////////////////////////////////////////////////////////////////////////////
// lmedia functions
 

LUALIB_API int luaopen_lcamera(lua_State *L) 
{
	luaL_newlib(L, lmedia_functions);

	lua_pushstring(L, MediaSystemGetVersion());
    lua_setfield(L, -2, "VERSION");

  	lua_pushstring(L, MediaSystemGetType());
    lua_setfield(L, -2, "TYPE");

    audio_in_newtable(L);
    lua_setfield(L, -2, "audio_in");

    audio_out_newtable(L);
    lua_setfield(L, -2, "audio_out");

    video_in_newtable(L);
    lua_setfield(L, -2, "video_in");

    video_encoder_newtable(L);
    lua_setfield(L, -2, "video_encoder");

	return 1;
}


