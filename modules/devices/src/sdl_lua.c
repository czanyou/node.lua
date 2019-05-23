#include <sys/time.h>
#include <time.h>

#include "common.h"
#include "lua.h"
#include "i2c.h"
#include "lauxlib.h"

int sdl_nanosleep           (lua_State* L);
int sdl_set_system_time     (lua_State* L);

int sdl_nanosleep(lua_State* L)
{
	int ret = -1;

	int delay = luaL_checkinteger(L, 1);
	int mode  = luaL_optinteger(L, 2, 0);

	#ifdef __linux__
	struct timespec t, dummy;
	if (mode > 0) { // us
		t.tv_sec  = 0 ;
		t.tv_nsec = (long)(delay * 1000);

	} else { // ms
		t.tv_sec  = (time_t)(delay / 1000);
		t.tv_nsec = (long)(delay % 1000) * 1000000;
	}

	nanosleep(&t, &dummy);
	ret = 0;
	#endif

	lua_pushinteger(L, ret);
	return 1;	
}

int sdl_set_system_time(lua_State* L)
{
	int ret = -1;

	int newTime  = luaL_optinteger(L, 1, 0);

	#ifdef __linux__
	if (newTime != 0) {
		struct timeval tv = { newTime, 0 };
		settimeofday(&tv, NULL);
	}
	ret = 0;
	#endif

	lua_pushinteger(L, ret);
	return 1;	
}


static const luaL_Reg lsdl_functions[] = {

	{ "nanosleep" , 			sdl_nanosleep	 	 },
	{ "set_system_time" , 		sdl_set_system_time	 },

	{ NULL, NULL }
};

///////////////////////////////////////////////////////////////////////////////
// lmedia functions
 

LUALIB_API int luaopen_lsdl(lua_State *L)
{
	luaL_newlib(L, lsdl_functions);

	return 1;
}
