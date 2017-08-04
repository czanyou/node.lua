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
)

# 生成 libsml.a 静态库
add_library(sml STATIC ${SOURCES})
