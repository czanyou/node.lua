cmake_minimum_required(VERSION 2.8.9)

set(MODULE_DIR ${CMAKE_CURRENT_LIST_DIR})

include_directories(
  ${CMAKE_CURRENT_LIST_DIR}/lua/src
  ${MODULE_DIR}/include
)

set(SOURCES
  ${MODULE_DIR}/src/media_system.c
  ${MODULE_DIR}/src/media_isp.c
  ${MODULE_DIR}/src/media_video.c
  ${MODULE_DIR}/src/media_audio.c
)

if (BUILD_FAAD)
  add_definitions(-DMEDIA_USE_FAAD)  
endif ()

add_library(sml STATIC ${SOURCES})

