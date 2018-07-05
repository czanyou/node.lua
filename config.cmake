cmake_minimum_required(VERSION 2.8)

set(BUILD_BLUE_TOOTH      OFF)
set(BUILD_MBED_TLS        OFF)
set(BUILD_SDL             OFF)
set(BUILD_SQLITE          OFF)

# Lua module build type (Shared|Static)
if (WIN32)

elseif (APPLE)
  set(CMAKE_MACOSX_RPATH 0)

  if (BUILD_SQLITE)
  	add_definitions(-DLUA_USE_LSQLITE)
  endif ()

elseif (LINUX)
  set(BUILD_SDL 		  ON)
  set(BUILD_BLUE_TOOTH    ON)

endif ()

if (BOARD_TYPE STREQUAL hi3518)
  set(CMAKE_C_COMPILER "arm-hisiv100nptl-linux-gcc")

elseif (BOARD_TYPE STREQUAL hi3516a)
  set(CMAKE_C_COMPILER "arm-hisiv300-linux-gcc")

elseif (BOARD_TYPE STREQUAL mt7688)
  set(CMAKE_C_COMPILER "mipsel-openwrt-linux-gcc")

elseif (BOARD_TYPE STREQUAL xcode)
  set(BUILD_SHARED_LUA_LIB OFF)
  set(BUILD_LNODE_EXE      OFF)

endif ()

