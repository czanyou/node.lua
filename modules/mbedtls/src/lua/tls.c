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
 *  src/tls.c
 *  lua-mbedtls
 *  Created by Masatoshi Teruya on 16/05/22.
 */


#include "lmbedtls.h"

typedef struct lmbedtls_tls_s {
	mbedtls_entropy_context  entropy;
	mbedtls_ctr_drbg_context drbg;
	mbedtls_ssl_context      ssl_context;
	mbedtls_ssl_config       ssl_conf;
	mbedtls_x509_crt         cacert;
	mbedtls_net_context      net_context;

	int  fCallback;
	int  fReference;

	lua_State*  fState;

} lmbedtls_tls_t;


static void tls_callback_release(lmbedtls_tls_t* ltls)
{
	if (ltls == NULL) {
		return;
	}

	lua_State* L = ltls->fState;

	if (ltls->fCallback != LUA_NOREF) {
		luaL_unref(L, LUA_REGISTRYINDEX, ltls->fCallback);
		ltls->fCallback = LUA_NOREF;
	}
}

static void tls_callback_check(lmbedtls_tls_t* ltls, int index) 
{
	if (ltls == NULL) {
		return;
	}

	lua_State* L = ltls->fState;
	tls_callback_release(ltls);

	luaL_checktype(L, index, LUA_TFUNCTION);
	ltls->fCallback = luaL_ref(L, LUA_REGISTRYINDEX);
}

static void tls_callback_call(lmbedtls_tls_t* ltls, int nargs, int rets) 
{
	if (ltls == NULL) {
		return;
	}

	lua_State* L = ltls->fState;

	int ref = ltls->fCallback;
	if (ref == LUA_NOREF) {
		lua_pop(L, nargs);
		return;
	}

	// Get the callback
	lua_rawgeti(L, LUA_REGISTRYINDEX, ref);

	// And insert it before the args if there are any.
	if (nargs) {
		lua_insert(L, -1 - nargs);
	}

	if (lua_pcall(L, nargs, rets, -2 - nargs)) {
		printf("Uncaught error in ltls callback: %s\n", lua_tostring(L, -1));
		return;
	}
}


static void tls_debug( void *ctx, int level, const char *file, int line, const char *str )
{
	((void) level);

	fprintf( (FILE *) ctx, "%s:%04d: %s", file, line, str );
	fflush(  (FILE *) ctx  );
}


static int tls_free(lmbedtls_tls_t *tls)
{
	mbedtls_x509_crt_free( &tls->cacert );
	mbedtls_ssl_free( &tls->ssl_context );
	mbedtls_ssl_config_free( &tls->ssl_conf );
	mbedtls_ctr_drbg_free( &tls->drbg );
	mbedtls_entropy_free( &tls->entropy );

	return 0;
}

int tls_net_send( void *ctx, const unsigned char *buf, size_t len )
{
	//printf("send: %d 0x%08x\n", (int)len, (uint32_t)(void*)buf);
	lmbedtls_tls_t *tls = (lmbedtls_tls_t*)ctx;
	lua_State *L = tls->fState;

	lua_pushlstring(L, buf, len);
	tls_callback_call(tls, 1, 0);

	return 0;
}

int tls_net_recv( void *ctx, unsigned char *buf, size_t len, uint32_t timeout )
{
	//printf("recv: %d 0x%08x\n", (int)len, (uint32_t)(void*)buf);
	lmbedtls_tls_t *tls = (lmbedtls_tls_t*)ctx;
	lua_State *L = tls->fState;

	lua_pushnil(L);
	lua_pushnumber(L, len);
	tls_callback_call(tls, 2, 1);

	int top = lua_gettop(L);
	int type1 = lua_type(L, -1);
	int type2 = lua_type(L, -2);

	size_t retlen = 0;
	const char *ret = lauxh_optlstring( L, -1, "", &retlen);

	if (retlen <= 0) {
		return MBEDTLS_ERR_SSL_WANT_READ;
	}

	memcpy(buf, ret, retlen);
 
	return retlen;
}

static int tls_tostring( lua_State *L )
{
	TOSTRING_MT( L, LMBEDTLS_TLS_MT );
	return 1;
}

static int tls_gc( lua_State *L )
{
	lmbedtls_tls_t *tls = lua_touserdata( L, 1 );

	tls_free(tls);

	return 0;
}

static int tls_init(lmbedtls_tls_t *tls)
{
	const char* seed = "tls";
	const uint8_t* pers = (const uint8_t*)seed;
	size_t pers_len = strlen(seed);

	mbedtls_ssl_init        (&tls->ssl_context);
	mbedtls_ssl_config_init (&tls->ssl_conf);
	mbedtls_x509_crt_init   (&tls->cacert);
	mbedtls_ctr_drbg_init   (&tls->drbg);
	mbedtls_entropy_init    (&tls->entropy);

	mbedtls_net_init( &tls->net_context );

	mbedtls_ctr_drbg_seed(&tls->drbg, mbedtls_entropy_func, &tls->entropy, pers, pers_len);

	return 0;
}

static int tls_set_certificates(lua_State *L)
{
	lmbedtls_tls_t *tls = lauxh_checkudata( L, 1, LMBEDTLS_TLS_MT );
	const char *cas_pem = lauxh_optstring( L, 2, "");
	size_t cas_pem_len  = strlen(cas_pem);

	return mbedtls_x509_crt_parse( &tls->cacert, (const uint8_t *) cas_pem, cas_pem_len );
}

static int tls_config(lua_State *L)
{
	lmbedtls_tls_t *tls = lauxh_checkudata( L, 1, LMBEDTLS_TLS_MT );
	const char* serverName = lauxh_optstring( L, 2, "");

	tls_callback_check(tls, 3);

	int ret = mbedtls_ssl_config_defaults( &tls->ssl_conf, MBEDTLS_SSL_IS_CLIENT,
					MBEDTLS_SSL_TRANSPORT_STREAM, MBEDTLS_SSL_PRESET_DEFAULT);

	if (ret == 0) {
		/* OPTIONAL is not optimal for security,
		 * but makes interop easier in this simplified example */
		mbedtls_ssl_conf_authmode( &tls->ssl_conf, MBEDTLS_SSL_VERIFY_OPTIONAL );
		mbedtls_ssl_conf_ca_chain( &tls->ssl_conf, &tls->cacert, NULL );
		mbedtls_ssl_conf_rng( &tls->ssl_conf, mbedtls_ctr_drbg_random, &tls->drbg );
		mbedtls_ssl_conf_dbg( &tls->ssl_conf, tls_debug, stdout );

		ret = mbedtls_ssl_setup(&tls->ssl_context, &tls->ssl_conf);
	}

	if (ret == 0) {
		ret = mbedtls_ssl_set_hostname(&tls->ssl_context, serverName);
	}

	mbedtls_ssl_set_bio(&tls->ssl_context, tls, tls_net_send, tls_net_recv, NULL);

	//mbedtls_ssl_set_bio( &tls->ssl_context, &tls->net_context, mbedtls_net_send, mbedtls_net_recv, NULL );

	lua_pushnumber( L, ret );

	return 1;
}

static int tls_handshake(lua_State *L)
{
	lmbedtls_tls_t *tls = lauxh_checkudata( L, 1, LMBEDTLS_TLS_MT );
	if (tls->ssl_context.state == MBEDTLS_SSL_HANDSHAKE_OVER) {
		lua_pushnumber( L, 0 );
		return 1;
	}

	int ret = -1;
	ret = mbedtls_ssl_handshake(&tls->ssl_context);
  
	lua_pushnumber( L, ret );
	return 1;
}

static int tls_verify(lua_State *L)
{
	lmbedtls_tls_t *tls = lauxh_checkudata( L, 1, LMBEDTLS_TLS_MT );

	int ret = mbedtls_ssl_get_verify_result( &tls->ssl_context );
	if (ret != 0) {
		char vrfy_buf[512];
		mbedtls_x509_crt_verify_info(vrfy_buf, sizeof(vrfy_buf), "", ret);

		lua_pushboolean( L, 0 );
		lua_pushstring( L, vrfy_buf );

		return 2;
	}

	lua_pushboolean( L, 1 );
	return 1;
}


static int tls_write( lua_State *L )
{
	lmbedtls_tls_t *tls = lauxh_checkudata( L, 1, LMBEDTLS_TLS_MT );

	size_t len = 0;
	const char* buf = lauxh_optlstring( L, 2, "", &len);

	int ret = 0;
	while ( ( ret = mbedtls_ssl_write( &tls->ssl_context, buf, len ) ) <= 0 )
	{
		if( ret != MBEDTLS_ERR_SSL_WANT_READ && ret != MBEDTLS_ERR_SSL_WANT_WRITE )
		{
			printf( " failed\n  ! mbedtls_ssl_write returned %d\n\n", ret );
			break;
		}
	}

	lua_pushnumber( L, ret );
	return 1;
}

static int tls_read( lua_State *L )
{
	lmbedtls_tls_t *tls = lauxh_checkudata( L, 1, LMBEDTLS_TLS_MT );

	char buf[1024 + 1];
	size_t len = sizeof( buf ) - 1;
	memset( buf, 0, sizeof( buf ) );

	int ret = mbedtls_ssl_read( &tls->ssl_context, buf, len );

	lua_pushlstring( L, buf, len );
	return 1;
}

static int tls_connect( lua_State *L )
{
	lmbedtls_tls_t *tls = lauxh_checkudata( L, 1, LMBEDTLS_TLS_MT );
	const char* serverName = lauxh_optstring( L, 2, "");
	const char* serverPort = lauxh_optstring( L, 3, "");

	/*
	 * 1. Start the connection
	 */
	printf( "  . Connecting to tcp/%s/%s...", serverName, serverPort );
	fflush( stdout );
	int ret = mbedtls_net_connect( &tls->net_context, serverName, serverPort, MBEDTLS_NET_PROTO_TCP );
	if (ret != 0 ) {
		printf( " failed\n  ! mbedtls_net_connect returned %d\n\n", ret );
	}

	lua_pushnumber( L, ret );
	return 1;
}

static int tls_close( lua_State *L )
{
	lmbedtls_tls_t *tls = lauxh_checkudata( L, 1, LMBEDTLS_TLS_MT );
   
	mbedtls_ssl_close_notify(&tls->ssl_context);
	return 0;
}


static int tls_new( lua_State *L )
{
	size_t len = 0;
	lmbedtls_tls_t *tls = lua_newuserdata( L, sizeof( lmbedtls_tls_t ) );
	int rc = 0;
	lmbedtls_errbuf_t errstr;

	memset(tls, 0, sizeof(*tls));
	tls->fCallback = LUA_NOREF;
	tls->fState = L;

	if ( !tls ) {
		lua_pushnil( L );
		lua_pushstring( L, strerror( errno ) );
		return 2;
	}

	rc = tls_init(tls);

	if ( rc == 0 ) {
		lauxh_setmetatable( L, LMBEDTLS_TLS_MT );
		return 1;
	}

	// got error
	tls_free(tls);

	lmbedtls_strerror( rc, errstr );
	lua_pushnil( L );
	lua_pushstring( L, errstr );

	return 2;
}

LUALIB_API int luaopen_lmbedtls_tls( lua_State *L )
{
	struct luaL_Reg tls_mmethods[] = {
		{ "__gc",       tls_gc },
		{ "__tostring", tls_tostring },
		{ NULL, NULL }
	};

	struct luaL_Reg tls_methods[] = {
		{ "close",              tls_close       },
		{ "config",             tls_config      },
		{ "handshake",          tls_handshake   },
		{ "read",               tls_read        },
		{ "set_certificates",   tls_set_certificates   },
		{ "verify",             tls_verify      },
		{ "write",              tls_write       },
		{ "connect",            tls_connect     },

		{ NULL, NULL }
	};

	// register metatable
	lmbedtls_newmetatable( L, LMBEDTLS_TLS_MT, tls_mmethods, tls_methods );

	// create table
	lua_newtable( L );

	// add new function
	lauxh_pushfn2tbl( L, "new", tls_new );

	return 1;
}

