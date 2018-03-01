cmake_minimum_required(VERSION 2.8)
  
project(Node.lua)  # Project Name

# Project Version Code
set(LNODE_MAJOR_VERSION 3)
set(LNODE_MINOR_VERSION 2)

# The PATCH version see `app/lhost/lua/init.lua`

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

# Build lnode execute
option(BUILD_LNODE_EXE  "Build lnode execute"  ON)

option(BUILD_BLUE_TOOTH "Build with bluetooth" OFF)
option(BUILD_MBED_TLS   "Build mbedtls module" OFF)
option(BUILD_SDL        "Build sdl module"     OFF)
option(BUILD_SQLITE     "Build sqlite3 module" OFF)

set(BUILD_LNODE_EXE       ON)
set(BUILD_SHARED_LUA_LIB  OFF)

# Lua module build type (Shared|Static)
if (WIN32)
  set(BUILD_SHARED_LUA_LIB ON)

elseif (APPLE)
  set(CMAKE_MACOSX_RPATH 0)

elseif (LINUX)

endif ()

include(config.cmake)

# Development board type
if (NOT BOARD_TYPE)
  set(BOARD_TYPE local)
endif ()

###############################################################################
# Cross compiler options
# determine the parameters of the compiler tool chain through BOARD_TYPE

###############################################################################

message(STATUS "Build: BOARD_TYPE:           ${BOARD_TYPE}")
message(STATUS "Build: BUILD_LNODE_EXE:      ${BUILD_LNODE_EXE} ")
message(STATUS "Build: BUILD_SHARED_LUA_LIB: ${BUILD_SHARED_LUA_LIB}")
message(STATUS "Build: CC: ${CMAKE_C_COMPILER}")

###############################################################################
# OS build options

if (WIN32)
  add_definitions("/wd4005" "/wd4244" "/wd4819" "/wd4996")

  # See `deps/lua/src/luaconf.h`
  add_definitions(-DLUA_BUILD_AS_DLL -DLUA_LIB)

  # The install path
  add_definitions(-DNODE_LUA_ROOT="C:/Program Files/lnode")

  # Replace /MD to /MT to avoid link msvcr*.dll
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
  # See `deps/lua/src/luaconf.h`
  add_definitions(-DLUA_USE_POSIX -DLUA_USE_DLOPEN)

  # The install path
  add_definitions(-DNODE_LUA_ROOT="/usr/local/lnode")


  set(CMAKE_SHARED_MODULE_CREATE_C_FLAGS
    "${CMAKE_SHARED_MODULE_CREATE_C_FLAGS} -bundle -flat_namespace -undefined suppress"
  )

  add_definitions(-fPIC)
  add_definitions(-Wdeprecated-declarations)

elseif (LINUX)

  # Add share object flags
  # Under 64bit Linux, you must add -fPIC option to compile a dynamic link library
  add_definitions("-fPIC")

  # Retain function names, etc., to facilitate dlopen or debugging
  add_definitions("-rdynamic")

  # See `deps/lua/src/luaconf.h`
  add_definitions(-DLUA_USE_POSIX -DLUA_USE_DLOPEN)

  # The install path
  add_definitions(-DNODE_LUA_ROOT="/usr/local/lnode")

endif ()

include(modules/make.cmake)
include(node.lua/make.cmake)
