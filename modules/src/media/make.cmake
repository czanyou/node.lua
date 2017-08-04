cmake_minimum_required(VERSION 2.8)

set(MODULE_DIR ${CMAKE_CURRENT_LIST_DIR})

include_directories(
  ${MODULE_DIR}/common
  ${MODULE_DIR}/../common
)

set(SOURCES
  ${MODULE_DIR}/lmedia.c
  ${MODULE_DIR}/sml/audio_in_lua.c
  ${MODULE_DIR}/sml/audio_out_lua.c
  ${MODULE_DIR}/sml/media_lua.c
  ${MODULE_DIR}/sml/video_encoder_lua.c
  ${MODULE_DIR}/sml/video_in_lua.c
)

set(BUILD_WITH_AW_ENCODER OFF)
set(BUILD_WITH_ALSA       OFF)
set(BUILD_WITH_JPEG_LIB   OFF)

if (BUILD_SML) 

  if (BOARD_TYPE STREQUAL local)
    set(BUILD_WITH_ALSA ON)
    set(BUILD_WITH_JPEG_LIB ON)
    set(BUILD_WITH_AW_ENCODER ON)
  endif ()

  # find libvencoder
  # Build with allwinner video encoder (NanoPi only)
  if (BUILD_WITH_AW_ENCODER)
    FIND_FILE(PATH_AW_ENCODER "libvencoder.so" "/usr/local/lib/")
    if (PATH_AW_ENCODER STREQUAL "PATH_AW_ENCODER-NOTFOUND")
        set(BUILD_WITH_AW_ENCODER OFF)
        MESSAGE(STATUS "Build: libvencoder not found")
    else ()
        set(BUILD_WITH_AW_ENCODER ON)
    endif ()
  endif (BUILD_WITH_AW_ENCODER)

  # find libalsa
  # Build with alsa audio lib (Linux only)
  # alsa: sudo apt install -y libasound2-dev
  if (BUILD_WITH_ALSA)
    FIND_FILE(PATH_ALSA "asoundlib.h" "/usr/include/alsa")
    if (PATH_ALSA STREQUAL "PATH_ALSA-NOTFOUND")
        set(BUILD_WITH_ALSA OFF)
        MESSAGE(STATUS "Build: asoundlib.h not found")
    endif ()
  endif (BUILD_WITH_ALSA)

  # find jpeglib
  # Build with jpeg lib (Linux only)
  # sudo apt install -y libjpeg-dev
  if (BUILD_WITH_JPEG_LIB)
    FIND_FILE(PATH_JPEG "jpeglib.h" "/usr/include/")
    if (PATH_JPEG STREQUAL "PATH_JPEG-NOTFOUND")
        set(BUILD_WITH_JPEG_LIB OFF)
        MESSAGE(STATUS "Build: jpeglib.h not found")
    endif ()
  endif (BUILD_WITH_JPEG_LIB)

else ()


endif ()

MESSAGE(STATUS "Build: BUILD_SML=${BUILD_SML}")
MESSAGE(STATUS "Build: BUILD_WITH_ALSA=${BUILD_WITH_ALSA}")
MESSAGE(STATUS "Build: BUILD_WITH_JPEG_LIB=${BUILD_WITH_JPEG_LIB}")
MESSAGE(STATUS "Build: BUILD_WITH_AW_ENCODER=${BUILD_WITH_AW_ENCODER}")

if (WIN32)
  add_library(lmedia SHARED ${SOURCES})

  set_target_properties(lmedia PROPERTIES PREFIX "")
  target_link_libraries(lmedia sml lualib uv)
  target_link_libraries(lmedia ws2_32.lib shell32.lib psapi.lib iphlpapi.lib advapi32.lib Userenv.lib)

elseif (APPLE)
  add_library(lmedia STATIC ${SOURCES})

elseif (LINUX)
  add_library(lmedia SHARED ${SOURCES})
  target_link_libraries(lmedia sml)

  add_definitions(-DMEDIA_USE_SML)

  if (BOARD_TYPE STREQUAL hi3518)
    target_link_libraries(lmedia mpi isp voice sns_ov9712)

  elseif (BOARD_TYPE STREQUAL hi3516a)
    target_link_libraries(lmedia mpp)
   
  endif ()

  if (BUILD_FAAC)
    target_link_libraries(lmedia faac)
    add_definitions(-DMEDIA_USE_FAAC)
  endif ()

  if (BUILD_FAAD)
    target_link_libraries(lmedia faad)
    add_definitions(-DMEDIA_USE_FAAD)
  endif ()

  if (BUILD_WITH_ALSA)
    target_link_libraries(lmedia asound)
    add_definitions(-DMEDIA_USE_ALSA)
  endif ()

  if (BUILD_WITH_JPEG_LIB)
    target_link_libraries(lmedia jpeg)
    add_definitions(-DMEDIA_USE_JPEG_LIB)
  endif ()

  if (BUILD_WITH_AW_ENCODER)
    target_link_libraries(lmedia vencoder cdx_base MemAdapter VE)
    add_definitions(-DMEDIA_USE_AW_ENCODER)
  endif ()

  set_target_properties(lmedia PROPERTIES PREFIX "")

endif ()
