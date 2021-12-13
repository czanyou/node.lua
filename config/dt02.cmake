cmake_minimum_required(VERSION 2.8)

set(BUILD_BLUETOOTH      OFF)
set(BUILD_CAMERA         OFF)
set(BUILD_DEVICES        OFF)
set(BUILD_LNODE          ON)
set(BUILD_LUV            OFF)
set(BUILD_MBEDTLS        ON)
set(BUILD_MEDIA_TS       OFF)
set(BUILD_MESSAGE        OFF)
set(BUILD_MODBUS         ON)
set(BUILD_SQLITE         OFF)
set(ARCH_TYPE            "arm")

add_definitions(-D_NO_GLIBC)
add_definitions(-DNODE_LUA_BOARD="dt02")
add_definitions(-DNODE_LUA_ARCH="arm")
add_definitions(-DNODE_LUA_CPU="hi3516e")
add_definitions(-DNODE_LUA_RESOURCE) # build singal execute file
add_definitions(-std=c99)

set(CMAKE_C_COMPILER "/opt/hisi-linux/x86-arm/arm-hisiv500-linux/target/bin/arm-hisiv500-linux-gcc")