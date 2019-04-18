cmake_minimum_required(VERSION 2.8)

set(BUILD_BLUETOOTH      OFF)
set(BUILD_MBEDTLS        OFF)
set(BUILD_SDL            OFF)
set(BUILD_SQLITE         OFF)
set(BUILD_RTMP           OFF)
set(BUILD_CAMERA         OFF)
set(BUILD_MESSAGE        OFF)
set(BUILD_MOSQUITTO      OFF)
set(BUILD_TS             OFF)
set(BUILD_UBOX           OFF)
set(BUILD_UBUS           OFF)
set(BUILD_UCI            OFF)

# Lua module build type (Shared|Static)
if (WIN32)
  set(BUILD_MBEDTLS      OFF)

elseif (APPLE)
  set(CMAKE_MACOSX_RPATH 0)

  if (BUILD_SQLITE)
  	add_definitions(-DLUA_USE_LSQLITE)
  endif ()

elseif (LINUX)
  set(BUILD_SDL 		      OFF)
  set(BUILD_BLUETOOTH     OFF)
  set(BUILD_MBEDTLS       OFF)
  set(BUILD_SQLITE        ON)
  set(BUILD_RTMP          OFF)

endif ()