cmake_minimum_required(VERSION 2.8)

set(BUILD_BLUETOOTH       OFF)
set(BUILD_CAMERA          OFF)
set(BUILD_MBEDTLS         ON)
set(BUILD_MESSAGE         OFF)
set(BUILD_DEVICES         OFF)
set(BUILD_SQLITE          OFF)
set(BUILD_MEDIA_TS        OFF)
set(BUILD_MODBUS          ON)

add_definitions(-DNODE_LUA_BOARD="linux")
add_definitions(-DNODE_LUA_RESOURCE)

