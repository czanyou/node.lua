#include <stdio.h>
#include <string.h>
#include <errno.h>

#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>

#include <modbus.h>

#define LUV_MODBUS "modbus"

enum {
    TCP,
    TCP_PI,
    RTU
};

typedef struct l_modbus_t
{
    modbus_t *modbus;
    modbus_mapping_t *mb_mapping;
    int use_backend;
} l_modbus_t;

void l_pushtable(lua_State *L, int key, void *value, char *vtype)
{
    lua_pushnumber(L, key);

    if (strcmp(vtype, "number") == 0)
    {
        double *buf = value;
        lua_pushnumber(L, *buf);
    }
    else if (strcmp(vtype, "integer") == 0)
    {
        long int *buf = value;
        lua_pushinteger(L, *buf);
    }
    else if (strcmp(vtype, "boolean") == 0)
    {
        int *buf = value;
        lua_pushboolean(L, *buf);
    }
    else if (strcmp(vtype, "string") == 0)
    {
        lua_pushstring(L, (char *)value);
    }
    else
    {
        printf("Get NULL value\n");
        lua_pushnil(L);
    }

    lua_settable(L, -3);
}

static int l_version(lua_State *L)
{
    lua_pushstring(L, LIBMODBUS_VERSION_STRING);
    return 1;
}

static int l_init(lua_State *L)
{
    const char *host = lua_tostring(L, 1);
    int port = (int)lua_tointeger(L, 2);
    char parity = (char)luaL_optinteger(L, 3, 'N'); // N: 78, O: 79, E: 69
    int data_bit = (int)luaL_optinteger(L, 4, 8);
    int stop_bit = (int)luaL_optinteger(L, 5, 1);

    printf("init: %s, %d, %d, %d, %d", host, port, parity, data_bit, stop_bit);
    lua_pop(L, 2);

    l_modbus_t *ctx;

    if (port < 9600)
    {
        ctx = (l_modbus_t *)lua_newuserdata(L, sizeof(l_modbus_t));

        luaL_getmetatable(L, LUV_MODBUS);
        lua_setmetatable(L, -2);

        ctx->modbus = modbus_new_tcp(host, port);
        ctx->mb_mapping = NULL;
        ctx->use_backend = TCP;
    }
    else
    {
        ctx = (l_modbus_t *)lua_newuserdata(L, sizeof(l_modbus_t));

        luaL_getmetatable(L, LUV_MODBUS);
        lua_setmetatable(L, -2);

        const char* device = host;
        int baud = port;

        ctx->modbus = modbus_new_rtu(device, port, parity, data_bit, stop_bit);
        ctx->mb_mapping = NULL;
        ctx->use_backend = RTU;
    }

    if (ctx->modbus == NULL)
    {
        fprintf(stderr, "Modbus init error: %s\n", modbus_strerror(errno));
        return -1;
    }
    
    return 1;
}

static int l_connect(lua_State *L)
{
    l_modbus_t *ctx = (l_modbus_t *)luaL_checkudata(L, 1, LUV_MODBUS);
    luaL_argcheck(L, (ctx != NULL) && (ctx->modbus != NULL), 1, "Context Error");

    if (modbus_connect(ctx->modbus) == -1)
    {
        fprintf(stderr, "Modbus connect failed: %s\n", modbus_strerror(errno));
        modbus_free(ctx->modbus);
        return -1;
    }

    printf("Modbus connect successed!\n");
    return 1;
}

static int l_listen(lua_State *L)
{
    l_modbus_t *ctx = (l_modbus_t *)luaL_checkudata(L, 1, LUV_MODBUS);
    luaL_argcheck(L, (ctx != NULL) && (ctx->modbus != NULL), 1, "Context Error");

    int fd = modbus_tcp_listen(ctx->modbus, 1);
    modbus_tcp_accept(ctx->modbus, &fd);

    lua_pushinteger(L, fd);
    return 1;
}

static int l_mapping(lua_State *L)
{
    l_modbus_t *ctx = (l_modbus_t *)luaL_checkudata(L, 1, LUV_MODBUS);
    luaL_argcheck(L, (ctx != NULL) && (ctx->modbus != NULL), 1, "Context Error");

    if (ctx->mb_mapping) {
        modbus_mapping_free(ctx->mb_mapping);
        ctx->mb_mapping = NULL;
    }

    unsigned int startAddress = (unsigned int)luaL_optinteger(L, 2, 0);
    unsigned int registerCount = (unsigned int)luaL_optinteger(L, 3, 100);

    modbus_mapping_t *mb_mapping = modbus_mapping_new_start_address(
        0, 0,
        0, 0,
        startAddress, registerCount,
        0, 0);
    ctx->mb_mapping = mb_mapping;

    lua_pushinteger(L, 0);
    return 1;
}

static int l_set_value(lua_State *L)
{
    l_modbus_t *ctx = (l_modbus_t *)luaL_checkudata(L, 1, LUV_MODBUS);
    luaL_argcheck(L, (ctx != NULL) && (ctx->modbus != NULL), 1, "Context Error");

    unsigned int registerType = (unsigned int)luaL_optinteger(L, 2, 0);
    int registerAddress = (int)luaL_optinteger(L, 3, 0);
    uint16_t registerValue = (uint16_t)luaL_optinteger(L, 4, 0);

    modbus_mapping_t *mb_mapping = ctx->mb_mapping;
    if (mb_mapping) {
        if (registerType == 2 && mb_mapping->tab_registers) {
            int offset = registerAddress - mb_mapping->start_registers;
            if (offset >= 0 && offset < mb_mapping->nb_registers) {
                mb_mapping->tab_registers[offset] = registerValue;
            }
        }
    }
}

static int l_receive(lua_State *L)
{
    l_modbus_t *ctx = (l_modbus_t *)luaL_checkudata(L, 1, LUV_MODBUS);
    luaL_argcheck(L, (ctx != NULL) && (ctx->modbus != NULL), 1, "Context Error");

    uint8_t query[MODBUS_TCP_MAX_ADU_LENGTH];
    modbus_mapping_t *mb_mapping = ctx->mb_mapping;
  
    int ret = modbus_receive(ctx->modbus, query);
    if (ret > 0) {
        ret = modbus_reply(ctx->modbus, query, ret, mb_mapping);
    }
    
    lua_pushinteger(L, ret);
    return 1;
}

static int l_close(lua_State *L)
{
    l_modbus_t *ctx = (l_modbus_t *)luaL_checkudata(L, 1, LUV_MODBUS);
    luaL_argcheck(L, (ctx != NULL) && (ctx->modbus != NULL), 1, "Context Error");

    if (ctx->mb_mapping) {
        modbus_mapping_free(ctx->mb_mapping);
        ctx->mb_mapping = NULL;
    }

    modbus_close(ctx->modbus);
    modbus_free(ctx->modbus);

    ctx->modbus = NULL;

    lua_pop(L, lua_gettop(L));
    printf("Disconnect!\n");
    return 1;
}

static int l_slave(lua_State *L)
{
    l_modbus_t *ctx = (l_modbus_t *)luaL_checkudata(L, 1, LUV_MODBUS);
    luaL_argcheck(L, (ctx != NULL) && (ctx->modbus != NULL), 1, "Context Error");

    int slave = lua_tointeger(L, 2);
    lua_pop(L, 1);
    modbus_set_slave(ctx->modbus, slave);
    return 1;
}

static int l_read(lua_State *L)
{
    l_modbus_t *ctx = (l_modbus_t *)luaL_checkudata(L, 1, LUV_MODBUS);
    luaL_argcheck(L, (ctx != NULL) && (ctx->modbus != NULL), 1, "Context Error");

    int cnt = lua_rawlen(L, -1);
    int addr[256];
    uint16_t buf[sizeof(uint16_t)];

    int i = 0;
    lua_pushnil(L);
    while (lua_next(L, -2))
    {
        lua_pushvalue(L, -2);
        addr[i] = lua_tointeger(L, -2);
        lua_pop(L, 2);
        i++;
    }

    lua_pop(L, 1);

    lua_newtable(L);
    for (i = 0; i < cnt; i++)
    {
        if (modbus_read_registers(ctx->modbus, addr[i], 1, buf) == -1)
        {
            fprintf(stderr, "Read Error: %s\n", modbus_strerror(errno));
            return -1;
        }

        if (buf == NULL)
        {
            fprintf(stderr, "Read Error: %s\n", modbus_strerror(errno));
            return -1;
        }

        long int res = (long int)*buf;
        l_pushtable(L, addr[i], &res, "integer");
        //printf("%d,%ld\n", addr[i], (long int)buf);
    }

    return 1;
}

static int l_mread(lua_State *L)
{
    l_modbus_t *ctx = (l_modbus_t *)luaL_checkudata(L, 1, LUV_MODBUS);
    luaL_argcheck(L, (ctx != NULL) && (ctx->modbus != NULL), 1, "Context Error");

    int addr = lua_tointeger(L, 2);
    int cnt = lua_tointeger(L, 3);
    lua_pop(L, 2);
    if (cnt > 256)
    {
        cnt = 256;
    }

    uint16_t buf[256];
    if (modbus_read_registers(ctx->modbus, addr, cnt, buf) == -1)
    {
        fprintf(stderr, "Read Error: %s\n", modbus_strerror(errno));
        return -1;
    }

    if (buf == NULL)
    {
        fprintf(stderr, "Read Error: %s\n", modbus_strerror(errno));
        return -1;
    }
    lua_pushlstring(L, (const char *)buf, cnt * 2);
    return 1;
}

static int l_mwrite(lua_State *L)
{
    l_modbus_t *ctx = (l_modbus_t *)luaL_checkudata(L, 1, LUV_MODBUS);
    luaL_argcheck(L, (ctx != NULL) && (ctx->modbus != NULL), 1, "Context Error");

    int addr = lua_tointeger(L, 2);
    int value = lua_tointeger(L, 3);
    lua_pop(L, 2);

    if (modbus_write_register(ctx->modbus, addr, value) == -1)
    {
        fprintf(stderr, "Write Error: invalid action\n");
        return -1;
    }

    printf("%x Write Successed!\n", addr);
    return 1;
}

static int l_write(lua_State *L)
{
    l_modbus_t *ctx = (l_modbus_t *)luaL_checkudata(L, 1, LUV_MODBUS);
    luaL_argcheck(L, (ctx != NULL) && (ctx->modbus != NULL), 1, "Context Error");

    lua_pushvalue(L, -1);
    int cnt = 0;
    lua_pushnil(L);
    while (lua_next(L, -2))
    {
        lua_pushvalue(L, -2);
        lua_pop(L, 2);
        cnt++;
    }

    lua_pop(L, 1);

    int addr[256];
    int value[256];

    int i = 0;
    lua_pushnil(L);
    while (lua_next(L, -2))
    {
        lua_pushvalue(L, -2);
        addr[i] = lua_tointeger(L, -1);
        value[i] = lua_tointeger(L, -2);
        lua_pop(L, 2);
        i++;
    }

    lua_pop(L, 1);

    lua_newtable(L);
    int res = 0;
    for (i = 0; i < cnt; i++)
    {
        if (modbus_write_register(ctx->modbus, addr[i], value[i]) == -1)
        {
            fprintf(stderr, "%d Write Error:%s\n", addr[i], modbus_strerror(errno));
            res = 0;
        }
        else
        {
            res = 1;
        }

        l_pushtable(L, addr[i], &res, "boolean");
    }

    return 1;
}

static const struct luaL_Reg modbus_func[] = {
    {"connect", l_connect},
    {"close", l_close},
    {"read", l_read},
    {"mread", l_mread},
    {"mwrite", l_mwrite},
    {"write", l_write},
    {"slave", l_slave},
    {"listen", l_listen},
    {"mapping", l_mapping},
    {"set_value", l_set_value},
    {"receive", l_receive},
    {NULL, NULL},
};

static const struct luaL_Reg modbus_lib[] = {
    {"version", l_version},
    {"new", l_init},
    {NULL, NULL},
};

LUALIB_API int luaopen_lmodbus(lua_State *L)
{
    /*luaL_newmetatable(L, "modbus");
    lua_pushvalue(L,-1);
    lua_setfield(L, -2, "__index");
    luaL_register(L, NULL, modbus_func);
    luaL_register(L, "modbus", modbus_lib);*/

    luaL_newlib(L, modbus_lib);

    luaL_newmetatable(L, LUV_MODBUS);

    luaL_newlib(L, modbus_func);
    lua_setfield(L, -2, "__index");

    lua_pop(L, 1);

    return 1;
}
