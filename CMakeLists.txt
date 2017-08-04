cmake_minimum_required(VERSION 2.8)
  
project(Node.lua)  # Project Name

# Project Version Code
set(LNODE_MAJOR_VERSION 2)
set(LNODE_MINOR_VERSION 1)
set(LNODE_PATCH_VERSION 104) # The PATCH version see `lua/process.lua`

set(LNODE_VERSION ${LNODE_MAJOR_VERSION}.${LNODE_MINOR_VERSION})
add_definitions(-DLNODE_MAJOR_VERSION=${LNODE_MAJOR_VERSION})
add_definitions(-DLNODE_MINOR_VERSION=${LNODE_MINOR_VERSION})

# Linux
if ("${CMAKE_SYSTEM_NAME}" MATCHES "Linux")
  set(LINUX ON)
endif ()

message(STATUS "Build: LNODE_VERSION=${LNODE_VERSION}  ")
message(STATUS "CMAKE_SYSTEM_NAME: ${CMAKE_SYSTEM_NAME}")
message(STATUS "CMAKE_SYSTEM_VERSION: ${CMAKE_SYSTEM_VERSION}")
message(STATUS "CMAKE_SYSTEM_PROCESSOR: ${CMAKE_SYSTEM_PROCESSOR}")
message(STATUS "CMAKE_C_FLAGS: ${CMAKE_C_FLAGS}")
message(STATUS "CMAKE_CXX_FLAGS: ${CMAKE_CXX_FLAGS}")

###############################################################################
# Build Options

# Development board type
if (NOT BOARD_TYPE)
  set(BOARD_TYPE local)
endif ()

# Build lnode execute
option(BUILD_BLUE_TOOTH "Build with bluetooth" OFF)
option(BUILD_KCP        "Build with KCP"       OFF)
option(BUILD_LNODE_EXE  "Build lnode execute"  ON)
option(BUILD_MBED_TLS   "Build mbedtls module" OFF)
option(BUILD_MEDIA      "Build media module"   OFF)
option(BUILD_SDL        "Build sdl module"     OFF)
option(BUILD_SML        "Build sml module"     OFF)
option(BUILD_SQLITE     "Build sqlite3 module" OFF)
option(BUILD_TS         "Build ts module"      ON)

set(BUILD_BLUE_TOOTH      OFF)
set(BUILD_KCP             OFF)
set(BUILD_LNODE_EXE       ON)
set(BUILD_MBED_TLS        OFF)
set(BUILD_MEDIA           OFF)
set(BUILD_SDL             OFF)
set(BUILD_SHARED_LUA_LIB  OFF)
set(BUILD_SML             OFF)
set(BUILD_SQLITE          OFF)
set(BUILD_TS              ON)

# Lua module build type (Shared|Static)
if (WIN32)
  set(BUILD_SHARED_LUA_LIB ON)
  set(BUILD_MBED_TLS  ON)

elseif (APPLE)
  set(CMAKE_MACOSX_RPATH 0)
  set(BUILD_SQLITE ON)

elseif (LINUX)
  set(BUILD_SQLITE ON)

endif ()

###############################################################################
# Cross compiler options
# determine the parameters of the compiler tool chain through BOARD_TYPE

###############################################################################

message(STATUS "Build: BOARD_TYPE:           ${BOARD_TYPE}")
message(STATUS "Build: BUILD_BLUE_TOOTH:     ${BUILD_BLUE_TOOTH} ")
message(STATUS "Build: BUILD_KCP:            ${BUILD_KCP} ")
message(STATUS "Build: BUILD_LNODE_EXE:      ${BUILD_LNODE_EXE} ")
message(STATUS "Build: BUILD_MBED_TLS:       ${BUILD_MBED_TLS} ")
message(STATUS "Build: BUILD_SDL:            ${BUILD_SDL} ")
message(STATUS "Build: BUILD_SHARED_LUA_LIB: ${BUILD_SHARED_LUA_LIB}")
message(STATUS "Build: BUILD_SML:            ${BUILD_SML} ")
message(STATUS "Build: BUILD_SQLITE:         ${BUILD_SQLITE} ")
message(STATUS "Build: BUILD_TS:             ${BUILD_TS} ")
message(STATUS "Build: CC: ${CMAKE_C_COMPILER}")

###############################################################################
# OS build options

if (WIN32)
  add_definitions("/wd4005" "/wd4244" "/wd4819" "/wd4996")

  # see `deps/lua/src/luaconf.h`
  add_definitions(-DLUA_BUILD_AS_DLL -DLUA_LIB)
  add_definitions(-DNODE_LUA_ROOT="C:/Program Files/lnode")

  # replace /MD to /MT to avoid link msvcr*.dll
  set(CompilerFlags
    CMAKE_C_FLAGS
    CMAKE_C_FLAGS_DEBUG
    CMAKE_C_FLAGS_MINSIZEREL
    CMAKE_C_FLAGS_RELWITHDEBINFO
    CMAKE_C_FLAGS_RELEASE)

  foreach(CompilerFlag ${CompilerFlags})
    string(REPLACE "/MD" "/MT" ${CompilerFlag} "${${CompilerFlag}}")
    message(STATUS "Build: ${CompilerFlag} = ${${CompilerFlag}}")
  endforeach()

elseif (APPLE)
  # see `deps/lua/src/luaconf.h`
  add_definitions(-DLUA_USE_POSIX -DLUA_USE_DLOPEN)
  add_definitions(-DNODE_LUA_ROOT="/usr/local/lnode")
  add_definitions(-DLUA_USE_LMEDIA)
  add_definitions(-DLUA_USE_LSQLITE)

  set(CMAKE_SHARED_MODULE_CREATE_C_FLAGS
    "${CMAKE_SHARED_MODULE_CREATE_C_FLAGS} -bundle -flat_namespace -undefined suppress"
  )

  add_definitions(-fPIC)
  add_definitions(-Wdeprecated-declarations)

  set(CMAKE_MACOSX_RPATH 0)

  if (BOARD_TYPE STREQUAL xcode)
    set(BUILD_SHARED_LUA_LIB OFF)
    set(BUILD_LNODE_EXE OFF)
    message(STATUS "Build: xcode")
  endif ()

elseif (LINUX)

  # Add share object flags
  # Under 64bit Linux, you must add -fPIC option to compile a dynamic link library
  add_definitions("-fPIC")

  # Retain function names, etc., to facilitate dlopen or debugging
  add_definitions("-rdynamic")

  # see `deps/lua/src/luaconf.h`
  add_definitions(-DLUA_USE_POSIX -DLUA_USE_DLOPEN)  
  add_definitions(-DNODE_LUA_ROOT="/usr/local/lnode")

  set(BUILD_MEDIA           ON)
  set(BUILD_SML             ON)
  set(BUILD_SDL             ON)

  if (BOARD_TYPE STREQUAL hi3518)
    set(CMAKE_C_COMPILER "arm-hisiv100nptl-linux-gcc")
    include(targets/linux/hi3518/sml.cmake)

    link_directories(${CMAKE_CURRENT_LIST_DIR}/targets/hi3518/lib)

  elseif (BOARD_TYPE STREQUAL hi3516a)
    set(CMAKE_C_COMPILER "arm-hisiv300-linux-gcc")
    include(targets/linux/hi3516a/sml.cmake)

    link_directories(${CMAKE_CURRENT_LIST_DIR}/targets/hi3516a/lib)

  elseif (BOARD_TYPE STREQUAL mt7688)
    set(CMAKE_C_COMPILER "mipsel-openwrt-linux-gcc")

    include(targets/linux/local/sml.cmake)

  else ()
    include(targets/linux/local/sml.cmake)
    set(BUILD_BLUE_TOOTH ON)
  endif ()

endif ()

###############################################################################
# Include deps modules

# Include directories
include_directories(node.lua/deps/lua/src)

include(node.lua/deps/libuv/make.cmake)
include(node.lua/deps/lua/make.cmake)
include(node.lua/deps/luajson/make.cmake)
include(node.lua/deps/luautils/make.cmake)
include(node.lua/deps/luauv/make.cmake)
include(node.lua/deps/luazip/make.cmake)

###############################################################################
# Include ext modules

if (BUILD_MEDIA)
    include(modules/src/media/make.cmake)
endif ()

if (BUILD_KCP)
    include(modules/src/kcp/make.cmake)
endif ()

if (BUILD_TS)
    include(modules/src/ts/make.cmake)
endif ()

if (BUILD_SDL)
    include(modules/src/sdl/make.cmake)
endif ()

if (BUILD_BLUE_TOOTH)
    include(modules/src/bluetooth/make.cmake)
endif ()

if (BUILD_SQLITE)
    include(modules/src/sqlite/make.cmake)
endif ()

if (BUILD_MBED_TLS)
    include(modules/src/mbedtls/make.cmake)
endif ()

if (BUILD_LNODE_EXE)
    include(node.lua/deps/main/make.cmake)
    include(node.lua/deps/update/make.cmake)
endif ()
