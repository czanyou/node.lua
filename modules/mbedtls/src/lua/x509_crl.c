/*
 *  Copyright (C) 2016 Masatoshi Teruya
 *
 *  Permission is hereby granted, free of charge, to any person obtaining a
 *  copy of this software and associated documentation files (the "Software"),
 *  to deal in the Software without restriction, including without limitation
 *  the rights to use, copy, modify, merge, publish, distribute, sublicense,
 *  and/or sell copies of the Software, and to permit persons to whom the
 *  Software is furnished to do so, subject to the following conditions:
 *
 *  The above copyright notice and this permission notice shall be included in
 *  all copies or substantial portions of the Software.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 *  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 *  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
 *  THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 *  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 *  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 *  DEALINGS IN THE SOFTWARE.
 *
 *  src/x509_crl.c
 *  lua-mbedtls
 *  Created by Masatoshi Teruya on 16/07/13.
 */


#include "lmbedtls.h"


static int x509_crl_info( lua_State *L )
{
    mbedtls_x509_crl *crl = lauxh_checkudata( L, 1, LMBEDTLS_X509_CRL_MT );
    const char *prefix = lauxh_optstring( L, 2, "" );
    // FIXME: should allocate from heap
    char buf[100000] = { 0 };
    int rc = mbedtls_x509_crl_info( buf, 100000, prefix, crl );

    if( rc < 0 ){
        lmbedtls_errbuf_t errbuf;

        lmbedtls_strerror( rc, errbuf );
        lua_pushnil( L );
        lua_pushstring( L, errbuf );
        return 2;
    }

    lua_pushlstring( L, buf, rc );

    return 1;
}


static int x509_crl_parse_file( lua_State *L )
{
#if defined(MBEDTLS_FS_IO)
    mbedtls_x509_crl *crl = lauxh_checkudata( L, 1, LMBEDTLS_X509_CRL_MT );
    const char *path = lauxh_checkstring( L, 2 );
    int rc = mbedtls_x509_crl_parse_file( crl, path );

    if( rc ){
        lmbedtls_errbuf_t errbuf;

        lmbedtls_strerror( rc, errbuf );
        lua_pushboolean( L, 0 );
        lua_pushstring( L, errbuf );
        return 2;
    }

    lua_pushboolean( L, 1 );

    return 1;

#else
    lmbedtls_errbuf_t errbuf;

    lmbedtls_strerror( MBEDTLS_ERR_PK_FEATURE_UNAVAILABLE, errbuf );
    lua_pushboolean( L, 0 );
    lua_pushstring( L, errbuf );

    return 2;

#endif
}


typedef int (*parsefn)( mbedtls_x509_crl *, const unsigned char *, size_t );

static inline int x509_crl_parse_buffer( lua_State *L, parsefn fn )
{
    mbedtls_x509_crl *crl = lauxh_checkudata( L, 1, LMBEDTLS_X509_CRL_MT );
    size_t len = 0;
    const char *buf = lauxh_checklstring( L, 2, &len );
    int rc = fn( crl, (const unsigned char*)buf, len );

    if( rc ){
        lmbedtls_errbuf_t errbuf;

        lmbedtls_strerror( rc, errbuf );
        lua_pushboolean( L, 0 );
        lua_pushstring( L, errbuf );
        return 2;
    }

    lua_pushboolean( L, 1 );

    return 1;
}

static int x509_crl_parse( lua_State *L )
{
    return x509_crl_parse_buffer( L, mbedtls_x509_crl_parse );
}

static int x509_crl_parse_der( lua_State *L )
{
    return x509_crl_parse_buffer( L, mbedtls_x509_crl_parse_der );
}


static int x509_crl_tostring( lua_State *L )
{
    TOSTRING_MT( L, LMBEDTLS_X509_CRL_MT );
    return 1;
}


static int x509_crl_gc( lua_State *L )
{
    mbedtls_x509_crl *crl = lua_touserdata( L, 1 );

    mbedtls_x509_crl_free( crl );

    return 0;
}


static int x509_crl_new( lua_State *L )
{
    mbedtls_x509_crl *crl = lua_newuserdata( L, sizeof( mbedtls_x509_crl ) );

    if( !crl ){
        lua_pushnil( L );
        lua_pushstring( L, strerror( errno ) );
        return 2;
    }

    mbedtls_x509_crl_init( crl );
    lauxh_setmetatable( L, LMBEDTLS_X509_CRL_MT );

    return 1;
}


LUALIB_API int luaopen_lmbedtls_x509_crl( lua_State *L )
{
    struct luaL_Reg mmethods[] = {
        { "__gc",       x509_crl_gc },
        { "__tostring", x509_crl_tostring },
        { NULL, NULL }
    };

    struct luaL_Reg methods[] = {
        { "info",       x509_crl_info },
        { "parse",      x509_crl_parse },
        { "parse_der",  x509_crl_parse_der },
        { "parse_file", x509_crl_parse_file },
        { NULL, NULL }
    };

    struct luaL_Reg x509_crl_functions[] = {
        { "new",        x509_crl_new },
        { NULL, NULL }
    };

    struct luaL_Reg *function = x509_crl_functions;

    // register metatable
    lmbedtls_newmetatable( L, LMBEDTLS_X509_CRL_MT, mmethods, methods );

    // create table
    lua_newtable( L );

    // add functions
    while ( function->name ) {
        lauxh_pushfn2tbl( L, function->name, function->func );
        function++;
    }

    return 1;
}

