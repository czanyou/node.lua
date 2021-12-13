cmake_minimum_required(VERSION 2.8)

set(BUILD_BLUETOOTH      OFF)
set(BUILD_CAMERA         OFF)
set(BUILD_DEVICES        OFF)
set(BUILD_LNODE          ON)
set(BUILD_LUV            OFF)
set(BUILD_MBEDTLS        OFF)
set(BUILD_MEDIA_TS       OFF)
set(BUILD_MESSAGE        OFF)
set(BUILD_MODBUS         OFF)
set(BUILD_SQLITE         OFF)

# The install path
# set(NODE_LUA_ROOT "/system/local/lnode")

# Lua module build type (Shared|Static)
if (WIN32)
  set(BUILD_MBEDTLS      ON)
  set(BUILD_MODBUS       ON)

elseif (APPLE)
  set(CMAKE_MACOSX_RPATH 0)

  if (BUILD_SQLITE)
  	add_definitions(-DBUILD_SQLITE)
  endif ()

elseif (LINUX)
  set(BUILD_BLUETOOTH     OFF)
  set(BUILD_DEVICES 		  OFF)
  set(BUILD_MBEDTLS       ON)
  set(BUILD_MODBUS        ON)
  set(BUILD_SQLITE        OFF)

endif ()
