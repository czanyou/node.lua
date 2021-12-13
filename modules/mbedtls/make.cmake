cmake_minimum_required(VERSION 2.8)

set(MBEDTLS_DIR ${CMAKE_CURRENT_LIST_DIR}/src)

include_directories(
  ${MBEDTLS_DIR}/include
)

set(SOURCES
	# libcrypto
	${MBEDTLS_DIR}/library/aes.c
	${MBEDTLS_DIR}/library/aesni.c
	${MBEDTLS_DIR}/library/arc4.c
	${MBEDTLS_DIR}/library/asn1parse.c
	${MBEDTLS_DIR}/library/asn1write.c
	${MBEDTLS_DIR}/library/base64.c
	${MBEDTLS_DIR}/library/bignum.c
	${MBEDTLS_DIR}/library/blowfish.c
	${MBEDTLS_DIR}/library/camellia.c
	${MBEDTLS_DIR}/library/ccm.c
	${MBEDTLS_DIR}/library/cipher_wrap.c
	${MBEDTLS_DIR}/library/cipher.c
	${MBEDTLS_DIR}/library/ctr_drbg.c
	${MBEDTLS_DIR}/library/des.c
	${MBEDTLS_DIR}/library/dhm.c
	${MBEDTLS_DIR}/library/ecdh.c
	${MBEDTLS_DIR}/library/ecdsa.c
	${MBEDTLS_DIR}/library/ecjpake.c
	${MBEDTLS_DIR}/library/ecp_curves.c
	${MBEDTLS_DIR}/library/ecp.c
	${MBEDTLS_DIR}/library/entropy_poll.c
	${MBEDTLS_DIR}/library/entropy.c
	${MBEDTLS_DIR}/library/error.c
	${MBEDTLS_DIR}/library/gcm.c
	${MBEDTLS_DIR}/library/havege.c
	${MBEDTLS_DIR}/library/hmac_drbg.c
	${MBEDTLS_DIR}/library/md_wrap.c
	${MBEDTLS_DIR}/library/md.c
	${MBEDTLS_DIR}/library/md2.c
	${MBEDTLS_DIR}/library/md4.c
	${MBEDTLS_DIR}/library/md5.c
	${MBEDTLS_DIR}/library/memory_buffer_alloc.c
	${MBEDTLS_DIR}/library/oid.c
	${MBEDTLS_DIR}/library/padlock.c
	${MBEDTLS_DIR}/library/pem.c
	${MBEDTLS_DIR}/library/pk_wrap.c
	${MBEDTLS_DIR}/library/pk.c
	${MBEDTLS_DIR}/library/pkcs12.c
	${MBEDTLS_DIR}/library/pkcs5.c
	${MBEDTLS_DIR}/library/pkparse.c
	${MBEDTLS_DIR}/library/pkwrite.c
	${MBEDTLS_DIR}/library/platform.c
	${MBEDTLS_DIR}/library/ripemd160.c
	${MBEDTLS_DIR}/library/rsa.c
	${MBEDTLS_DIR}/library/sha1.c
	${MBEDTLS_DIR}/library/sha256.c
	${MBEDTLS_DIR}/library/sha512.c
	${MBEDTLS_DIR}/library/threading.c
	${MBEDTLS_DIR}/library/timing.c
	${MBEDTLS_DIR}/library/version_features.c
	${MBEDTLS_DIR}/library/version.c
	${MBEDTLS_DIR}/library/xtea.c

	# libx509
    ${MBEDTLS_DIR}/library/certs.c
    ${MBEDTLS_DIR}/library/pkcs11.c
    ${MBEDTLS_DIR}/library/x509_create.c
    ${MBEDTLS_DIR}/library/x509_crl.c
    ${MBEDTLS_DIR}/library/x509_crt.c
    ${MBEDTLS_DIR}/library/x509_csr.c
    ${MBEDTLS_DIR}/library/x509.c
    ${MBEDTLS_DIR}/library/x509write_crt.c
    ${MBEDTLS_DIR}/library/x509write_csr.c

	# libtls
    ${MBEDTLS_DIR}/library/debug.c
    ${MBEDTLS_DIR}/library/net.c
    ${MBEDTLS_DIR}/library/ssl_cache.c
    ${MBEDTLS_DIR}/library/ssl_ciphersuites.c
    ${MBEDTLS_DIR}/library/ssl_cli.c
    ${MBEDTLS_DIR}/library/ssl_cookie.c
    ${MBEDTLS_DIR}/library/ssl_srv.c
    ${MBEDTLS_DIR}/library/ssl_ticket.c
    ${MBEDTLS_DIR}/library/ssl_tls.c
	
	# mbedtls.lua
    ${MBEDTLS_DIR}/lua/cipher.c
    ${MBEDTLS_DIR}/lua/md.c
    ${MBEDTLS_DIR}/lua/pk.c
    ${MBEDTLS_DIR}/lua/rng.c
    ${MBEDTLS_DIR}/lua/tls.c
    ${MBEDTLS_DIR}/lua/x509_crl.c
    ${MBEDTLS_DIR}/lua/x509_csr.c 
)

if (WIN32)
  add_library(lmbedtls SHARED ${SOURCES})
  set_target_properties(lmbedtls PROPERTIES PREFIX "")
  target_link_libraries(lmbedtls lualib)
  
elseif (APPLE)
  add_library(lmbedtls STATIC ${SOURCES})

else ()
  add_library(lmbedtls STATIC ${SOURCES})
  # set_target_properties(lmbedtls PROPERTIES PREFIX "")

endif ()
