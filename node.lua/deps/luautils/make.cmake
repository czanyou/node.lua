cmake_minimum_required(VERSION 2.8)

include(CheckTypeSize)

set(LUAUTILSDIR ${CMAKE_CURRENT_LIST_DIR})

include_directories(
  ${LUAUTILSDIR}/src
)

set(SOURCES
  ${LUAUTILSDIR}/src/base64.c
  ${LUAUTILSDIR}/src/hex.c
  ${LUAUTILSDIR}/src/http_parser.c
  ${LUAUTILSDIR}/src/http_parser_lua.c
  ${LUAUTILSDIR}/src/lenv.c
  ${LUAUTILSDIR}/src/md5.c
  ${LUAUTILSDIR}/src/lutils.c
  ${LUAUTILSDIR}/src/message_lua.c

)

check_type_size("void*" SIZEOF_VOID_P)
if (SIZEOF_VOID_P EQUAL 8)
  add_definitions(-D_OS_BITS=64)
endif()

add_library(luautils STATIC ${SOURCES})
