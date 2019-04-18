cmake_minimum_required(VERSION 2.8)

message(STATUS "Build: BUILD_BLUETOOTH:     ${BUILD_BLUETOOTH}")
message(STATUS "Build: BUILD_CAMERA:        ${BUILD_CAMERA}")
message(STATUS "Build: BUILD_MBEDTLS:       ${BUILD_MBEDTLS}")
message(STATUS "Build: BUILD_MESSAGE:       ${BUILD_MESSAGE}")
message(STATUS "Build: BUILD_MOSQUITTO:     ${BUILD_MOSQUITTO}")

message(STATUS "Build: BUILD_SQLITE:        ${BUILD_SQLITE}")
message(STATUS "Build: BUILD_SDL:           ${BUILD_SDL}")
message(STATUS "Build: BUILD_TS:            ${BUILD_TS}")
message(STATUS "Build: BUILD_UBOX:          ${BUILD_UBOX}")
message(STATUS "Build: BUILD_UBUS:          ${BUILD_UBUS}")
message(STATUS "Build: BUILD_UCI:           ${BUILD_UCI}")
message(STATUS "Build: BUILD_RTMP:          ${BUILD_RTMP}")

# HCI bluetooth
if (BUILD_BLUETOOTH)
    include(modules/bluetooth/make.cmake)
endif ()

# UVC USB camera
if (BUILD_CAMERA)
    include(modules/camera/make.cmake)
endif ()

# TLS
# 
if (BUILD_MBEDTLS)
    include(modules/mbedtls/make.cmake)
endif ()

# Thread message
if (BUILD_MESSAGE)
    include(modules/message/make.cmake)
endif ()

# MQTT client
# 
if (BUILD_MOSQUITTO)
    include(modules/mosquitto/make.cmake)
endif ()

# Simple device layer
if (BUILD_SDL)
    include(modules/sdl/make.cmake)
endif ()

# Sqlite 3 database
if (BUILD_SQLITE)
    include(modules/sqlite/make.cmake)
endif ()

# MEPG TS Stream
if (BUILD_TS)
    include(modules/ts/make.cmake)
endif ()

# OpenWrt core utilities
# https://git.openwrt.org/project/ubox.git
if (BUILD_UBOX)
    include(modules/ubox/make.cmake)
endif ()

# OpenWrt system message/RPC bus
# https://git.openwrt.org/project/ubus.git
if (BUILD_UBUS)
    include(modules/ubus/make.cmake)
endif ()

# OpenWrt Unified Configuration Interface
# https://git.openwrt.org/project/uci.git
if (BUILD_UCI)
    include(modules/uci/make.cmake)
endif ()

if (BUILD_RTMP)
#    include(modules/rtmp/make.cmake)
endif ()
