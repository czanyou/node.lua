
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

static int luv_buffer_copy(lua_State* L)
{
	luv_buffer_t* buffer = luv_buffer_check(L, 1);
	luv_buffer_t* source = luv_buffer_check(L, 3);

	// position, offset, end 为 1 到 size
	lua_Integer targetStart = luaL_optinteger(L, 2, 0);  // target position of dest
	lua_Integer sourceStart = luaL_optinteger(L, 4, 0);  // start position of source
	lua_Integer sourceEnd   = luaL_optinteger(L, 5, 0);  // end position of source

	lua_Integer ret = buffer_copy(buffer, source, targetStart, sourceStart, sourceEnd);

	lua_pushinteger(L, ret);
	return 1;
}

static int luv_buffer_compare(lua_State* L)
{
	luv_buffer_t* buffer = luv_buffer_check(L, 1);
	luv_buffer_t* source = luv_buffer_check(L, 4);

	// position, offset, end 为 1 到 size
	lua_Integer targetStart = luaL_optinteger(L, 2, 0);
	lua_Integer targetEnd   = luaL_optinteger(L, 3, 0);
	
	lua_Integer sourceStart = luaL_optinteger(L, 5, 0);
	lua_Integer sourceEnd   = luaL_optinteger(L, 6, 0);

	lua_Integer ret = buffer_compare(buffer, source, targetStart, targetEnd, sourceStart, sourceEnd);

	lua_pushinteger(L, ret);
	return 1;
}

static int luv_buffer_index_of(lua_State* L)
{
	luv_buffer_t* buffer = luv_buffer_check(L, 1);

	size_t source_size    = 0;
	char* source_data     = (char*)luaL_checklstring(L, 2, &source_size);	

	// offset 为 1 到 size
	lua_Integer offset    = luaL_optinteger(L, 3, 0);
	lua_Integer ret = buffer_index_of(buffer, source_data, source_size, offset);

	lua_pushinteger(L, ret);
	return 1;
}

static int luv_buffer_last_index_of(lua_State* L)
{
	luv_buffer_t* buffer = luv_buffer_check(L, 1);

	size_t source_size    = 0;
	char* source_data     = (char*)luaL_checklstring(L, 2, &source_size);	

	// offset 为 1 到 size
	lua_Integer offset    = luaL_optinteger(L, 3, 0);
	lua_Integer ret = buffer_last_index_of(buffer, source_data, source_size, offset);

	lua_pushinteger(L, ret);
	return 1;
}

static int luv_buffer_compress(lua_State* L)
{
	luv_buffer_t* buffer = luv_buffer_check(L, 1);

	lua_Integer ret = buffer_compress(buffer);
	lua_pushinteger(L, ret);
	return 1;
}

static int luv_buffer_expand(lua_State* L)
{
	luv_buffer_t* buffer = luv_buffer_check(L, 1);
	lua_Integer size = luaL_checkinteger(L, 2);
	lua_Integer ret = buffer_expand(buffer, size);
	lua_pushinteger(L, ret);
	return 1;
}

static int luv_buffer_fill(lua_State* L)
{
	luv_buffer_t* buffer 	= luv_buffer_check (L, 1);
	lua_Integer value 	 	= luaL_checkinteger(L, 2);
	lua_Integer targetStart = luaL_optinteger(L, 3, 0); // start position to fill, default is 1
	lua_Integer targetEnd 	= luaL_optinteger(L, 4, 0); // end position to fill, default is buf.size

	lua_Integer ret = buffer_fill(buffer, value, targetStart, targetEnd);
	lua_pushinteger(L, ret);
	return 1;
}

static int luv_buffer_flags(lua_State* L)
{
	lua_Integer ret = 0;
	luv_buffer_t* buffer = luv_buffer_check(L, 1);
	if (buffer) {
		// set flags
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
	lua_Integer targetStart = luaL_optinteger(L, 2, 0);
	lua_Integer ret = buffer_get_byte(buffer, targetStart);

	lua_pushinteger(L, ret);
	return 1;
}


static int luv_buffer_get_bytes(lua_State* L)
{
	luv_buffer_t* buffer = luv_buffer_check(L, 1);
	// position 为 1 到 size
	lua_Integer targetStart = luaL_checkinteger(L, 2);
	lua_Integer length      = luaL_checkinteger(L, 3);

	int ret = length;
	char* data = buffer_get_bytes(buffer, targetStart, &ret);
	if (data) {
		lua_pushlstring(L, data, ret);
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

static int luv_buffer_move(lua_State* L)
{
	luv_buffer_t* buffer = luv_buffer_check(L, 1);
	// position, offset 为 1 到 size
	lua_Integer targetStart = luaL_checkinteger(L, 2);  // target position to move
	lua_Integer offset   = luaL_checkinteger(L, 3);  // start position of bytes to move
	lua_Integer length   = luaL_checkinteger(L, 4);  // size of bytes to move

	lua_Integer ret = buffer_move(buffer, targetStart, offset, length);
	lua_pushinteger(L, ret);
	return 1;
}

static int luv_buffer_limit(lua_State* L)
{
	lua_Integer ret = 0;
	luv_buffer_t* buffer = luv_buffer_check(L, 1);
	if (buffer) {
		// set limit
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

static int luv_buffer_position(lua_State* L)
{
	lua_Integer ret = 0;
	luv_buffer_t* buffer = luv_buffer_check(L, 1);
	if (buffer) {
		// set position
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
	size_t source_size = 0;

	luv_buffer_t* buffer = luv_buffer_check(L, 1);
	lua_Integer position = luaL_optinteger(L, 2, 0);		// target start of buffer to write
	char* source_data    = (char*)luaL_checklstring(L, 3, &source_size);	
	lua_Integer offset   = luaL_optinteger(L, 4, 0);		// source start of buffer to write
	lua_Integer length   = luaL_optinteger(L, 5, 0);  	// size of bytes to write

	lua_Integer ret = -1;

	if (source_data && source_size > 0) {
		if (offset < 1) {
			offset = 1;
		}

		source_data += (offset - 1);
		source_size -= (offset - 1);
		if (length <= 0) {
			length = source_size;
		}

		ret = buffer_put_bytes(buffer, position, source_data, length);
	}

	lua_pushinteger(L, ret);
	return 1;
}

static int luv_buffer_skip(lua_State* L)
{
	luv_buffer_t* buffer = luv_buffer_check(L, 1);
	lua_Integer size = luaL_checkinteger(L, 2);
	lua_Integer ret = buffer_skip(buffer, size);
	lua_pushinteger(L, ret);
	return 1;
}

static int luv_buffer_size(lua_State* L)
{
	int ret = 0;
	luv_buffer_t* buffer = luv_buffer_check(L, 1);
	ret = buffer_get_size(buffer);

	lua_pushinteger(L, ret);
	return 1;
}

static int luv_buffer_time_seconds(lua_State* L)
{
	lua_Integer ret = 0;
	luv_buffer_t* buffer = luv_buffer_check(L, 1);
	if (buffer) {
		// set time 
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
		// set time 
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
	char* data = buffer_get_data(buffer, 0);
	int   size = buffer_get_size(buffer);
	if (data && (size > 0)) {
		lua_pushlstring(L, data, size);
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
	{ "compare",		luv_buffer_compare },
	{ "compress",		luv_buffer_compress },
	{ "copy",			luv_buffer_copy },
	{ "expand",			luv_buffer_expand },		
	{ "fill",			luv_buffer_fill },
	{ "flags",			luv_buffer_flags },	
	{ "get_byte",		luv_buffer_get_byte },
	{ "get_bytes",		luv_buffer_get_bytes },
	{ "index_of",		luv_buffer_index_of },	
	{ "last_index_of",	luv_buffer_last_index_of },	
	{ "length",			luv_buffer_length },
	{ "limit",			luv_buffer_limit },	
	{ "move",			luv_buffer_move },
	{ "position",		luv_buffer_position },
	{ "put_byte",		luv_buffer_put_byte },
	{ "put_bytes",		luv_buffer_put_bytes },
	{ "size",			luv_buffer_size },
	{ "skip",			luv_buffer_skip },	
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

