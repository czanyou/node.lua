
#include "buffer.c"

static int luv_buffer_new(lua_State* L)
{
	lua_Integer length = luaL_optinteger(L, 1, 128 * 1024);

	luv_buffer_t* buffer = NULL;
	buffer = lua_newuserdata(L, sizeof(*buffer));
	luaL_getmetatable(L, LUV_BUFFER);
	lua_setmetatable(L, -2);

	buffer_init(buffer, length);

	return 1;
}

static luv_buffer_t* luv_buffer_check(lua_State* L, int index)
{
	return (luv_buffer_t*)luaL_checkudata(L, index, LUV_BUFFER);
}

static int luv_buffer_close(lua_State* L)
{
	luv_buffer_t* buffer = luv_buffer_check(L, 1);
	lua_Integer ret = buffer_close(buffer);
	lua_pushinteger(L, ret);
	return 1;
}

static int luv_buffer_fill(lua_State* L)
{
	luv_buffer_t* buffer = luv_buffer_check (L, 1);
	lua_Integer value 	 = luaL_checkinteger(L, 2);
	lua_Integer position = luaL_checkinteger(L, 3);
	lua_Integer length 	 = luaL_checkinteger(L, 4);

	// position 为 1 到 size
	lua_Integer ret = buffer_fill(buffer, value, position, length);

	lua_pushinteger(L, ret);
	return 1;
}

static int luv_buffer_copy(lua_State* L)
{
	luv_buffer_t* buffer = luv_buffer_check(L, 1);
	luv_buffer_t* source = luv_buffer_check(L, 3);

	// position, offset 为 1 到 size
	lua_Integer position = luaL_checkinteger(L, 2);
	lua_Integer offset   = luaL_checkinteger(L, 4);
	lua_Integer length   = luaL_checkinteger(L, 5);

	lua_Integer ret = buffer_copy(buffer, source, position, offset, length);

	lua_pushinteger(L, ret);
	return 1;
}

static int luv_buffer_flags(lua_State* L)
{
	lua_Integer ret = 0;
	luv_buffer_t* buffer = luv_buffer_check(L, 1);
	if (buffer) {
		if (lua_isnumber(L, 2)) {
			lua_Integer flags = luaL_checkinteger(L, 2);
			buffer->flags = flags;
		}

		ret = buffer->flags;
	}

	lua_pushinteger(L, ret);
	return 1;
}


static int luv_buffer_get_byte(lua_State* L)
{
	luv_buffer_t* buffer = luv_buffer_check(L, 1);
	lua_Integer position = luaL_checkinteger(L, 2);
	lua_Integer ret = buffer_get_byte(buffer, position);

	lua_pushinteger(L, ret);
	return 1;
}


static int luv_buffer_get_bytes(lua_State* L)
{
	luv_buffer_t* buffer = luv_buffer_check(L, 1);
	// position 为 1 到 size
	lua_Integer position = luaL_checkinteger(L, 2);
	lua_Integer length   = luaL_checkinteger(L, 3);
	lua_Integer limit    = buffer->length - length + 1;

	char* data = buffer_get_bytes(buffer, position, length, limit);
	if (data) {
		lua_pushlstring(L, data, length);
		return 1;
	}

	lua_pushnil(L);
	return 1;
}

static int luv_buffer_length(lua_State* L)
{
	int ret = 0;
	luv_buffer_t* buffer = luv_buffer_check(L, 1);
	if (buffer) {
		ret = buffer->length;
	}

	lua_pushinteger(L, ret);
	return 1;
}

static int luv_buffer_limit(lua_State* L)
{
	lua_Integer ret = 0;
	luv_buffer_t* buffer = luv_buffer_check(L, 1);
	if (buffer) {
		if (lua_isnumber(L, 2)) {
			lua_Integer limit = luaL_checkinteger(L, 2);
			if (limit >= 1 && limit <= buffer->length + 1) {
				buffer->limit = limit;
			}
		}

		ret = buffer->limit;
	}

	lua_pushinteger(L, ret);
	return 1;
}

static int luv_buffer_move(lua_State* L)
{
	luv_buffer_t* buffer = luv_buffer_check(L, 1);
	// position, offset 为 1 到 size
	lua_Integer position = luaL_checkinteger(L, 2);
	lua_Integer offset   = luaL_checkinteger(L, 3);
	lua_Integer length   = luaL_checkinteger(L, 4);

	lua_Integer ret = buffer_move(buffer, position, offset, length);
	lua_pushinteger(L, ret);
	return 1;
}

static int luv_buffer_position(lua_State* L)
{
	lua_Integer ret = 0;
	luv_buffer_t* buffer = luv_buffer_check(L, 1);
	if (buffer) {
		if (lua_isnumber(L, 2)) {
			int position = luaL_checkinteger(L, 2);
			if (position >= 1 && position <= buffer->length) {
				buffer->position = position;
			}
		}

		ret = buffer->position;
	}

	lua_pushinteger(L, ret);
	return 1;
}

static int luv_buffer_put_byte(lua_State* L)
{
	luv_buffer_t* buffer = luv_buffer_check(L, 1);
	lua_Integer position = luaL_checkinteger(L, 2);
	lua_Integer value    = luaL_checkinteger(L, 3);

	lua_Integer ret = buffer_put_byte(buffer, position, value);
	lua_pushinteger(L, ret);
	return 1;
}

static int luv_buffer_put_bytes(lua_State* L)
{
	size_t data_size = 0;

	luv_buffer_t* buffer = luv_buffer_check(L, 1);
	lua_Integer position = luaL_checkinteger(L, 2);
	char* source_data    = (char*)luaL_checklstring(L, 3, &data_size);	
	lua_Integer offset   = luaL_checkinteger(L, 4);
	lua_Integer length   = luaL_checkinteger(L, 5);

	lua_Integer ret = buffer_put_bytes(buffer, position, source_data, data_size, offset, length);
	lua_pushinteger(L, ret);
	return 1;
}

static int luv_buffer_time_seconds(lua_State* L)
{
	lua_Integer ret = 0;
	luv_buffer_t* buffer = luv_buffer_check(L, 1);
	if (buffer) {
		if (lua_isnumber(L, 2)) {
			lua_Integer time_seconds = luaL_checkinteger(L, 2);
			if (time_seconds > 0) {
				buffer->time_seconds = time_seconds;
			}
		}

		ret = buffer->time_seconds;
	}

	lua_pushinteger(L, ret);
	return 1;
}

static int luv_buffer_time_useconds(lua_State* L)
{
	lua_Integer ret = 0;
	luv_buffer_t* buffer = luv_buffer_check(L, 1);
	if (buffer) {
		if (lua_isnumber(L, 2)) {
			lua_Integer time_useconds = luaL_checkinteger(L, 2);
			if (time_useconds > 0) {
				buffer->time_useconds = time_useconds;
			}
		}

		ret = buffer->time_useconds;
	}

	lua_pushinteger(L, ret);
	return 1;
}

static int luv_buffer_to_string(lua_State* L)
{
	luv_buffer_t* buffer = luv_buffer_check(L, 1);
	if (buffer && buffer->data) {
		lua_pushlstring(L, buffer->data, buffer->length);
		return 1;
	}

	lua_pushnil(L);
	return 1;
}

static int luv_buffer_tostring(lua_State* L) {
	luv_buffer_t* buffer = luv_buffer_check(L, 1);
    lua_pushfstring(L, "%s: %p", LUV_BUFFER, buffer);
  	return 1;
}

static const luaL_Reg luv_buffer_functions[] = {
	{ "close",			luv_buffer_close },
	{ "copy",			luv_buffer_copy },
	{ "fill",			luv_buffer_fill },
	{ "flags",			luv_buffer_flags },	
	{ "get_byte",		luv_buffer_get_byte },
	{ "get_bytes",		luv_buffer_get_bytes },
	{ "length",			luv_buffer_length },
	{ "limit",			luv_buffer_limit },	
	{ "move",			luv_buffer_move },
	{ "position",		luv_buffer_position },
	{ "put_byte",		luv_buffer_put_byte },
	{ "put_bytes",		luv_buffer_put_bytes },
	{ "time_seconds",	luv_buffer_time_seconds },	
	{ "time_useconds",	luv_buffer_time_useconds },	
	{ "to_string",		luv_buffer_to_string },
	{ NULL, NULL }
};

static void luv_buffer_init(lua_State* L) {
	// buffer
	luaL_newmetatable(L, LUV_BUFFER);

	luaL_newlib(L, luv_buffer_functions);
	lua_setfield(L, -2, "__index");

	lua_pushcfunction(L, luv_buffer_close);
	lua_setfield(L, -2, "__gc");

	lua_pushcfunction(L, luv_buffer_tostring);
	lua_setfield(L, -2, "__tostring");	

	lua_pop(L, 1);
}

