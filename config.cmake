cmake_minimum_required(VERSION 2.8)

set(BUILD_BLUE_TOOTH      ON)
set(BUILD_MBED_TLS        ON)
set(BUILD_SDL             ON)
set(BUILD_SQLITE          ON)

if (BOARD_TYPE STREQUAL hi3518)
  set(CMAKE_C_COMPILER "arm-hisiv100nptl-linux-gcc")

elseif (BOARD_TYPE STREQUAL hi3516a)
  set(CMAKE_C_COMPILER "arm-hisiv300-linux-gcc")

elseif (BOARD_TYPE STREQUAL mt7688)
  set(CMAKE_C_COMPILER "mipsel-openwrt-linux-gcc")

elseif (BOARD_TYPE STREQUAL xcode)
  set(BUILD_SHARED_LUA_LIB OFF)
  set(BUILD_LNODE_EXE OFF)

endif ()

