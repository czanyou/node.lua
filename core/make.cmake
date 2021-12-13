cmake_minimum_required(VERSION 2.8)

if (WIN32)
  # See `deps/lua/src/luaconf.h`
  add_definitions(-DLUA_BUILD_AS_DLL -DLUA_LIB)

  # The install path
  add_definitions(-DNODE_LUA_ROOT="C:/Program Files/lnode")

elseif (APPLE)
  # See `deps/lua/src/luaconf.h`
  add_definitions(-DLUA_USE_POSIX -DLUA_USE_DLOPEN)

  # The install path
  add_definitions(-DNODE_LUA_ROOT="/usr/local/lnode")

elseif (LINUX)
  # See `deps/lua/src/luaconf.h`
  add_definitions(-DLUA_USE_POSIX -DLUA_USE_DLOPEN)

  # The install path
  if (NODE_LUA_ROOT)
    add_definitions(-DNODE_LUA_ROOT="${NODE_LUA_ROOT}")
  else ()
    add_definitions(-DNODE_LUA_ROOT="/usr/local/lnode")
  endif()

endif ()

###############################################################################
# Include deps modules

# Include directories
include_directories(core/deps/lua/src)

include(core/deps/libuv/make.cmake)
include(core/deps/lua/make.cmake)
include(core/deps/luajson/make.cmake)
include(core/deps/luautils/make.cmake)
include(core/deps/luauv/make.cmake)
include(core/deps/luazip/make.cmake)
include(core/deps/lnode/make.cmake)
