cmake_minimum_required(VERSION 2.8)

set(BUILD_BLUETOOTH      OFF)
set(BUILD_MBEDTLS        OFF)
set(BUILD_DEVICES        ON)
set(BUILD_SQLITE         OFF)
set(BUILD_UBOX           OFF)
set(BUILD_UBUS           OFF)
set(BUILD_UCI            OFF)

message(STATUS, $ENV{STAGING_DIR})

#set( ENV{PATH} /home/martink )
# export PATH=$PATH:/opt/openwrt/staging_dir/toolchain-mipsel_24kc_gcc-7.3.0_musl/bin
# export STAGING_DIR=/opt/openwrt/staging_dir/

set(CMAKE_C_COMPILER "mipsel-openwrt-linux-gcc")
