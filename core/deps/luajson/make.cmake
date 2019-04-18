cmake_minimum_required(VERSION 2.8)

# Source Code Updated: 2016/9/23
# https://github.com/mpx/lua-cjson

set(LUAJSONDIR ${CMAKE_CURRENT_LIST_DIR})

include_directories(
  ${LUAJSONDIR}/src/
)

set(SOURCES
  ${LUAJSONDIR}/src/lua_cjson.c
  ${LUAJSONDIR}/src/fpconv.c
  ${LUAJSONDIR}/src/strbuf.c
)

add_library(luajson STATIC ${SOURCES})

