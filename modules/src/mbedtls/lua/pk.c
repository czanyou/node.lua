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
 *  src/pk.c
 *  lua-mbedtls
 *  Created by Masatoshi Teruya on 16/07/09.
 */


#include "lmbedtls.h"

/*
 * buffer size calculation
 * please refer:
 *   https://github.com/ARMmbed/mbedtls/blob/mbedtls-2.3.0/library/pkwrite.c#L295
 */
#if defined(MBEDTLS_RSA_C)
#define LMBEDTLS_RSA_PUB_DER_MAX_BYTES  (38 + 2 * MBEDTLS_MPI_MAX_SIZE)
#define LMBEDTLS_MPI_MAX_SIZE_2         (MBEDTLS_MPI_MAX_SIZE / 2 + \
                                         MBEDTLS_MPI_MAX_SIZE % 2)
#define LMBEDTLS_RSA_PRV_DER_MAX_BYTES  (47 + 3 * MBEDTLS_MPI_MAX_SIZE + \
                                         5 * LMBEDTLS_MPI_MAX_SIZE_2)

#else
#define LMBEDTLS_RSA_PUB_DER_MAX_BYTES  0
#define LMBEDTLS_RSA_PRV_DER_MAX_BYTES  0

#endif


#if defined(MBEDTLS_ECP_C)
#define LMBEDTLS_ECP_PUB_DER_MAX_BYTES  (30 + 2 * MBEDTLS_ECP_MAX_BYTES)
#define LMBEDTLS_ECP_PRV_DER_MAX_BYTES  (29 + 3 * MBEDTLS_ECP_MAX_BYTES)

#else
#define LMBEDTLS_ECP_PUB_DER_MAX_BYTES  0
#define LMBEDTLS_ECP_PRV_DER_MAX_BYTES  0

#endif


#define LMBEDTLS_PUB_DER_MAX_BYTES \
    ((LMBEDTLS_RSA_PUB_DER_MAX_BYTES > LMBEDTLS_ECP_PUB_DER_MAX_BYTES) ? \
      LMBEDTLS_RSA_PUB_DER_MAX_BYTES : LMBEDTLS_ECP_PUB_DER_MAX_BYTES)

#define LMBEDTLS_PRV_DER_MAX_BYTES \
    ((LMBEDTLS_RSA_PRV_DER_MAX_BYTES > LMBEDTLS_ECP_PRV_DER_MAX_BYTES) ? \
      LMBEDTLS_RSA_PRV_DER_MAX_BYTES : LMBEDTLS_ECP_PRV_DER_MAX_BYTES)

#define LMBEDTLS_PUB_PEM_MAX_BYTES  (LMBEDTLS_PUB_DER_MAX_BYTES * 4 / 3 + 100)
#define LMBEDTLS_PRV_PEM_MAX_BYTES  (LMBEDTLS_PRV_DER_MAX_BYTES * 4 / 3 + 100)



typedef int (*writefn)( mbedtls_pk_context *, uint8_t *, size_t );


static inline int pk_write_pem( lua_State *L, uint8_t *buf, size_t blen,
                                writefn fn )
{
#if defined(MBEDTLS_PK_WRITE_C) && defined(MBEDTLS_PEM_WRITE_C)
    mbedtls_pk_context *pk = lauxh_checkudata( L, 1, LMBEDTLS_PK_MT );
    int rc = fn( pk, buf, blen );

    if ( rc ) {
        lmbedtls_errbuf_t errbuf;

        lmbedtls_strerror( rc, errbuf );
        lua_pushnil( L );
        lua_pushstring( L, errbuf );
        return 2;
    }

    lua_pushstring( L, (const char*)buf );

    return 1;

#else
    lmbedtls_errbuf_t errbuf;

    lmbedtls_strerror( MBEDTLS_ERR_PK_FEATURE_UNAVAILABLE, errbuf );
    lua_pushboolean( L, 0 );
    lua_pushstring( L, errbuf );

    return 2;

#endif
}

static int pk_write_key_pem( lua_State *L )
{
    uint8_t buf[LMBEDTLS_PRV_PEM_MAX_BYTES] = { 0 };

    return pk_write_pem( L, buf, LMBEDTLS_PRV_PEM_MAX_BYTES,
                         mbedtls_pk_write_key_pem );
}

static int pk_write_public_key_pem( lua_State *L )
{
    uint8_t buf[LMBEDTLS_PUB_PEM_MAX_BYTES] = { 0 };

    return pk_write_pem( L, buf, LMBEDTLS_PUB_PEM_MAX_BYTES,
                         mbedtls_pk_write_pubkey_pem );
}


static inline int pk_write_der( lua_State *L, uint8_t *buf, size_t blen,
                                writefn fn )
{
#if defined(MBEDTLS_PK_WRITE_C)
    mbedtls_pk_context *pk = lauxh_checkudata( L, 1, LMBEDTLS_PK_MT );
    int len = fn( pk, buf, blen );

    if( len < 0 ){
        lmbedtls_errbuf_t errbuf;

        lmbedtls_strerror( len, errbuf );
        lua_pushnil( L );
        lua_pushstring( L, errbuf );
        return 2;
    }

    lua_pushlstring( L, (const char*)buf + ( blen - len ), len );

    return 1;

#else
    lmbedtls_errbuf_t errbuf;

    lmbedtls_strerror( MBEDTLS_ERR_PK_FEATURE_UNAVAILABLE, errbuf );
    lua_pushnil( L );
    lua_pushstring( L, errbuf );

    return 2;

#endif
}


static int pk_write_public_key_der( lua_State *L )
{
    uint8_t buf[LMBEDTLS_PUB_DER_MAX_BYTES] = { 0 };

    return pk_write_der( L, buf, LMBEDTLS_PUB_DER_MAX_BYTES,
                         mbedtls_pk_write_pubkey_der );
}


static int pk_write_key_der( lua_State *L )
{
    uint8_t buf[LMBEDTLS_PRV_DER_MAX_BYTES] = { 0 };

    return pk_write_der( L, buf, LMBEDTLS_PRV_DER_MAX_BYTES,
                         mbedtls_pk_write_key_der );
}


typedef int (*cryptfn)( mbedtls_pk_context *, const uint8_t *, size_t,
                        uint8_t *, size_t *, size_t,
                        int (*f_rng)(void *, uint8_t *, size_t), void * );

static inline int pk_crypt( lua_State *L, cryptfn fn )
{
    mbedtls_pk_context *pk = lauxh_checkudata( L, 1, LMBEDTLS_PK_MT );
    size_t ilen = 0;
    const char *input = lauxh_checklstring( L, 2, &ilen );
    lmbedtls_rng_t *rng = lauxh_checkudata( L, 3, LMBEDTLS_RNG_MT );
    size_t olen = 0;
    uint8_t output[MBEDTLS_MPI_MAX_SIZE] = { 0 };
    int rc = fn( pk, (const uint8_t*)input, ilen, output, &olen,
                 sizeof( output ), mbedtls_ctr_drbg_random, &rng->drbg );

    if (rc) {
        lmbedtls_errbuf_t errbuf;

        lmbedtls_strerror( rc, errbuf );
        lua_pushnil( L );
        lua_pushstring( L, errbuf );
        return 2;
    }

    lua_pushlstring( L, (const char*)output, olen );

    return 1;
}

static int pk_encrypt( lua_State *L )
{
    return pk_crypt( L, mbedtls_pk_encrypt );
}

static int pk_decrypt( lua_State *L )
{
    return pk_crypt( L, mbedtls_pk_decrypt );
}


static int pk_sign( lua_State *L )
{
    mbedtls_pk_context *pk = lauxh_checkudata( L, 1, LMBEDTLS_PK_MT );
    mbedtls_md_type_t alg = lauxh_checkinteger( L, 2 );
    size_t hlen = 0;
    const char *hash = lauxh_checklstring( L, 3, &hlen );
    lmbedtls_rng_t *rng = lauxh_checkudata( L, 4, LMBEDTLS_RNG_MT );
    size_t slen = 0;
    uint8_t sig[MBEDTLS_MPI_MAX_SIZE] = { 0 };
    int rc = mbedtls_pk_sign( pk, alg, (const uint8_t*)hash, hlen, sig,
                              &slen, mbedtls_ctr_drbg_random, &rng->drbg );

    if (rc) {
        lmbedtls_errbuf_t errbuf;

        lmbedtls_strerror( rc, errbuf );
        lua_pushnil( L );
        lua_pushstring( L, errbuf );
        return 2;
    }

    lua_pushlstring( L, (const char*)sig, slen );

    return 1;
}


static int pk_verify( lua_State *L )
{
    mbedtls_pk_context *pk = lauxh_checkudata( L, 1, LMBEDTLS_PK_MT );
    mbedtls_md_type_t alg = lauxh_checkinteger( L, 2 );

    size_t hlen = 0;
    const char *hash = lauxh_checklstring( L, 3, &hlen );
    size_t slen = 0;
    const char *sig = lauxh_checklstring( L, 4, &slen );

    int rc = mbedtls_pk_verify( pk, alg, (const uint8_t*)hash, hlen,
                                (const uint8_t*)sig, slen );

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


static int pk_gen_key( lua_State *L )
{
    mbedtls_pk_context *pk = lauxh_checkudata( L, 1, LMBEDTLS_PK_MT );
    lmbedtls_rng_t *rng = lauxh_checkudata( L, 2, LMBEDTLS_RNG_MT );
    mbedtls_pk_type_t type = mbedtls_pk_get_type( pk );
    int rc = 0;

#if defined(MBEDTLS_RSA_C) && defined(MBEDTLS_GENPRIME)
    if( type == MBEDTLS_PK_RSA )
    {
        unsigned int nbits = lauxh_optinteger( L, 3, 4096 );
        int exponent = lauxh_optinteger( L, 4, 65537 );

        rc = mbedtls_rsa_gen_key( mbedtls_pk_rsa( *pk ), mbedtls_ctr_drbg_random,
                                  &rng->drbg, nbits, exponent );
    }
    else
#endif
#if defined(MBEDTLS_ECP_C)
    if( type == MBEDTLS_PK_ECKEY || type == MBEDTLS_PK_ECDSA ||
        type == MBEDTLS_PK_ECKEY_DH )
    {
        mbedtls_ecp_group_id gid = lauxh_checkinteger( L, 3 );

        rc = mbedtls_ecp_gen_key( gid, mbedtls_pk_ec( *pk ),
                                  mbedtls_ctr_drbg_random, &rng->drbg );
    }
    else
#endif
    {
        rc = MBEDTLS_ERR_PK_TYPE_MISMATCH;
    }

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


static int pk_can_do( lua_State *L )
{
    mbedtls_pk_context *pk = lauxh_checkudata( L, 1, LMBEDTLS_PK_MT );
    mbedtls_pk_type_t type = lauxh_checkinteger( L, 2 );

    lua_pushboolean( L, mbedtls_pk_can_do( pk, type ) != 0 );

    return 1;
}


static int pk_get_type( lua_State *L )
{
    const mbedtls_pk_context *pk = lauxh_checkudata( L, 1, LMBEDTLS_PK_MT );
    mbedtls_pk_type_t type = mbedtls_pk_get_type( pk );

    lua_pushinteger( L, type );

    return 1;
}


static int pk_get_name( lua_State *L )
{
    const mbedtls_pk_context *pk = lauxh_checkudata( L, 1, LMBEDTLS_PK_MT );
    const char *name = mbedtls_pk_get_name( pk );

    lua_pushstring( L, name );

    return 1;
}


static int pk_get_len( lua_State *L )
{
    mbedtls_pk_context *pk = lauxh_checkudata( L, 1, LMBEDTLS_PK_MT );

    lua_pushinteger( L, mbedtls_pk_get_len( pk ) );

    return 1;
}


static int pk_get_bit_len( lua_State *L )
{
    mbedtls_pk_context *pk = lauxh_checkudata( L, 1, LMBEDTLS_PK_MT );

    lua_pushinteger( L, mbedtls_pk_get_bitlen( pk ) );

    return 1;
}


static int pk_tostring( lua_State *L )
{
    TOSTRING_MT( L, LMBEDTLS_PK_MT );
    return 1;
}


static int pk_gc( lua_State *L )
{
    mbedtls_pk_context *pk = lua_touserdata( L, 1 );

    mbedtls_pk_free( pk );

    return 0;
}


static int pk_parse_public_key_file( lua_State *L )
{
#if defined(MBEDTLS_PK_PARSE_C) && defined(MBEDTLS_FS_IO)
    const char *path = lauxh_checkstring( L, 1 );
    mbedtls_pk_context *pk = lua_newuserdata( L, sizeof( mbedtls_pk_context ) );
    int rc = 0;

    if (!pk) {
        lua_pushnil( L );
        lua_pushstring( L, strerror( errno ) );
        return 2;
    }

    mbedtls_pk_init( pk );
    rc = mbedtls_pk_parse_public_keyfile( pk, path );
    if (rc) {
        lmbedtls_errbuf_t errbuf;

        // mbedtls_pk_free( pk );
        lmbedtls_strerror( rc, errbuf );
        lua_pushnil( L );
        lua_pushstring( L, errbuf );
        return 2;
    }

    lauxh_setmetatable( L, LMBEDTLS_PK_MT );
    return 1;

#else
    lmbedtls_errbuf_t errbuf;

    lmbedtls_strerror( MBEDTLS_ERR_PK_FEATURE_UNAVAILABLE, errbuf );
    lua_pushnil( L );
    lua_pushstring( L, errbuf );

    return 2;

#endif
}


static int pk_parse_key_file( lua_State *L )
{
#if defined(MBEDTLS_PK_PARSE_C) && defined(MBEDTLS_FS_IO)
    const char *path = lauxh_checkstring( L, 1 );
    const char *pwd = lauxh_optstring( L, 2, NULL );
    mbedtls_pk_context *pk = lua_newuserdata( L, sizeof( mbedtls_pk_context ) );
    int rc = 0;

    if( !pk ){
        lua_pushnil( L );
        lua_pushstring( L, strerror( errno ) );
        return 2;
    }

    mbedtls_pk_init( pk );
    rc = mbedtls_pk_parse_keyfile( pk, path, pwd );
    if( rc ){
        lmbedtls_errbuf_t errbuf;

        //mbedtls_pk_free( pk );
        lmbedtls_strerror( rc, errbuf );
        lua_pushnil( L );
        lua_pushstring( L, errbuf );
        return 2;
    }

    lauxh_setmetatable( L, LMBEDTLS_PK_MT );

    return 1;

#else
    lmbedtls_errbuf_t errbuf;

    lmbedtls_strerror( MBEDTLS_ERR_PK_FEATURE_UNAVAILABLE, errbuf );
    lua_pushnil( L );
    lua_pushstring( L, errbuf );

    return 2;

#endif
}


static int pk_parse_public_key( lua_State *L )
{
#if defined(MBEDTLS_PK_PARSE_C)
    size_t klen = 0;
    const char *key = lauxh_checklstring( L, 1, &klen );

    mbedtls_pk_context *pk = lua_newuserdata( L, sizeof( mbedtls_pk_context ) );
    int rc = 0;

    if (!pk) {
        lua_pushnil( L );
        lua_pushstring( L, strerror( errno ) );
        return 2;
    }

    mbedtls_pk_init(pk);
    rc = mbedtls_pk_parse_public_key( pk, (const uint8_t*)key, klen );
    if (rc) {
        lmbedtls_errbuf_t errbuf;

        ///mbedtls_pk_free( pk );
        lmbedtls_strerror( rc, errbuf );
        lua_pushnil( L );
        lua_pushstring( L, errbuf );
        return 2;
    }

    lauxh_setmetatable( L, LMBEDTLS_PK_MT );

    return 1;

#else
    lmbedtls_errbuf_t errbuf;

    lmbedtls_strerror( MBEDTLS_ERR_PK_FEATURE_UNAVAILABLE, errbuf );
    lua_pushnil( L, 0 );
    lua_pushstring( L, errbuf );

    return 2;

#endif
}


static int pk_parse_key( lua_State *L )
{
#if defined(MBEDTLS_PK_PARSE_C)
    size_t klen = 0;
    const char *key = lauxh_checklstring( L, 1, &klen );
    size_t plen = 0;
    const char *pwd = lauxh_optlstring( L, 2, NULL, &plen );

    mbedtls_pk_context *pk = lua_newuserdata(L, sizeof( mbedtls_pk_context ));
    int rc = 0;

    if (!pk) {
        lua_pushnil( L );
        lua_pushstring( L, strerror( errno ) );
        return 2;
    }

    mbedtls_pk_init( pk );
    rc = mbedtls_pk_parse_key(pk, (const uint8_t*)key, klen, (const uint8_t*)pwd, plen);
    if (rc) {
        lmbedtls_errbuf_t errbuf;

        // mbedtls_pk_free( pk );
        lmbedtls_strerror( rc, errbuf );
        lua_pushnil( L );
        lua_pushstring( L, errbuf );
        return 2;
    }

    lauxh_setmetatable( L, LMBEDTLS_PK_MT );

    return 1;

#else
    lmbedtls_errbuf_t errbuf;

    lmbedtls_strerror( MBEDTLS_ERR_PK_FEATURE_UNAVAILABLE, errbuf );
    lua_pushnil( L );
    lua_pushstring( L, errbuf );

    return 2;

#endif
}


static int pk_new( lua_State *L )
{
    const mbedtls_pk_type_t type = lauxh_checkinteger( L, 1 );
    const mbedtls_pk_info_t *info = mbedtls_pk_info_from_type( type );
    mbedtls_pk_context *pk = NULL;
    int rc = 0;

    if( !info ){
        lua_pushnil( L );
        lua_pushstring( L, strerror( EINVAL ) );
        return 2;
    }
    else if( !( pk = lua_newuserdata( L, sizeof( mbedtls_pk_context ) ) ) ){
        lua_pushnil( L );
        lua_pushstring( L, strerror( errno ) );
        return 2;
    }

    mbedtls_pk_init( pk );
    rc = mbedtls_pk_setup( pk, info );
    if( rc ){
        lmbedtls_errbuf_t errbuf;

        mbedtls_pk_free( pk );
        lmbedtls_strerror( rc, errbuf );
        lua_pushnil( L );
        lua_pushstring( L, errbuf );
        return 2;
    }

    lauxh_setmetatable( L, LMBEDTLS_PK_MT );

    return 1;
}


static int pk_check_pair( lua_State *L )
{
    const mbedtls_pk_context *pub = lauxh_checkudata( L, 1, LMBEDTLS_PK_MT );
    const mbedtls_pk_context *prv = lauxh_checkudata( L, 2, LMBEDTLS_PK_MT );
    int rc = mbedtls_pk_check_pair( pub, prv );

    if (rc) {
        lmbedtls_errbuf_t errbuf;

        lmbedtls_strerror( rc, errbuf );
        lua_pushboolean( L, 0 );
        lua_pushstring( L, errbuf );
        return 2;
    }

    lua_pushboolean( L, 1 );

    return 1;
}


LUALIB_API int luaopen_lmbedtls_pk( lua_State *L )
{
    struct luaL_Reg pk_mmethods[] = {
        { "__gc",                   pk_gc },
        { "__tostring",             pk_tostring },
        { NULL, NULL }
    };

    struct luaL_Reg pk_methods[] = {
        { "gen_key",                pk_gen_key },
        { "get_bit_len",            pk_get_bit_len },
        { "get_len",                pk_get_len },
        { "get_name",               pk_get_name },
        { "get_type",               pk_get_type },
        { "can_do",                 pk_can_do },
        { "verify",                 pk_verify },
        { "sign",                   pk_sign },
        { "decrypt",                pk_decrypt },
        { "encrypt",                pk_encrypt },
        { "write_key_der",          pk_write_key_der },
        { "write_public_key_der",   pk_write_public_key_der },
        { "write_public_key_pem",   pk_write_public_key_pem },
        { "write_key_pem",          pk_write_key_pem },
        { NULL, NULL }
    };

    struct luaL_Reg pk_functions[] = {
        { "new",                    pk_new },
        { "parse_key",              pk_parse_key },
        { "parse_public_key",       pk_parse_public_key },
        { "parse_key_file",         pk_parse_key_file },
        { "parse_public_key_file",  pk_parse_public_key_file },
        { "check_pair",             pk_check_pair },
        { NULL, NULL }
    };

    struct luaL_Reg *function = pk_functions;

    // register metatable
    lmbedtls_newmetatable( L, LMBEDTLS_PK_MT, pk_mmethods, pk_methods );

    // create table
    lua_newtable( L );

    // add functions
    while ( function->name ) {
        lauxh_pushfn2tbl( L, function->name, function->func );
        function++;
    }

    // add mbedtls_pk_type_t
    lauxh_pushint2tbl( L, "RSA",        MBEDTLS_PK_RSA );
    lauxh_pushint2tbl( L, "EC",         MBEDTLS_PK_ECKEY );
    lauxh_pushint2tbl( L, "EC_DH",      MBEDTLS_PK_ECKEY_DH );
    lauxh_pushint2tbl( L, "ECDSA",      MBEDTLS_PK_ECDSA );

    // add mbedtls_ecp_group_id
    lauxh_pushint2tbl( L, "SECP192R1",  MBEDTLS_ECP_DP_SECP192R1 );
    lauxh_pushint2tbl( L, "SECP224R1",  MBEDTLS_ECP_DP_SECP224R1 );
    lauxh_pushint2tbl( L, "SECP256R1",  MBEDTLS_ECP_DP_SECP256R1 );
    lauxh_pushint2tbl( L, "SECP384R1",  MBEDTLS_ECP_DP_SECP384R1 );
    lauxh_pushint2tbl( L, "SECP521R1",  MBEDTLS_ECP_DP_SECP521R1 );
    lauxh_pushint2tbl( L, "BP256R1",    MBEDTLS_ECP_DP_BP256R1 );
    lauxh_pushint2tbl( L, "BP384R1",    MBEDTLS_ECP_DP_BP384R1 );
    lauxh_pushint2tbl( L, "BP512R1",    MBEDTLS_ECP_DP_BP512R1 );
    lauxh_pushint2tbl( L, "CURVE25519", MBEDTLS_ECP_DP_CURVE25519 );
    lauxh_pushint2tbl( L, "SECP192K1",  MBEDTLS_ECP_DP_SECP192K1 );
    lauxh_pushint2tbl( L, "SECP224K1",  MBEDTLS_ECP_DP_SECP224K1 );
    lauxh_pushint2tbl( L, "SECP256K1",  MBEDTLS_ECP_DP_SECP256K1 );

    return 1;
}

