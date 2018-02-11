cmake_minimum_required(VERSION 2.8)

message(STATUS "Build: BUILD_BLUE_TOOTH:     ${BUILD_BLUE_TOOTH} ")
message(STATUS "Build: BUILD_MBED_TLS:       ${BUILD_MBED_TLS} ")
message(STATUS "Build: BUILD_SDL:            ${BUILD_SDL} ")
message(STATUS "Build: BUILD_SQLITE:         ${BUILD_SQLITE} ")

if (BUILD_BLUE_TOOTH)
    include(modules/bluetooth/make.cmake)
endif ()

if (BUILD_MBED_TLS)
    include(modules/mbedtls/make.cmake)
endif ()

if (BUILD_SDL)
    include(modules/sdl/make.cmake)
endif ()

if (BUILD_SQLITE)
    include(modules/sqlite3/make.cmake)
endif ()
