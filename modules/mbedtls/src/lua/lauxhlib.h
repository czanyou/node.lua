/*
 *  Copyright (C) 2016 Masatoshi Teruya
 *
 *  Permission is hereby granted, free of charge, to any person obtaining a copy
 *  of this software and associated documentation files (the "Software"), to deal
 *  in the Software without restriction, including without limitation the rights
 *  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 *  copies of the Software, and to permit persons to whom the Software is
 *  furnished to do so, subject to the following conditions:
 *
 *  The above copyright notice and this permission notice shall be included in
 *  all copies or substantial portions of the Software.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 *  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 *  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
 *  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 *  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 *  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 *  THE SOFTWARE.
 *
 *  lauxhlib.h
 *  lauxhlib - lua auxiliary header library
 *
 *  Created by Masatoshi Teruya on 16/02/28.
 *  Copyright 2016 Masatoshi Teruya. All rights reserved.
 *
 */


#ifndef lauxhlib_h
#define lauxhlib_h

#include <lauxlib.h>
#include <lualib.h>


/* reference */

#define lauxh_isref(ref) \
    ((ref) >= 0)


#define lauxh_ref(L) \
    luaL_ref(L, LUA_REGISTRYINDEX)


#define lauxh_refat(L, idx) \
    (lua_pushvalue(L, idx), luaL_ref(L, LUA_REGISTRYINDEX))


#define lauxh_pushref(L, ref) \
    lua_rawgeti(L, LUA_REGISTRYINDEX, ref)


#define lauxh_unref(L, ref) \
    (luaL_unref(L, LUA_REGISTRYINDEX, ref), LUA_NOREF)



/* table */

#define lauxh_gettblof(L, k, idx) do{ \
    lua_pushstring(L, k); \
    lua_rawget(L, idx); \
}while(0)


#define lauxh_pushnil2tbl(L, k) do{ \
    lua_pushstring(L, k); \
    lua_pushnil(L); \
    lua_rawset(L, -3); \
}while(0)


#define lauxh_pushfn2tbl(L, k, v) do{ \
    lua_pushstring(L, k); \
    lua_pushcfunction(L, v); \
    lua_rawset(L, -3); \
}while(0)


#define lauxh_pushstr2tbl(L, k, v) do{ \
    lua_pushstring(L, k); \
    lua_pushstring(L, v); \
    lua_rawset(L, -3); \
}while(0)


#define lauxh_pushlstr2tbl(L, k, v, l) do{ \
    lua_pushliteral(L, k); \
    lua_pushlstring(L, v, l); \
    lua_rawset(L, -3); \
}while(0)


#define lauxh_pushnum2tbl(L, k, v) do{ \
    lua_pushstring(L, k); \
    lua_pushnumber(L, v); \
    lua_rawset(L, -3); \
}while(0)


#define lauxh_pushint2tbl(L, k, v) do{ \
    lua_pushstring(L, k); \
    lua_pushinteger(L, v); \
    lua_rawset(L, -3); \
}while(0)


#define lauxh_pushbool2tbl(L, k, v) do{ \
    lua_pushstring(L, k); \
    lua_pushboolean(L, v); \
    lua_rawset(L, -3); \
}while(0)


/* table as array */

#define lauxh_gettblat(L, idx, at) do{ \
    lua_rawgeti(L, at, idx); \
}while(0)


#define lauxh_pushnil2arr(L, idx) do{ \
    lua_pushnil(L); \
    lua_rawseti(L, -2, idx); \
}while(0)


#define lauxh_pushfn2arr(L, idx, v) do{ \
    lua_pushcfunction(L, v); \
    lua_rawseti(L, -2, idx); \
}while(0)


#define lauxh_pushstr2arr(L, idx, v) do{ \
    lua_pushstring(L, v); \
    lua_rawseti(L, -2, idx); \
}while(0)


#define lauxh_pushlstr2arr(L, idx, v, l) do{ \
    lua_pushlstring(L, v, l); \
    lua_rawseti(L, -2, idx); \
}while(0)


#define lauxh_pushnum2arr(L, idx, v) do{ \
    lua_pushnumber(L, v); \
    lua_rawseti(L, -2, idx); \
}while(0)


#define lauxh_pushint2arr(L, idx, v) do{ \
    lua_pushinteger(L, v); \
    lua_rawseti(L, -2, idx); \
}while(0)


#define lauxh_pushbool2arr(L, idx, v) do{ \
    lua_pushboolean(L, v); \
    lua_rawseti(L, -2, idx); \
}while(0)


#if LUA_VERSION_NUM >= 502
    #define lauxh_rawlen(L, idx)    lua_rawlen(L, idx)
#else
    #define lauxh_rawlen(L, idx)    lua_objlen(L, idx)
#endif


/* metatable */

#define lauxh_setmetatable(L, tname) do { \
    luaL_getmetatable(L, tname); \
    lua_setmetatable(L, -2); \
}while(0)


/* type */

#define lauxh_typenameat(L, idx)    lua_typename(L, lua_type(L, idx))


/* typecheck */

#define lauxh_isnil(L, idx)         (lua_type(L, idx) <= LUA_TNIL)
#define lauxh_isstring(L, idx)      (lua_type(L, idx) == LUA_TSTRING)
#define lauxh_isnumber(L, idx)      (lua_type(L, idx) == LUA_TNUMBER)
#define lauxh_isboolean(L, idx)     (lua_type(L, idx) == LUA_TBOOLEAN)
#define lauxh_istable(L, idx)       (lua_type(L, idx) == LUA_TTABLE)
#define lauxh_isfunction(L, idx)    (lua_type(L, idx) == LUA_TFUNCTION)
#define lauxh_iscfunction(L, idx)   lua_iscfunction(L, idx)
#define lauxh_isthread(L, idx)      (lua_type(L, idx) == LUA_TTHREAD)
#define lauxh_isuserdata(L, idx)    (lua_type(L, idx) == LUA_TUSERDATA)
#define lauxh_ispointer(L, idx)     (lua_type(L, idx) == LUA_TLIGHTUSERDATA)

#define lauxh_isinteger(L, idx) \
    (lauxh_isnumber(L, idx) && \
     (lua_Number)lua_tointeger(L, idx) == lua_tonumber(L, idx))


/* check argument */
#define lauxh_argerror(L, idx, fmt, ... ) do{ \
    char _errstr[255]; \
    snprintf( _errstr, 255, fmt, ##__VA_ARGS__ ); \
    luaL_argerror(L, idx, _errstr); \
}while(0)


#define lauxh_argcheck(L, cond, idx, fmt, ... ) do{ \
    if(!(cond)){ \
        lauxh_argerror( L, idx, fmt, ##__VA_ARGS__ ); \
    }\
}while(0)


/* string argument */

static inline const char *lauxh_checklstring( lua_State *L, int idx,
                                              size_t *len )
{
    return luaL_checklstring( L, idx, len );
}


static inline const char *lauxh_optlstring( lua_State *L, int idx,
                                            const char *def, size_t *len )
{
    if( lauxh_isnil( L, idx ) ){
        return def;
    }
    return lauxh_checklstring( L, idx, len );
}


static inline const char *lauxh_checkstring( lua_State *L, int idx )
{
    return luaL_checkstring( L, idx );
}


static inline const char *lauxh_optstring( lua_State *L, int idx,
                                           const char *def )
{
    if( lauxh_isnil( L, idx ) ){
        return def;
    }
    return lauxh_checkstring( L, idx );
}



/* number/integer argument */

static inline lua_Number lauxh_checknumber( lua_State *L, int idx )
{
    return luaL_checknumber( L, idx );
}


static inline lua_Number lauxh_optnumber( lua_State *L, int idx,
                                          lua_Number def )
{
    if( lauxh_isnil( L, idx ) ){
        return def;
    }
    return lauxh_checknumber( L, idx );
}


static inline lua_Integer lauxh_checkinteger( lua_State *L, int idx )
{
    lua_Number v = lauxh_checknumber( L, idx );

    lauxh_argcheck( L, v == (lua_Number)lua_tointeger(L, idx), idx,
                    "integer expected, got number" );

    return (lua_Integer)v;
}


static inline lua_Integer lauxh_optinteger( lua_State *L, int idx,
                                            lua_Integer def )
{
    if( lauxh_isnil( L, idx ) ){
        return def;
    }
    return lauxh_checkinteger( L, idx );
}



/* boolean argument */

static inline int lauxh_checkboolean( lua_State *L, int idx )
{
    luaL_checktype( L, idx, LUA_TBOOLEAN );
    return lua_toboolean( L, idx );
}


static inline int lauxh_optboolean( lua_State *L, int idx, int def )
{
    if( lauxh_isnil( L, idx ) ){
        return !!def;
    }
    return lauxh_checkboolean( L, idx );
}



/* table argument */

static inline void lauxh_checktable( lua_State *L, int idx )
{
    luaL_checktype( L, idx, LUA_TTABLE );
}


static inline void lauxh_checktableof( lua_State *L, int idx, const char *k )
{
    lua_pushstring( L, k );
    lua_rawget( L, idx );
    lauxh_checktable( L, -1 );
}


static inline const char *lauxh_checklstringof( lua_State *L, int idx,
                                                const char *k, size_t *len )
{
    const char *v = NULL;

    lua_pushstring( L, k );
    lua_rawget( L, idx );
    v = lauxh_checklstring( L, -1, len );
    lua_pop( L, 1 );

    return v;
}


static inline const char *lauxh_optlstringof( lua_State *L, int idx,
                                              const char *k, const char *def,
                                              size_t *len )
{
    const char *v = NULL;

    lua_pushstring( L, k );
    lua_rawget( L, idx );
    v = lauxh_optlstring( L, -1, def, len );
    lua_pop( L, 1 );

    return v;
}


static inline const char *lauxh_checkstringof( lua_State *L, int idx,
                                               const char *k )
{
    const char *v = NULL;

    lua_pushstring( L, k );
    lua_rawget( L, idx );
    v = lauxh_checkstring( L, -1 );
    lua_pop( L, 1 );

    return v;
}


static inline const char *lauxh_optstringof( lua_State *L, int idx,
                                             const char *k, const char *def )
{
    const char *v = NULL;

    lua_pushstring( L, k );
    lua_rawget( L, idx );
    v = lauxh_optstring( L, -1, def );
    lua_pop( L, 1 );

    return v;
}


static inline lua_Number lauxh_checknumberof( lua_State *L, int idx,
                                              const char *k )
{
    lua_Number v = 0;

    lua_pushstring( L, k );
    lua_rawget( L, idx );
    v = lauxh_checknumber( L, -1 );
    lua_pop( L, 1 );

    return v;
}


static inline lua_Number lauxh_optnumberof( lua_State *L, int idx,
                                            const char *k, lua_Number def )
{
    lua_Number v = 0;

    lua_pushstring( L, k );
    lua_rawget( L, idx );
    v = lauxh_optnumber( L, -1, def );
    lua_pop( L, 1 );

    return v;
}


static inline lua_Integer lauxh_checkintegerof( lua_State *L, int idx,
                                                const char *k )
{
    lua_Integer v = 0;

    lua_pushstring( L, k );
    lua_rawget( L, idx );
    v = lauxh_checkinteger( L, -1 );
    lua_pop( L, 1 );

    return v;
}


static inline lua_Integer lauxh_optintegerof( lua_State *L, int idx,
                                              const char *k, lua_Integer def )
{
    lua_Integer v = 0;

    lua_pushstring( L, k );
    lua_rawget( L, idx );
    v = lauxh_optinteger( L, -1, def );
    lua_pop( L, 1 );

    return v;
}


static inline int lauxh_checkbooleanof( lua_State *L, int idx, const char *k )
{
    int v = 0;

    lua_pushstring( L, k );
    lua_rawget( L, idx );
    v = lauxh_checkboolean( L, -1 );
    lua_pop( L, 1 );

    return v;
}


static inline int lauxh_optbooleanof( lua_State *L, int idx, const char *k, int def )
{
    int v = 0;

    lua_pushstring( L, k );
    lua_rawget( L, idx );
    v = lauxh_optboolean( L, -1, def );
    lua_pop( L, 1 );

    return v;
}



// table as array

static inline void lauxh_checktableat( lua_State *L, int idx, int row )
{
    lua_rawgeti( L, idx, row );
    lauxh_checktable( L, -1 );
}


static inline const char *lauxh_checklstringat( lua_State *L, int idx, int row,
                                                size_t *len )
{
    const char *v = NULL;

    lua_rawgeti( L, idx, row );
    v = lauxh_checklstring( L, -1, len );
    lua_pop( L, 1 );

    return v;
}


static inline const char *lauxh_optlstringat( lua_State *L, int idx, int row,
                                              const char *def, size_t *len )
{
    const char *v = NULL;

    lua_rawgeti( L, idx, row );
    v = lauxh_optlstring( L, -1, def, len );
    lua_pop( L, 1 );

    return v;
}


static inline const char *lauxh_checkstringat( lua_State *L, int idx, int row )
{
    const char *v = NULL;

    lua_rawgeti( L, idx, row );
    v = lauxh_checkstring( L, -1 );
    lua_pop( L, 1 );

    return v;
}


static inline const char *lauxh_optstringat( lua_State *L, int idx, int row,
                                             const char *def )
{
    const char *v = NULL;

    lua_rawgeti( L, idx, row );
    v = lauxh_optstring( L, -1, def );
    lua_pop( L, 1 );

    return v;
}


static inline lua_Number lauxh_checknumberat( lua_State *L, int idx, int row )
{
    lua_Number v = 0;

    lua_rawgeti( L, idx, row );
    v = lauxh_checknumber( L, -1 );
    lua_pop( L, 1 );

    return v;
}


static inline lua_Number lauxh_optnumberat( lua_State *L, int idx, int row,
                                            lua_Number def )
{
    lua_Number v = 0;

    lua_rawgeti( L, idx, row );
    v = lauxh_optnumber( L, -1, def );
    lua_pop( L, 1 );

    return v;
}


static inline lua_Integer lauxh_checkintegerat( lua_State *L, int idx, int row )
{
    lua_Integer v = 0;

    lua_rawgeti( L, idx, row );
    v = lauxh_checkinteger( L, -1 );
    lua_pop( L, 1 );

    return v;
}


static inline lua_Integer lauxh_optintegerat( lua_State *L, int idx, int row,
                                              lua_Integer def )
{
    lua_Integer v = 0;

    lua_rawgeti( L, idx, row );
    v = lauxh_optinteger( L, -1, def );
    lua_pop( L, 1 );

    return v;
}


static inline int lauxh_checkbooleanat( lua_State *L, int idx, int row )
{
    int v = 0;

    lua_rawgeti( L, idx, row );
    v = lauxh_checkboolean( L, -1 );
    lua_pop( L, 1 );

    return v;
}


static inline int lauxh_optbooleanat( lua_State *L, int idx, int row, int def )
{
    int v = 0;

    lua_rawgeti( L, idx, row );
    v = lauxh_optboolean( L, -1, def );
    lua_pop( L, 1 );

    return v;
}


/* thread argument */

static inline lua_State *lauxh_checkthread( lua_State *L, int idx )
{
    luaL_checktype( L, idx, LUA_TTHREAD );
    return lua_tothread( L, idx );
}



/* function argument */

static inline void lauxh_checkfunction( lua_State *L, int idx )
{
    luaL_checktype( L, idx, LUA_TFUNCTION );
}



/* cfunction argument */

static inline lua_CFunction lauxh_checkcfunction( lua_State *L, int idx )
{
    lauxh_argcheck( L, lua_iscfunction( L, idx ), idx,
                    "cfunction expected, got %s", lauxh_typenameat( L, idx ) );

    return lua_tocfunction( L, idx );
}



/* lightuserdata argument */

static inline const void *lauxh_checkpointer( lua_State *L, int idx )
{
    luaL_checktype( L, idx, LUA_TLIGHTUSERDATA );
    return lua_topointer( L, idx );
}



/* userdata argument */

static inline void *lauxh_checkudata( lua_State *L, int idx, const char *tname )
{
    return luaL_checkudata( L, idx, tname );
}


static inline void *lauxh_optudata( lua_State *L, int idx, const char *tname,
                                    void *def )
{
    if( lauxh_isnil( L, idx ) ){
        return def;
    }

    return lauxh_checkudata( L, idx, tname );
}


/* flag arguments */

static inline int lauxh_optflags( lua_State *L, int idx )
{
    const int argc = lua_gettop( L );
    int flg = 0;

    for(; idx <= argc; idx++ ){
        flg |= (int)lauxh_optinteger( L, idx, 0 );
    }

    return flg;
}


#endif
