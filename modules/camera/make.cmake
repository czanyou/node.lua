cmake_minimum_required(VERSION 2.8.9)

set(MODULE_DIR ${CMAKE_CURRENT_LIST_DIR})

include_directories(
  ${MODULE_DIR}/src/
)

set(SOURCES
  ${MODULE_DIR}/src/media_audio.c
  ${MODULE_DIR}/src/media_system.c
  ${MODULE_DIR}/src/media_v4l2.c
  ${MODULE_DIR}/src/media_video.c
  ${MODULE_DIR}/src/lmedia.c
  ${MODULE_DIR}/src/audio_in_lua.c
  ${MODULE_DIR}/src/audio_out_lua.c
  ${MODULE_DIR}/src/media_lua.c
  ${MODULE_DIR}/src/video_encoder_lua.c
  ${MODULE_DIR}/src/video_in_lua.c
)

set(BUILD_WITH_ALSA ON)
set(BUILD_WITH_JPEG_LIB ON)
set(BUILD_WITH_AW_ENCODER ON)

# find libvencoder
# Build with allwinner video encoder (NanoPi only)
if (BUILD_WITH_AW_ENCODER)
  FIND_FILE(PATH_AW_ENCODER "libvencoder.so" "/usr/local/lib/")
  if (PATH_AW_ENCODER STREQUAL "PATH_AW_ENCODER-NOTFOUND")
      set(BUILD_WITH_AW_ENCODER OFF)
      # MESSAGE(STATUS "Build: libvencoder not found")
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
      # MESSAGE(STATUS "Build: asoundlib.h not found")
  endif ()
endif (BUILD_WITH_ALSA)

# find jpeglib
# Build with jpeg lib (Linux only)
# sudo apt install -y libjpeg-dev
if (BUILD_WITH_JPEG_LIB)
  FIND_FILE(PATH_JPEG "jpeglib.h" "/usr/include/")
  if (PATH_JPEG STREQUAL "PATH_JPEG-NOTFOUND")
      set(BUILD_WITH_JPEG_LIB OFF)
      # MESSAGE(STATUS "Build: jpeglib.h not found")
  endif ()
endif (BUILD_WITH_JPEG_LIB)


add_library(lcamera SHARED ${SOURCES})
set_target_properties(lcamera PROPERTIES PREFIX "")

if (BUILD_WITH_ALSA)
  MESSAGE(STATUS "Build: BUILD_WITH_ALSA:       ${BUILD_WITH_ALSA}")
  target_link_libraries(lcamera asound)
  add_definitions(-DMEDIA_USE_ALSA)
endif ()

if (BUILD_WITH_JPEG_LIB)
  MESSAGE(STATUS "Build: BUILD_WITH_JPEG_LIB:   ${BUILD_WITH_JPEG_LIB}")
  target_link_libraries(lcamera jpeg)
  add_definitions(-DMEDIA_USE_JPEG_LIB)
endif ()

if (BUILD_WITH_AW_ENCODER)
  MESSAGE(STATUS "Build: BUILD_WITH_AW_ENCODER: ${BUILD_WITH_AW_ENCODER}")
  target_link_libraries(lcamera vencoder cdx_base MemAdapter VE)
  add_definitions(-DMEDIA_USE_AW_ENCODER)
endif ()

