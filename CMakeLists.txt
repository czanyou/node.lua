cmake_minimum_required(VERSION 2.8)
  
project(Node.lua)  # Project Name

# Project Version Code
set(LNODE_MAJOR_VERSION 4)
set(LNODE_MINOR_VERSION 1)

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
set(BUILD_SHARED_LUA_LIB  OFF)

# Lua module build type (Shared|Static)
if (WIN32)
  set(BUILD_SHARED_LUA_LIB ON)

elseif (APPLE)
  set(CMAKE_MACOSX_RPATH 0)

elseif (LINUX)

endif ()


###############################################################################
# Cross compiler options
# determine the parameters of the compiler tool chain through BOARD_TYPE

# Development board type
if (NOT BOARD_TYPE)
  set(BOARD_TYPE local)
endif ()

include(config/${BOARD_TYPE}.cmake)

message(STATUS "Build: BOARD_TYPE: ${BOARD_TYPE}")
message(STATUS "Build: CC: ${CMAKE_C_COMPILER}")


###############################################################################
# OS build options

if (WIN32)
  add_definitions("/wd4005" "/wd4244" "/wd4819" "/wd4996")

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
  add_definitions("-fPIC")
  add_definitions("-Wdeprecated-declarations")

elseif (LINUX)
  # Add share object flags
  # Under 64bit Linux, you must add -fPIC option to compile a dynamic link library
  add_definitions("-fPIC")

  # Retain function names, etc., to facilitate dlopen or debugging
  add_definitions("-rdynamic")

endif ()


###############################################################################
# build sub directory

include(modules/make.cmake)
include(core/make.cmake)

###############################################################################
