#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <limits.h>
#include <assert.h>
#include "lauxhlib.h"

static int cfunction( lua_State *L ){
    return 0;
}


static int test_array( lua_State *L )
{
    size_t len = 0;

    lua_newtable( L );

    // string
    lauxh_pushstr2arr( L, 2, "string" );
    assert( lauxh_checkstringat( L, 1, 2 ) );
    assert( lauxh_checklstringat( L, 1, 2, &len ) );
    assert( len == 6 );
    // optstring
    assert( lauxh_optstringat( L, 1, 2, NULL ) );
    assert( lauxh_optlstringat( L, 1, 2, NULL, &len ) );
    assert( len == 6 );
    lauxh_pushnil2arr( L, 2 );
    assert( lauxh_optlstringat( L, 1, 2, NULL, &len ) == NULL );


    // number
    lauxh_pushnum2arr( L, 2, 1.1 );
    assert( lauxh_checknumberat( L, 1, 2 ) == 1.1 );
    // optnumber
    assert( lauxh_optnumberat( L, 1, 2, 0 ) == 1.1 );
    lauxh_pushnil2arr( L, 2 );
    assert( lauxh_optnumberat( L, 1, 2, 0 ) == 0 );


    // integer
    lauxh_pushint2arr( L, 2, 1 );
    assert( lauxh_checkintegerat( L, 1, 2 ) == 1 );
    // optnumber
    assert( lauxh_optintegerat( L, 1, 2, 0 ) == 1 );
    lauxh_pushnil2arr( L, 2 );
    assert( lauxh_optintegerat( L, 1, 2, 0 ) == 0 );


    // boolean
    lauxh_pushbool2arr( L, 2, 1 );
    assert( lauxh_checkbooleanat( L, 1, 2 ) == 1 );
    // optboolean
    lauxh_pushnil2arr( L, 2 );
    assert( lauxh_optbooleanat( L, 1, 2, 0 ) == 0 );


    // push table
    lua_newtable( L );
    lauxh_pushbool2arr( L, 1, 1 );
    lauxh_pushstr2arr( L, 2, "string" );
    lua_rawseti( L, -2, 2 );

    // table
    lauxh_checktableat( L, 1, 2 );
    assert( lauxh_rawlen( L, -1 ) == 2 );

    return 0;
}


static int test_table( lua_State *L )
{
    size_t len = 0;

    lua_newtable( L );

    // string
    lauxh_pushstr2tbl( L, "key", "string" );
    assert( lauxh_checkstringof( L, 1, "key" ) );
    assert( lauxh_checklstringof( L, 1, "key", &len ) );
    assert( len == 6 );
    // optstring
    assert( lauxh_optstringof( L, 1, "key", NULL ) );
    assert( lauxh_optlstringof( L, 1, "key", NULL, &len ) );
    assert( len == 6 );
    lauxh_pushnil2tbl( L, "key" );
    assert( lauxh_optlstringof( L, 1, "key", NULL, &len ) == NULL );


    // number
    lauxh_pushnum2tbl( L, "key", 1.1 );
    assert( lauxh_checknumberof( L, 1, "key" ) == 1.1 );
    // optnumber
    assert( lauxh_optnumberof( L, 1, "key", 0 ) == 1.1 );
    lauxh_pushnil2tbl( L, "key" );
    assert( lauxh_optnumberof( L, 1, "key", 0 ) == 0 );


    // integer
    lauxh_pushint2tbl( L, "key", 1 );
    assert( lauxh_checkintegerof( L, 1, "key" ) == 1 );
    // optnumber
    assert( lauxh_optintegerof( L, 1, "key", 0 ) == 1 );
    lauxh_pushnil2tbl( L, "key" );
    assert( lauxh_optintegerof( L, 1, "key", 0 ) == 0 );


    // boolean
    lauxh_pushbool2tbl( L, "key", 1 );
    assert( lauxh_checkbooleanof( L, 1, "key" ) == 1 );
    // optboolean
    lauxh_pushnil2tbl( L, "key" );
    assert( lauxh_optbooleanof( L, 1, "key", 0 ) == 0 );


    // push table
    lua_pushstring( L, "key" );
    lua_newtable( L );
    lauxh_pushbool2arr( L, 1, 1 );
    lua_rawset( L, -3 );

    // table
    lauxh_checktableof( L, 1, "key" );
    assert( lauxh_rawlen( L, -1 ) == 1 );

    return 0;
}


static int test_arguments( lua_State *L )
{
    void *ptr = NULL;
    size_t len = 0;

    // string
    lua_pushstring( L, "string" );
    assert( lauxh_checkstring( L, -1 ) );
    assert( lauxh_optstring( L, -1, NULL ) );
    assert( lauxh_checklstring( L, -1, &len ) );
    assert( len == 6 );
    assert( lauxh_optlstring( L, -1, NULL, &len ) );
    assert( len == 6 );
    // optstring
    lua_settop( L, 0 );
    lua_pushnil( L );
    assert( lauxh_optstring( L, -1, NULL ) == NULL );
    assert( lauxh_optlstring( L, -1, NULL, &len ) == NULL );


    // number
    lua_settop( L, 0 );
    lua_pushnumber( L, 1.1 );
    assert( lauxh_checknumber( L, -1 ) == 1.1 );
    // optnumber
    lua_settop( L, 0 );
    lua_pushnumber( L, 1.1 );
    assert( lauxh_optnumber( L, -1, 0 ) == 1.1 );
    lua_pushnil( L );
    assert( lauxh_optnumber( L, -1, 0 ) == 0 );


    // integer
    lua_settop( L, 0 );
    lua_pushinteger( L, 1 );
    assert( lauxh_checkinteger( L, -1 ) == 1 );
    // optinteger
    lua_settop( L, 0 );
    lua_pushinteger( L, 1 );
    assert( lauxh_optinteger( L, -1, 2 ) == 1 );
    lua_pushnil( L );
    assert( lauxh_optinteger( L, -1, 2 ) == 2 );


    // boolean
    lua_settop( L, 0 );
    lua_pushboolean( L, 1 );
    assert( lauxh_checkboolean( L, -1 ) == 1 );
    // optboolean
    lua_pushnil( L );
    assert( lauxh_optboolean( L, -1, 0 ) == 0 );


    // table
    lua_settop( L, 0 );
    lua_newtable( L );
    lauxh_checktable( L, -1 );


    // thread
    lua_settop( L, 0 );
    ptr = (void*)lua_newthread( L );
    assert( (uintptr_t)lauxh_checkthread( L, -1 ) == (uintptr_t)ptr );


    // lightuserdata
    lua_settop( L, 0 );
    ptr = malloc(0);
    lua_pushlightuserdata( L, ptr );
    assert( (uintptr_t)lauxh_checkpointer( L, -1 ) == (uintptr_t)ptr );
    free( ptr );


    // cfunction
    lua_settop( L, 0 );
    lua_pushcfunction( L, cfunction );
    assert( (uintptr_t)lauxh_checkcfunction( L, -1 ) == (uintptr_t)cfunction );


    // function
    lua_settop( L, 0 );
    assert( luaL_loadstring( L, "function fn()end" ) == 0 );
    lauxh_checkfunction( L, -1 );


    // flags
    lua_settop( L, 0 );
    lua_pushinteger( L, 0x1 );
    lua_pushinteger( L, 0x2 );
    lua_pushinteger( L, 0x4 );
    lua_pushinteger( L, 0x8 );
    assert( lauxh_optflags( L, 1 ) == 0xF );


    return 0;
}


static int test_reference( lua_State *L )
{
    int ref = LUA_NOREF;

    assert( !lauxh_isref( LUA_NOREF ) );
    assert( !lauxh_isref( LUA_REFNIL ) );

    lua_pushstring( L, "string" );
    ref = lauxh_ref( L );
    assert( lauxh_isref( ref ) );

    ref = lauxh_unref( L, ref );
    assert( ref == LUA_NOREF );

    lua_pushstring( L, "string" );
    ref = lauxh_refat( L, -1 );
    assert( lauxh_isref( ref ) );

    lauxh_pushref( L, ref );
    assert( lauxh_isstring( L, -1 ) );

    ref = lauxh_unref( L, ref );
    assert( ref == LUA_NOREF );

    return 0;
}


static int test_is( lua_State *L )
{
    void *ptr = NULL;

    lua_pushnil( L );
    assert( lauxh_isnil( L, -1 ) );

    // string
    lua_settop( L, 0 );
    lua_pushstring( L, "string" );
    assert( lauxh_isstring( L, -1 ) );

    // number
    lua_settop( L, 0 );
    lua_pushnumber( L, 1.1 );
    assert( lauxh_isnumber( L, -1 ) );

    // boolean true
    lua_settop( L, 0 );
    lua_pushboolean( L, 1 );
    assert( lauxh_isboolean( L, -1 ) );

    // boolean false
    lua_settop( L, 0 );
    lua_pushboolean( L, 0 );
    assert( lauxh_isboolean( L, -1 ) );

    // table
    lua_settop( L, 0 );
    lua_newtable( L );
    assert( lauxh_istable( L, -1 ) );

    // thread
    lua_settop( L, 0 );
    lua_newthread( L );
    assert( lauxh_isthread( L, -1 ) );

    // userdata
    lua_settop( L, 0 );
    lua_newuserdata( L, sizeof(1) );
    assert( lauxh_isuserdata( L, -1 ) );

    // lightuserdata
    lua_settop( L, 0 );
    ptr = malloc(0);
    lua_pushlightuserdata( L, ptr );
    assert( lauxh_ispointer( L, -1 ) );
    free( ptr );

    // integer
    lua_settop( L, 0 );
    lua_pushinteger( L, 1 );
    assert( lauxh_isinteger( L, -1 ) );

    // floating-point number is not integer
    lua_settop( L, 0 );
    lua_pushnumber( L, 1.1 );
    assert( !lauxh_isinteger( L, -1 ) );

    // cfunction
    lua_settop( L, 0 );
    lua_pushcfunction( L, cfunction );
    assert( lauxh_iscfunction( L, -1 ) );

    // function
    lua_settop( L, 0 );
    assert( luaL_loadstring( L, "function fn()end" ) == 0 );
    assert( lauxh_isfunction( L, -1 ) );

    return 0;
}


LUALIB_API int luaopen_lauxhlib( lua_State *L )
{
    struct luaL_Reg method[] = {
        { "test_is", test_is },
        { "test_reference", test_reference },
        { "test_arguments", test_arguments },
        { "test_table", test_table },
        { "test_array", test_array },
        { NULL, NULL }
    };
    struct luaL_Reg *ptr = method;

    lua_settop( L, 0 );
    while( ptr->name ){
        printf( "%s\n", ptr->name );
        ptr->func( L );
        lua_settop( L, 0 );
        ptr++;
    }

    return 0;
}
