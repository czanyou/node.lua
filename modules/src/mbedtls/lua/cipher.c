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
 *  src/cipher.c
 *  lua-mbedtls
 *  Created by Masatoshi Teruya on 16/05/21.
 */


#include "lmbedtls.h"


static int cipher_check_tag( lua_State *L )
{
    lmbedtls_errbuf_t errbuf;
#if defined(MBEDTLS_GCM_C)
    mbedtls_cipher_context_t *cph = lauxh_checkudata( L, 1, LMBEDTLS_CIPHER_MT );
    size_t len = 0;
    const char *tag = lauxh_checklstring( L, 2, &len );
    int rc = mbedtls_cipher_check_tag( cph, (uint8_t*)tag, len );

    if( rc == 0 ){
        lua_pushboolean( L, 1 );
        return 1;
    }

#else
    int rc = MBEDTLS_ERR_CIPHER_FEATURE_UNAVAILABLE;

#endif

    // got error
    lmbedtls_strerror( rc, errbuf );
    lua_pushboolean( L, 0 );
    lua_pushstring( L, errbuf );

    return 2;
}


static int cipher_write_tag( lua_State *L )
{
    lmbedtls_errbuf_t errbuf;
#if defined(MBEDTLS_GCM_C)
    mbedtls_cipher_context_t *cph = lauxh_checkudata( L, 1, LMBEDTLS_CIPHER_MT );
    size_t len = 0;
    const char *tag = lauxh_checklstring( L, 2, &len );
    int rc = mbedtls_cipher_write_tag( cph, (uint8_t*)tag, len );

    if( rc == 0 ){
        lua_pushboolean( L, 1 );
        return 1;
    }

#else
    int rc = MBEDTLS_ERR_CIPHER_FEATURE_UNAVAILABLE;

#endif

    // got error
    lmbedtls_strerror( rc, errbuf );
    lua_pushboolean( L, 0 );
    lua_pushstring( L, errbuf );

    return 2;
}


static int cipher_finish( lua_State *L )
{
    mbedtls_cipher_context_t *cph = lauxh_checkudata( L, 1, LMBEDTLS_CIPHER_MT );
    size_t len = 0;
    uint8_t output[BUFSIZ] = {0};
    int rc = mbedtls_cipher_finish( cph, output, &len );
    lmbedtls_errbuf_t errbuf;

    if( rc == 0 ){
        lua_pushlstring( L, (const char*)output, len );
        return 1;
    }

    // got error
    lmbedtls_strerror( rc, errbuf );
    lua_pushnil( L );
    lua_pushstring( L, errbuf );

    return 2;
}


static int cipher_update( lua_State *L )
{
    mbedtls_cipher_context_t *cph = lauxh_checkudata( L, 1, LMBEDTLS_CIPHER_MT );
    size_t len = 0;
    const char *data = lauxh_checklstring( L, 2, &len );

    const uint8_t *ptr = (const uint8_t*)data;
    size_t blksize = mbedtls_cipher_get_block_size( cph );
    size_t tail = len % blksize;
    size_t last = len - tail;
    size_t offset = 0;
    size_t olen = 0;
    uint8_t output[BUFSIZ] = {0};
    int rc = 0;
    lmbedtls_errbuf_t errbuf;

    lua_settop( L, 0 );

    for (; offset < last; offset += blksize ) {
        rc = mbedtls_cipher_update( cph, ptr + offset, blksize, output, &olen );
        if (rc != 0) {
            goto FAILED;
        }
        lua_pushlstring( L, (const char*)output, olen );
    }

    if (tail) {
        rc = mbedtls_cipher_update( cph, ptr + offset, tail, output, &olen );
        if ( rc == 0 ) {
            lua_pushlstring( L, (const char*)output, olen );
        }
    }

    if (rc == 0) {
        lua_concat( L, lua_gettop( L ) );
        return 1;
    }

FAILED:
    // got error
    lmbedtls_strerror( rc, errbuf );
    lua_settop( L, 0 );
    lua_pushnil( L );
    lua_pushstring( L, errbuf );

    return 2;
}


static int cipher_update_ad( lua_State *L )
{
    lmbedtls_errbuf_t errbuf;
#if defined(MBEDTLS_GCM_C)
    mbedtls_cipher_context_t *cph = lauxh_checkudata( L, 1, LMBEDTLS_CIPHER_MT );
    size_t len = 0;
    const char *data = lauxh_checklstring( L, 2, &len );
    int rc = mbedtls_cipher_update_ad( cph, (const uint8_t*)data, len );

    if( rc == 0 ){
        lua_pushboolean( L, 1 );
        return 1;
    }

#else
    int rc = MBEDTLS_ERR_CIPHER_FEATURE_UNAVAILABLE;

#endif

    // got error
    lmbedtls_strerror( rc, errbuf );
    lua_pushboolean( L, 0 );
    lua_pushstring( L, errbuf );

    return 2;
}


static int cipher_reset( lua_State *L )
{
    mbedtls_cipher_context_t *cph = lauxh_checkudata( L, 1, LMBEDTLS_CIPHER_MT );
    int rc = mbedtls_cipher_reset( cph );
    lmbedtls_errbuf_t errbuf;

    if( rc == 0 ){
        lua_pushboolean( L, 1 );
        return 1;
    }

    // got error
    lmbedtls_strerror( rc, errbuf );
    lua_pushboolean( L, 0 );
    lua_pushstring( L, errbuf );

    return 2;
}


static int cipher_set_iv( lua_State *L )
{
    mbedtls_cipher_context_t *cph = lauxh_checkudata( L, 1, LMBEDTLS_CIPHER_MT );
    size_t len = 0;
    const char *iv = lauxh_checklstring( L, 2, &len );
    int rc = mbedtls_cipher_set_iv( cph, (const uint8_t*)iv, len );
    lmbedtls_errbuf_t errbuf;

    if ( rc == 0 ) {
        lua_pushboolean( L, 1 );
        return 1;
    }

    // got error
    lmbedtls_strerror( rc, errbuf );
    lua_pushboolean( L, 0 );
    lua_pushstring( L, errbuf );

    return 2;
}


static int cipher_set_padding_mode( lua_State *L )
{
    lmbedtls_errbuf_t errbuf;
#if defined(MBEDTLS_CIPHER_MODE_WITH_PADDING)
    mbedtls_cipher_context_t *cph = lauxh_checkudata( L, 1, LMBEDTLS_CIPHER_MT );
    mbedtls_cipher_padding_t pad = lauxh_checkinteger( L, 2 );
    int rc = mbedtls_cipher_set_padding_mode( cph, pad );

    if( rc == 0 ){
        lua_pushboolean( L, 1 );
        return 1;
    }

#else
    int rc = MBEDTLS_ERR_CIPHER_FEATURE_UNAVAILABLE;

#endif

    // got error
    lmbedtls_strerror( rc, errbuf );
    lua_pushboolean( L, 0 );
    lua_pushstring( L, errbuf );

    return 2;
}


static int cipher_set_key( lua_State *L )
{
    mbedtls_cipher_context_t *cph = lauxh_checkudata( L, 1, LMBEDTLS_CIPHER_MT );
    size_t len = 0;
    const char *key = lauxh_checklstring( L, 2, &len );
    const mbedtls_operation_t op = lauxh_checkinteger( L, 3 );
    int rc = mbedtls_cipher_setkey( cph, (const uint8_t*)key,
                                   (int)len * CHAR_BIT, op );
    lmbedtls_errbuf_t errbuf;

    if (rc == 0) {
        lua_pushboolean( L, 1 );
        return 1;
    }

    // got error
    lmbedtls_strerror( rc, errbuf );
    lua_pushboolean( L, 0 );
    lua_pushstring( L, errbuf );

    return 2;
}


static int cipher_get_operation( lua_State *L )
{
    mbedtls_cipher_context_t *cph = lauxh_checkudata( L, 1, LMBEDTLS_CIPHER_MT );

    lua_pushinteger( L, mbedtls_cipher_get_operation( cph ) );

    return 1;
}


static int cipher_get_key_bit_len( lua_State *L )
{
    mbedtls_cipher_context_t *cph = lauxh_checkudata( L, 1, LMBEDTLS_CIPHER_MT );

    lua_pushinteger( L, mbedtls_cipher_get_key_bitlen( cph ) );

    return 1;
}


static int cipher_get_name( lua_State *L )
{
    mbedtls_cipher_context_t *cph = lauxh_checkudata( L, 1, LMBEDTLS_CIPHER_MT );
    const char *name = mbedtls_cipher_get_name( cph );

    if( name ){
        lua_pushstring( L, name );
    }
    else {
        lua_pushnil( L );
    }

    return 1;
}


static int cipher_get_type( lua_State *L )
{
    mbedtls_cipher_context_t *cph = lauxh_checkudata( L, 1, LMBEDTLS_CIPHER_MT );

    lua_pushinteger( L, mbedtls_cipher_get_type( cph ) );

    return 1;
}


static int cipher_get_iv_size( lua_State *L )
{
    mbedtls_cipher_context_t *cph = lauxh_checkudata( L, 1, LMBEDTLS_CIPHER_MT );

    lua_pushinteger( L, mbedtls_cipher_get_iv_size( cph ) );

    return 1;
}


static int cipher_get_cipher_mode( lua_State *L )
{
    mbedtls_cipher_context_t *cph = lauxh_checkudata( L, 1, LMBEDTLS_CIPHER_MT );

    lua_pushinteger( L, mbedtls_cipher_get_cipher_mode( cph ) );

    return 1;
}


static int cipher_get_block_size( lua_State *L )
{
    mbedtls_cipher_context_t *cph = lauxh_checkudata( L, 1, LMBEDTLS_CIPHER_MT );

    lua_pushinteger( L, mbedtls_cipher_get_block_size( cph ) );

    return 1;
}


static int cipher_init( lua_State *L )
{
    mbedtls_cipher_context_t *cph = lauxh_checkudata( L, 1, LMBEDTLS_CIPHER_MT );
    const mbedtls_cipher_type_t type = lauxh_optinteger( L, 2, MBEDTLS_CIPHER_NONE );
    const mbedtls_cipher_info_t *info = NULL;
    int rc = 0;
    lmbedtls_errbuf_t errstr;

    // use current cipher info
    if( type == MBEDTLS_CIPHER_NONE ){
        info = cph->cipher_info;
    }
    // check argument
    else if( !( info = mbedtls_cipher_info_from_type( type ) ) ){
        lua_pushboolean( L, 0 );
        lua_pushstring( L, strerror( EINVAL ) );
        return 2;
    }

    mbedtls_cipher_free( cph );
    rc = mbedtls_cipher_setup( cph, info );
    if( rc == 0 ){
        lua_pushboolean( L, 1 );
        return 1;
    }

    // got error
    lmbedtls_strerror( rc, errstr );
    lua_pushboolean( L, 0 );
    lua_pushstring( L, errstr );

    return 2;
}


static int cipher_tostring( lua_State *L )
{
    TOSTRING_MT( L, LMBEDTLS_CIPHER_MT );
    return 1;
}


static int cipher_gc( lua_State *L )
{
    mbedtls_cipher_context_t *cph = lua_touserdata( L, 1 );

    mbedtls_cipher_free( cph );

    return 0;
}


static int cipher_new( lua_State *L )
{
    const mbedtls_cipher_type_t type = lauxh_checkinteger( L, 1 );
    const mbedtls_cipher_info_t *info = mbedtls_cipher_info_from_type( type );
    mbedtls_cipher_context_t *cph = NULL;
    int rc = 0;

    if ( !info ) {
        lua_pushnil( L );
        lua_pushstring( L, strerror( EINVAL ) );
        return 2;
    }

    cph = lua_newuserdata( L, sizeof( mbedtls_cipher_context_t ) );
    if ( !cph ) {
        lua_pushnil( L );
        lua_pushstring( L, strerror( errno ) );
        return 2;
    }

    mbedtls_cipher_init( cph );
    if ( ( rc = mbedtls_cipher_setup( cph, info ) ) != 0 ) {
        lmbedtls_errbuf_t errstr;

        lmbedtls_strerror( rc, errstr );
        lua_pushnil( L );
        lua_pushstring( L, errstr );

        return 2;
    }

    lauxh_setmetatable( L, LMBEDTLS_CIPHER_MT );

    return 1;
}


LUALIB_API int luaopen_lmbedtls_cipher( lua_State *L )
{
    struct luaL_Reg cipher_mmethods[] = {
        { "__gc",       cipher_gc },
        { "__tostring", cipher_tostring },
        { NULL, NULL }
    };

    struct luaL_Reg cipher_methods[] = {
        { "check_tag",          cipher_check_tag },
        { "finish",             cipher_finish },
        { "get_block_size",     cipher_get_block_size },
        { "get_cipher_mode",    cipher_get_cipher_mode },
        { "get_iv_size",        cipher_get_iv_size },
        { "get_key_bit_len",    cipher_get_key_bit_len },
        { "get_name",           cipher_get_name },
        { "get_operation",      cipher_get_operation },
        { "get_type",           cipher_get_type },
        { "init",               cipher_init },
        { "reset",              cipher_reset },
        { "set_iv",             cipher_set_iv },
        { "set_key",            cipher_set_key },
        { "set_padding_mode",   cipher_set_padding_mode },
        { "update",             cipher_update },
        { "update_ad",          cipher_update_ad },
        { "write_tag",          cipher_write_tag },
        { NULL, NULL }
    };

    // register metatable
    lmbedtls_newmetatable( L, LMBEDTLS_CIPHER_MT, cipher_mmethods, cipher_methods );

    // create table
    lua_newtable( L );

    // add new function
    lauxh_pushfn2tbl( L, "new", cipher_new );

    // add mbedtls_cipher_type_t
    lauxh_pushint2tbl( L, "AES_128_ECB",        MBEDTLS_CIPHER_AES_128_ECB );
    lauxh_pushint2tbl( L, "AES_192_ECB",        MBEDTLS_CIPHER_AES_192_ECB );
    lauxh_pushint2tbl( L, "AES_256_ECB",        MBEDTLS_CIPHER_AES_256_ECB );
    lauxh_pushint2tbl( L, "AES_128_CBC",        MBEDTLS_CIPHER_AES_128_CBC );
    lauxh_pushint2tbl( L, "AES_192_CBC",        MBEDTLS_CIPHER_AES_192_CBC );
    lauxh_pushint2tbl( L, "AES_256_CBC",        MBEDTLS_CIPHER_AES_256_CBC );
    lauxh_pushint2tbl( L, "AES_128_CFB128",     MBEDTLS_CIPHER_AES_128_CFB128 );
    lauxh_pushint2tbl( L, "AES_192_CFB128",     MBEDTLS_CIPHER_AES_192_CFB128 );
    lauxh_pushint2tbl( L, "AES_256_CFB128",     MBEDTLS_CIPHER_AES_256_CFB128 );
    lauxh_pushint2tbl( L, "AES_128_CTR",        MBEDTLS_CIPHER_AES_128_CTR );
    lauxh_pushint2tbl( L, "AES_192_CTR",        MBEDTLS_CIPHER_AES_192_CTR );
    lauxh_pushint2tbl( L, "AES_256_CTR",        MBEDTLS_CIPHER_AES_256_CTR );
    lauxh_pushint2tbl( L, "AES_128_GCM",        MBEDTLS_CIPHER_AES_128_GCM );
    lauxh_pushint2tbl( L, "AES_192_GCM",        MBEDTLS_CIPHER_AES_192_GCM );
    lauxh_pushint2tbl( L, "AES_256_GCM",        MBEDTLS_CIPHER_AES_256_GCM );
    lauxh_pushint2tbl( L, "CAMELLIA_128_ECB",   MBEDTLS_CIPHER_CAMELLIA_128_ECB );
    lauxh_pushint2tbl( L, "CAMELLIA_192_ECB",   MBEDTLS_CIPHER_CAMELLIA_192_ECB );
    lauxh_pushint2tbl( L, "CAMELLIA_256_ECB",   MBEDTLS_CIPHER_CAMELLIA_256_ECB );
    lauxh_pushint2tbl( L, "CAMELLIA_128_CBC",   MBEDTLS_CIPHER_CAMELLIA_128_CBC );
    lauxh_pushint2tbl( L, "CAMELLIA_192_CBC",   MBEDTLS_CIPHER_CAMELLIA_192_CBC );
    lauxh_pushint2tbl( L, "CAMELLIA_256_CBC",   MBEDTLS_CIPHER_CAMELLIA_256_CBC );
    lauxh_pushint2tbl( L, "CAMELLIA_128_CFB128",MBEDTLS_CIPHER_CAMELLIA_128_CFB128 );
    lauxh_pushint2tbl( L, "CAMELLIA_192_CFB128",MBEDTLS_CIPHER_CAMELLIA_192_CFB128 );
    lauxh_pushint2tbl( L, "CAMELLIA_256_CFB128",MBEDTLS_CIPHER_CAMELLIA_256_CFB128 );
    lauxh_pushint2tbl( L, "CAMELLIA_128_CTR",   MBEDTLS_CIPHER_CAMELLIA_128_CTR );
    lauxh_pushint2tbl( L, "CAMELLIA_192_CTR",   MBEDTLS_CIPHER_CAMELLIA_192_CTR );
    lauxh_pushint2tbl( L, "CAMELLIA_256_CTR",   MBEDTLS_CIPHER_CAMELLIA_256_CTR );
    lauxh_pushint2tbl( L, "CAMELLIA_128_GCM",   MBEDTLS_CIPHER_CAMELLIA_128_GCM );
    lauxh_pushint2tbl( L, "CAMELLIA_192_GCM",   MBEDTLS_CIPHER_CAMELLIA_192_GCM );
    lauxh_pushint2tbl( L, "CAMELLIA_256_GCM",   MBEDTLS_CIPHER_CAMELLIA_256_GCM );
    lauxh_pushint2tbl( L, "DES_ECB",            MBEDTLS_CIPHER_DES_ECB );
    lauxh_pushint2tbl( L, "DES_CBC",            MBEDTLS_CIPHER_DES_CBC );
    lauxh_pushint2tbl( L, "DES_EDE_ECB",        MBEDTLS_CIPHER_DES_EDE_ECB );
    lauxh_pushint2tbl( L, "DES_EDE_CBC",        MBEDTLS_CIPHER_DES_EDE_CBC );
    lauxh_pushint2tbl( L, "DES_EDE3_ECB",       MBEDTLS_CIPHER_DES_EDE3_ECB );
    lauxh_pushint2tbl( L, "DES_EDE3_CBC",       MBEDTLS_CIPHER_DES_EDE3_CBC );
    lauxh_pushint2tbl( L, "BLOWFISH_ECB",       MBEDTLS_CIPHER_BLOWFISH_ECB );
    lauxh_pushint2tbl( L, "BLOWFISH_CBC",       MBEDTLS_CIPHER_BLOWFISH_CBC );
    lauxh_pushint2tbl( L, "BLOWFISH_CFB64",     MBEDTLS_CIPHER_BLOWFISH_CFB64 );
    lauxh_pushint2tbl( L, "BLOWFISH_CTR",       MBEDTLS_CIPHER_BLOWFISH_CTR );
    lauxh_pushint2tbl( L, "ARC4_128",           MBEDTLS_CIPHER_ARC4_128 );
    lauxh_pushint2tbl( L, "AES_128_CCM",        MBEDTLS_CIPHER_AES_128_CCM );
    lauxh_pushint2tbl( L, "AES_192_CCM",        MBEDTLS_CIPHER_AES_192_CCM );
    lauxh_pushint2tbl( L, "AES_256_CCM",        MBEDTLS_CIPHER_AES_256_CCM );
    lauxh_pushint2tbl( L, "CAMELLIA_128_CCM",   MBEDTLS_CIPHER_CAMELLIA_128_CCM );
    lauxh_pushint2tbl( L, "CAMELLIA_192_CCM",   MBEDTLS_CIPHER_CAMELLIA_192_CCM );
    lauxh_pushint2tbl( L, "CAMELLIA_256_CCM",   MBEDTLS_CIPHER_CAMELLIA_256_CCM );

    // add mbedtls_cipher_mode_t
    lauxh_pushint2tbl( L, "MODE_NONE",          MBEDTLS_MODE_NONE );
    lauxh_pushint2tbl( L, "MODE_ECB",           MBEDTLS_MODE_ECB );
    lauxh_pushint2tbl( L, "MODE_CBC",           MBEDTLS_MODE_CBC );
    lauxh_pushint2tbl( L, "MODE_CFB",           MBEDTLS_MODE_CFB );
    lauxh_pushint2tbl( L, "MODE_CTR",           MBEDTLS_MODE_CTR );
    lauxh_pushint2tbl( L, "MODE_GCM",           MBEDTLS_MODE_GCM );
    lauxh_pushint2tbl( L, "MODE_STREAM",        MBEDTLS_MODE_STREAM );
    lauxh_pushint2tbl( L, "MODE_CCM",           MBEDTLS_MODE_CCM );

    // add mbedtls_cipher_padding_t
    lauxh_pushint2tbl( L, "PADDING_PKCS7",          MBEDTLS_PADDING_PKCS7 );
    lauxh_pushint2tbl( L, "PADDING_ONE_AND_ZEROS",  MBEDTLS_PADDING_ONE_AND_ZEROS );
    lauxh_pushint2tbl( L, "PADDING_ZEROS_AND_LEN",  MBEDTLS_PADDING_ZEROS_AND_LEN );
    lauxh_pushint2tbl( L, "PADDING_ZEROS",          MBEDTLS_PADDING_ZEROS );
    lauxh_pushint2tbl( L, "PADDING_NONE",           MBEDTLS_PADDING_NONE );

    // add mbedtls_operation_t
    lauxh_pushint2tbl( L, "OP_NONE",            MBEDTLS_OPERATION_NONE );
    lauxh_pushint2tbl( L, "OP_DECRYPT",         MBEDTLS_DECRYPT );
    lauxh_pushint2tbl( L, "OP_ENCRYPT",         MBEDTLS_ENCRYPT );

    return 1;
}

