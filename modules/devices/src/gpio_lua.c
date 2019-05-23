#include "common.h"

#include "lua.h"
#include "i2c.h"
#include "lauxlib.h"

///////////////////////////////////////////////////////////////////////////////
// ADC device

typedef struct sdl_adc_s
{
	int  fChannel;	
} sdl_adc_t;

#define LUV_ADC "sdl_adc_t"

static sdl_adc_t* sdl_adc_check(lua_State* L, int index)
{
	return luaL_checkudata(L, index, LUV_ADC);
}

int sdl_adc_open(lua_State* L)
{
	int channel = luaL_checkinteger(L, 1);
	int ret = 0;

	sdl_adc_t* stream = NULL;
	stream = lua_newuserdata(L, sizeof(*stream));
	luaL_getmetatable(L, LUV_ADC);
	lua_setmetatable(L, -2);

	stream->fChannel = channel;
	return 1;
}

static int sdl_adc_close(lua_State* L)
{
	int ret = -1;
	sdl_adc_t* sdl_adc = sdl_adc_check(L, 1);
	if (sdl_adc) {
		int channel = sdl_adc->fChannel;
		if (channel > 0) {

		} else {
			ret = 0;
		}

		sdl_adc->fChannel = -1;
	}

	lua_pushinteger(L, ret);
	return 1;
}

static int sdl_adc_read(lua_State* L)
{
	int ret = -1;
	sdl_adc_t* sdl_adc = sdl_adc_check(L, 1);
	if (sdl_adc) {
		int channel = sdl_adc->fChannel;

		
	}

	lua_pushinteger(L, ret);
	return 1;
}

static int sdl_adc_write(lua_State* L)
{
	int ret = -1;
	sdl_adc_t* sdl_adc = sdl_adc_check(L, 1);
	if (sdl_adc) {
		int channel = sdl_adc->fChannel;

		
	}

	lua_pushinteger(L, ret);
	return 1;
}

static int sdl_adc_tostring(lua_State* L) 
{
	sdl_adc_t* sdl_adc = sdl_adc_check(L, 1);
    lua_pushfstring(L, "%s: %p", LUV_ADC, sdl_adc);
  	return 1;
}

static const struct luaL_Reg sdl_adc_methods[] = {
	{ "close",	sdl_adc_close },
	{ "read",	sdl_adc_read },
	{ "write",	sdl_adc_write },
	{NULL, NULL},
};

int sdl_adc_init(lua_State* L) 
{
    luaL_newmetatable(L, LUV_ADC);

    luaL_newlib(L, sdl_adc_methods);
    lua_setfield(L, -2, "__index");

    lua_pushcfunction(L, sdl_adc_close);
    lua_setfield(L, -2, "__gc");

    lua_pushcfunction(L, sdl_adc_tostring);
    lua_setfield(L, -2, "__tostring");   

    lua_pop(L, 1);

    return 0;
}


///////////////////////////////////////////////////////////////////////////////
// GPIO device

typedef struct sdl_gpio_s
{
	int  fChannel;	
} sdl_gpio_t;

#define LUV_GPIO "sdl_gpio_t"

static sdl_gpio_t* sdl_gpio_check(lua_State* L, int index)
{
	return luaL_checkudata(L, index, LUV_GPIO);
}

int sdl_gpio_open(lua_State* L)
{
	int channel = luaL_checkinteger(L, 1);
	int ret = 0;

	sdl_gpio_t* stream = NULL;
	stream = lua_newuserdata(L, sizeof(*stream));
	luaL_getmetatable(L, LUV_GPIO);
	lua_setmetatable(L, -2);

	stream->fChannel = channel;
	return 1;
}

static int sdl_gpio_close(lua_State* L)
{
	int ret = -1;
	sdl_gpio_t* sdl_gpio = sdl_gpio_check(L, 1);
	if (sdl_gpio) {
		int channel = sdl_gpio->fChannel;
		if (channel > 0) {

		} else {
			ret = 0;
		}

		sdl_gpio->fChannel = -1;
	}

	lua_pushinteger(L, ret);
	return 1;
}

static int sdl_gpio_read(lua_State* L)
{
	int ret = -1;
	sdl_gpio_t* sdl_gpio = sdl_gpio_check(L, 1);
	if (sdl_gpio) {
		int channel = sdl_gpio->fChannel;

		
	}

	lua_pushinteger(L, ret);
	return 1;
}

// This sets the mode of a pin to either INPUT, OUTPUT, PWM_OUTPUT or GPIO_CLOCK
static int sdl_gpio_setup(lua_State* L)
{
	int ret = -1;
	sdl_gpio_t* sdl_gpio = sdl_gpio_check(L, 1);
	if (sdl_gpio) {
		int channel = sdl_gpio->fChannel;

		int pin    = luaL_checkinteger(L, 2);
		int value  = luaL_checkinteger(L, 3);
		int mode   = luaL_checkinteger(L, 4);

		if (mode == 1) {
			//ret = analogRead(pin)

		} else if (mode == 2) {
			//pwm

		} else {
			//ret = digitalRead(pin)
		}
	}

	lua_pushinteger(L, ret);
	return 1;
}

static int sdl_gpio_write(lua_State* L)
{
	int ret = -1;
	sdl_gpio_t* sdl_gpio = sdl_gpio_check(L, 1);
	if (sdl_gpio) {
		int channel = sdl_gpio->fChannel;

		int pin    = luaL_checkinteger(L, 2);
		int value  = luaL_checkinteger(L, 3);
		int mode   = luaL_checkinteger(L, 4);

		if (mode == 1) {
			//analogWrite(pin, value)

		} else if (mode == 2) {
			//pwmWrite(pin, value)

		} else {
			//digitalWrite(pin, value)
		}
	}

	lua_pushinteger(L, ret);
	return 1;
}

static int sdl_gpio_tostring(lua_State* L) 
{
	sdl_gpio_t* sdl_gpio = sdl_gpio_check(L, 1);
    lua_pushfstring(L, "%s: %p", LUV_GPIO, sdl_gpio);
  	return 1;
}

static const struct luaL_Reg sdl_gpio_methods[] = {
	{ "close",	sdl_gpio_close },
	{ "read",	sdl_gpio_read },
	{ "setup",	sdl_gpio_setup },
	{ "write",	sdl_gpio_write },
	{NULL, NULL},
};

int sdl_gpio_init(lua_State* L) 
{
    luaL_newmetatable(L, LUV_GPIO);

    luaL_newlib(L, sdl_gpio_methods);
    lua_setfield(L, -2, "__index");

    lua_pushcfunction(L, sdl_gpio_close);
    lua_setfield(L, -2, "__gc");

    lua_pushcfunction(L, sdl_gpio_tostring);
    lua_setfield(L, -2, "__tostring");   

    lua_pop(L, 1);

    return 0;
}



///////////////////////////////////////////////////////////////////////////////
// UART device

typedef struct sdl_uart_s
{
	int  fChannel;	
} sdl_uart_t;

#define LUV_UART "sdl_uart_t"

static sdl_uart_t* sdl_uart_check(lua_State* L, int index)
{
	return luaL_checkudata(L, index, LUV_UART);
}

int sdl_uart_open(lua_State* L)
{
	int channel = luaL_checkinteger(L, 1);
	int ret = 0;

	sdl_uart_t* stream = NULL;
	stream = lua_newuserdata(L, sizeof(*stream));
	luaL_getmetatable(L, LUV_UART);
	lua_setmetatable(L, -2);

	stream->fChannel = channel;
	return 1;
}

static int sdl_uart_close(lua_State* L)
{
	int ret = -1;
	sdl_uart_t* sdl_uart = sdl_uart_check(L, 1);
	if (sdl_uart) {
		int channel = sdl_uart->fChannel;
		if (channel > 0) {

		} else {
			ret = 0;
		}

		sdl_uart->fChannel = -1;
	}

	lua_pushinteger(L, ret);
	return 1;
}

static int sdl_uart_read(lua_State* L)
{
	int ret = -1;
	sdl_uart_t* sdl_uart = sdl_uart_check(L, 1);
	if (sdl_uart) {
		int channel = sdl_uart->fChannel;

		
	}

	lua_pushinteger(L, ret);
	return 1;
}

static int sdl_uart_setup(lua_State* L)
{
	int ret = -1;
	sdl_uart_t* sdl_uart = sdl_uart_check(L, 1);
	if (sdl_uart) {
		int channel = sdl_uart->fChannel;

		
	}

	lua_pushinteger(L, ret);
	return 1;
}

static int sdl_uart_write(lua_State* L)
{
	int ret = -1;
	sdl_uart_t* sdl_uart = sdl_uart_check(L, 1);
	if (sdl_uart) {
		int channel = sdl_uart->fChannel;

		
	}

	lua_pushinteger(L, ret);
	return 1;
}

static int sdl_uart_tostring(lua_State* L) 
{
	sdl_uart_t* sdl_uart = sdl_uart_check(L, 1);
    lua_pushfstring(L, "%s: %p", LUV_UART, sdl_uart);
  	return 1;
}

static const struct luaL_Reg sdl_uart_methods[] = {
	{ "close",	sdl_uart_close },
	{ "read",	sdl_uart_read },
	{ "setup",	sdl_uart_setup },
	{ "write",	sdl_uart_write },
	{NULL, NULL},
};

int sdl_uart_init(lua_State* L) 
{
    luaL_newmetatable(L, LUV_UART);

    luaL_newlib(L, sdl_uart_methods);
    lua_setfield(L, -2, "__index");

    lua_pushcfunction(L, sdl_uart_close);
    lua_setfield(L, -2, "__gc");

    lua_pushcfunction(L, sdl_uart_tostring);
    lua_setfield(L, -2, "__tostring");   

    lua_pop(L, 1);

    return 0;
}

