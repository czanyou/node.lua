#include "common.h"

#include "lua.h"
#include "i2c.h"
#include "lauxlib.h"

///////////////////////////////////////////////////////////////////////////////
// I2C device

typedef struct sdl_i2c_s
{
	int  fChannel;	
} sdl_i2c_t;

#define LUV_I2C "sdl_i2c_t"

static sdl_i2c_t* sdl_i2c_check(lua_State* L, int index)
{
	return luaL_checkudata(L, index, LUV_I2C);
}

static int sdl_i2c_channel(lua_State* L)
{
	sdl_i2c_t* sdl_i2c = sdl_i2c_check(L, 1);
	return sdl_i2c ? sdl_i2c->fChannel : -1;
}

int sdl_i2c_open(lua_State* L)
{
	int ret = 0;
	size_t dataSize = 0;
	char* data = (char*)luaL_checklstring(L, 1, &dataSize);

	const char* deviceName = data;
	if (data == NULL || dataSize <= 0) {
		deviceName = "/dev/i2c-1";
	}

	int fd = i2c_open((char*)deviceName);
	if (fd <= 0) {
		lua_pushnil(L);
		lua_pushstring(L, strerror(errno));
		return 2;
	}
	
	sdl_i2c_t* object = NULL;
	object = lua_newuserdata(L, sizeof(*object));
	luaL_getmetatable(L, LUV_I2C);
	lua_setmetatable(L, -2);

	object->fChannel = fd;

	return 1;
}

static int sdl_i2c_close(lua_State* L)
{
	int ret = -1;
	sdl_i2c_t* sdl_i2c = sdl_i2c_check(L, 1);
	if (sdl_i2c) {
		int channel = sdl_i2c->fChannel;
		if (channel > 0) {
			i2c_close(channel);
			ret = 0;

		} else {
			ret = 0;
		}

		sdl_i2c->fChannel = -1;
	}

	lua_pushinteger(L, ret);
	return 1;
}

static int sdl_i2c_read(lua_State* L)
{
	int ret = -1;
	int channel = sdl_i2c_channel(L);
	int length  = luaL_checkinteger(L, 2);

	if (channel > 0 && length > 0) {
		uint8_t buffer[65];
		memset(buffer, 0xff, sizeof(buffer));

		int readSize = length;
		if (readSize > 64) {
			readSize = 64;

		} else if (readSize <= 0) {
			readSize = 1;
		}

		ret = i2c_read(channel, buffer, readSize);
		if (ret >= 0) {
			lua_pushlstring(L, (char*)buffer, readSize);
			return 1;
		}
	}

	lua_pushnil(L);
	lua_pushinteger(L, ret);
	if (ret < 0) {
		lua_pushstring(L, strerror(errno));
		return 2;
	}
	return 1;
}

// I2C_SLAVE = 1795
static int sdl_i2c_setup(lua_State* L)
{
	int ret 	= -1;
	int channel = sdl_i2c_channel(L);
	int mode    = luaL_checkinteger(L, 2);		
	int value   = luaL_checkinteger(L, 3);

	if (channel > 0) {
		ret = i2c_setup(channel, mode, value);
	}

	lua_pushinteger(L, ret);
	if (ret < 0) {
		lua_pushstring(L, strerror(errno));
		return 2;
	}
	return 1;
}

static int sdl_i2c_write(lua_State* L)
{
	int ret 	= -1;
	int channel = sdl_i2c_channel(L);

	size_t dataSize = 0;
	uint8_t* data = (uint8_t*)luaL_checklstring(L, 2, &dataSize);

	if (data && channel > 0) {
		if (dataSize > 2) {
			dataSize = 2;
		}
		ret = i2c_write(channel, data, dataSize);
	}
	
	lua_pushinteger(L, ret);
	if (ret < 0) {
		lua_pushstring(L, strerror(errno));
		return 2;
	}	
	return 1;
}

static int sdl_i2c_crc(lua_State* L)
{
	int ret = 0;

	size_t dataSize = 0;
	uint8_t* data = (uint8_t*)luaL_checklstring(L, 2, &dataSize);
	if (data && dataSize > 0) {
		ret = i2c_sht20_crc(data, dataSize);
	}
	
	lua_pushinteger(L, ret);
	return 1;
}

static int sdl_i2c_tostring(lua_State* L) 
{
	sdl_i2c_t* sdl_i2c = sdl_i2c_check(L, 1);
    lua_pushfstring(L, "%s: %p", LUV_I2C, sdl_i2c);
  	return 1;
}

static const struct luaL_Reg sdl_i2c_methods[] = {
	{ "close",	sdl_i2c_close },
	{ "read",	sdl_i2c_read  },
	{ "setup",	sdl_i2c_setup },
	{ "write",	sdl_i2c_write },
	{ "crc",	sdl_i2c_crc   },
	{ NULL, NULL },
};

int sdl_i2c_init(lua_State* L) 
{
    luaL_newmetatable(L, LUV_I2C);

    luaL_newlib(L, sdl_i2c_methods);
    lua_setfield(L, -2, "__index");

    lua_pushcfunction(L, sdl_i2c_close);
    lua_setfield(L, -2, "__gc");

    lua_pushcfunction(L, sdl_i2c_tostring);
    lua_setfield(L, -2, "__tostring");   

    lua_pop(L, 1);

    return 0;
}

static const luaL_Reg lsdl_i2c_functions[] = {
	{ "open", sdl_i2c_open },

	{ NULL, NULL }
};

LUALIB_API int luaopen_lsdl_i2c(lua_State *L) 
{
	luaL_newlib(L, lsdl_i2c_functions);

	sdl_i2c_init(L);

	return 1;
}
