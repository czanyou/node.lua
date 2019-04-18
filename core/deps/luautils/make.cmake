cmake_minimum_required(VERSION 2.8)

set(LUAUTILSDIR ${CMAKE_CURRENT_LIST_DIR})

include_directories(
  ${LUAUTILSDIR}/src
)

set(SOURCES
  ${LUAUTILSDIR}/src/base64.c
  ${LUAUTILSDIR}/src/hex.c
  ${LUAUTILSDIR}/src/lenv.c
  ${LUAUTILSDIR}/src/md5.c
  ${LUAUTILSDIR}/src/lutils.c

)

add_library(luautils STATIC ${SOURCES})
