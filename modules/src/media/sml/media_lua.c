#include "media_lua.h"

uv_loop_t* media_uv_loop(lua_State* L) {
	uv_loop_t* loop;
	lua_pushstring(L, "uv_loop");
	lua_rawget(L, LUA_REGISTRYINDEX);
	loop = (uv_loop_t*)lua_touserdata(L, -1);
	lua_pop(L, 1);
	return loop;
}

/**
 * 初始化媒体处理系统, 主要是预分配缓存区等.
 */
int media_system_init(lua_State* L)
{
	lua_Integer flags = luaL_optinteger(L, 1, 0);
	lua_Integer ret = MediaSystemInit(flags);
	lua_pushinteger(L, ret);
	return 1;
}

/**
 * 关闭媒体处理系统, 并释放相关的资源.
 */
int media_system_release(lua_State* L)
{
	lua_Integer ret = MediaSystemRelease();
	lua_pushinteger(L, ret);
	return 1;
}

/**
 * 返回当前媒体处理系统版本.
 */
int media_system_type(lua_State* L)
{
	lua_pushstring(L, MediaSystemGetType());
	return 1;
}

int media_system_version(lua_State* L)
{
	lua_pushstring(L, MediaSystemGetVersion());
	return 1;
}

