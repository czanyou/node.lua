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
 *  src/x509_csr.c
 *  lua-mbedtls
 *  Created by Masatoshi Teruya on 16/07/19.
 */


#include "lmbedtls.h"


static int x509_csr_info( lua_State *L )
{
    mbedtls_x509_csr *csr = lauxh_checkudata( L, 1, LMBEDTLS_X509_CSR_MT );
    const char *prefix = lauxh_optstring( L, 2, "" );
    // FIXME: should allocate from heap
    char buf[100000] = { 0 };
    int rc = mbedtls_x509_csr_info( buf, 100000, prefix, csr );

    if( rc ){
        lmbedtls_errbuf_t errbuf;

        lmbedtls_strerror( rc, errbuf );
        lua_pushnil( L );
        lua_pushstring( L, errbuf );
        return 2;
    }

    lua_pushlstring( L, buf, rc );

    return 1;
}


static int x509_csr_tostring( lua_State *L )
{
    TOSTRING_MT( L, LMBEDTLS_X509_CSR_MT );
    return 1;
}


static int x509_csr_gc( lua_State *L )
{
    mbedtls_x509_csr *csr = lua_touserdata( L, 1 );

    mbedtls_x509_csr_free( csr );

    return 0;
}


static int x509_csr_parse_file( lua_State *L )
{
#if defined(MBEDTLS_FS_IO)
    const char *path = lauxh_checkstring( L, 1 );
    mbedtls_x509_csr *csr = lua_newuserdata( L, sizeof( mbedtls_x509_csr ) );
    int rc = 0;

    if( !csr ){
        lua_pushnil( L );
        lua_pushstring( L, strerror( errno ) );
        return 2;
    }

    mbedtls_x509_csr_init( csr );
    if( ( rc = mbedtls_x509_csr_parse_file( csr, path ) ) ){
        lmbedtls_errbuf_t errbuf;

        mbedtls_x509_csr_free( csr );
        lmbedtls_strerror( rc, errbuf );
        lua_pushnil( L );
        lua_pushstring( L, errbuf );
        return 2;
    }

    lauxh_setmetatable( L, LMBEDTLS_X509_CSR_MT );

    return 1;

#else
    lmbedtls_errbuf_t errbuf;

    lmbedtls_strerror( MBEDTLS_ERR_X509_FEATURE_UNAVAILABLE, errbuf );
    lua_pushnil( L );
    lua_pushstring( L, errbuf );

    return 2;

#endif
}


typedef int (*parsefn)( mbedtls_x509_csr *, const unsigned char *, size_t );

static inline int x509_csr_parse_buffer( lua_State *L, parsefn fn )
{
#if defined(MBEDTLS_X509_CSR_PARSE_C)
    size_t len = 0;
    const char *buf = lauxh_checklstring( L, 1, &len );
    mbedtls_x509_csr *csr = lua_newuserdata( L, sizeof( mbedtls_x509_csr ) );
    int rc = 0;

    if( !csr ){
        lua_pushnil( L );
        lua_pushstring( L, strerror( errno ) );
        return 2;
    }

    mbedtls_x509_csr_init( csr );
    if( ( rc = fn( csr, (const unsigned char*)buf, len ) ) ){
        lmbedtls_errbuf_t errbuf;

        mbedtls_x509_csr_free( csr );
        lmbedtls_strerror( rc, errbuf );
        lua_pushnil( L );
        lua_pushstring( L, errbuf );
        return 2;
    }

    lauxh_setmetatable( L, LMBEDTLS_X509_CSR_MT );

    return 1;

#else
    lmbedtls_errbuf_t errbuf;

    lmbedtls_strerror( MBEDTLS_ERR_X509_FEATURE_UNAVAILABLE, errbuf );
    lua_pushnil( L );
    lua_pushstring( L, errbuf );

    return 2;

#endif
}

static int x509_csr_parse( lua_State *L )
{
    return x509_csr_parse_buffer( L, mbedtls_x509_csr_parse );
}

static int x509_csr_parse_der( lua_State *L )
{
    return x509_csr_parse_buffer( L, mbedtls_x509_csr_parse_der );
}


LUALIB_API int luaopen_lmbedtls_x509_csr( lua_State *L )
{
    struct luaL_Reg mmethods[] = {
        { "__gc",       x509_csr_gc },
        { "__tostring", x509_csr_tostring },
        { NULL, NULL }
    };

    struct luaL_Reg methods[] = {
        { "info",       x509_csr_info },
        { NULL, NULL }
    };

    struct luaL_Reg x509_csr_functions[] = {
        { "parse",      x509_csr_parse },
        { "parse_der",  x509_csr_parse_der },
        { "parse_file", x509_csr_parse_file },
        { NULL, NULL }
    };

    struct luaL_Reg *function = x509_csr_functions;

    // register metatable
    lmbedtls_newmetatable( L, LMBEDTLS_X509_CSR_MT, mmethods, methods );

    // create table
    lua_newtable( L );

    // add functions
    while ( function->name ) {
        lauxh_pushfn2tbl( L, function->name, function->func );
        function++;
    }

    return 1;
}

