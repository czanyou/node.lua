cmake_minimum_required(VERSION 2.8)

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
# lnode.exe

if (BUILD_LNODE_EXE)
    include(node.lua/deps/main/make.cmake)
endif ()
