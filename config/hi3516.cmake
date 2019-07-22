cmake_minimum_required(VERSION 2.8)

set(BUILD_BLUETOOTH      OFF)
set(BUILD_CAMERA         OFF)
set(BUILD_MBEDTLS        OFF)
set(BUILD_MESSAGE        OFF)
set(BUILD_DEVICES        OFF)
set(BUILD_SQLITE         OFF)
set(BUILD_MEDIA_TS       OFF)
set(BUILD_MODBUS         ON)

add_definitions(-D_NO_GLIBC)

set(CMAKE_C_COMPILER "/opt/hisi-linux/x86-arm/arm-hisiv500-linux/target/bin/arm-hisiv500-linux-gcc")