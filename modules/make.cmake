cmake_minimum_required(VERSION 2.8)

message(STATUS "= BUILD OPTIONS: =========")
message(STATUS "# BUILD_BLUETOOTH: _______ [${BUILD_BLUETOOTH}]")
message(STATUS "# BUILD_CAMERA: __________ [${BUILD_CAMERA}]")
message(STATUS "# BUILD_DEVICES: _________ [${BUILD_DEVICES}]")
message(STATUS "# BUILD_MBEDTLS: _________ [${BUILD_MBEDTLS}]")
message(STATUS "# BUILD_MEDIA_TS: ________ [${BUILD_MEDIA_TS}]")
message(STATUS "# BUILD_MESSAGE: _________ [${BUILD_MESSAGE}]")
message(STATUS "# BUILD_MODBUS: __________ [${BUILD_MODBUS}]")
message(STATUS "# BUILD_SQLITE: __________ [${BUILD_SQLITE}]")
message(STATUS "# ARCH_TYPE: _____________ [${ARCH_TYPE}]")
message(STATUS "")

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

if (BUILD_RTSP)
    include(modules/rtsp/make.cmake)
endif ()