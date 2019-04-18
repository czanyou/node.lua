cmake_minimum_required(VERSION 2.8)

# 
# https://github.com/richgel999/miniz

set(LUAZIPDIR ${CMAKE_CURRENT_LIST_DIR})

include_directories(
  ${LUAZIPDIR}/src
)

set(SOURCES
  ${LUAZIPDIR}/src/lminiz.c
)

add_library(luazip STATIC ${SOURCES})
