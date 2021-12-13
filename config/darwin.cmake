cmake_minimum_required(VERSION 2.8)

set(BUILD_BLUETOOTH       OFF)
set(BUILD_CAMERA          ON)
set(BUILD_DEVICES         ON)
set(BUILD_LNODE           ON)
set(BUILD_LUV             OFF)
set(BUILD_MBEDTLS         ON)
set(BUILD_MEDIA_TS        ON)
set(BUILD_MESSAGE         ON)
set(BUILD_SQLITE          ON)

add_definitions(-DNODE_LUA_RESOURCE)