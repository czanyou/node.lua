cmake_minimum_required(VERSION 2.8)

message(STATUS "Build: BUILD_BLUETOOTH:     ${BUILD_BLUETOOTH}")
message(STATUS "Build: BUILD_CAMERA:        ${BUILD_CAMERA}")
message(STATUS "Build: BUILD_DEVICES:       ${BUILD_DEVICES}")
message(STATUS "Build: BUILD_MBEDTLS:       ${BUILD_MBEDTLS}")
message(STATUS "Build: BUILD_MEDIA_TS:      ${BUILD_MEDIA_TS}")
message(STATUS "Build: BUILD_MESSAGE:       ${BUILD_MESSAGE}")
message(STATUS "Build: BUILD_MODBUS:        ${BUILD_MODBUS}")
message(STATUS "Build: BUILD_SQLITE:        ${BUILD_SQLITE}")

# HCI bluetooth
if (BUILD_BLUETOOTH)
    include(modules/bluetooth/make.cmake)
endif ()

# UVC USB camera
if (BUILD_CAMERA)
    include(modules/camera/make.cmake)
endif ()

# Devices layer
if (BUILD_DEVICES)
    include(modules/devices/make.cmake)
endif ()

# MEPG TS Stream
if (BUILD_MEDIA_TS)
    include(modules/media/make.cmake)
endif ()

# MBEDTLS
if (BUILD_MBEDTLS)
    include(modules/mbedtls/make.cmake)
endif ()

# Thread message
if (BUILD_MESSAGE)
    include(modules/message/make.cmake)
endif ()

# Modbus
if (BUILD_MODBUS)
    include(modules/modbus/make.cmake)
endif ()

# Sqlite 3 database
if (BUILD_SQLITE)
    include(modules/sqlite/make.cmake)
endif ()
