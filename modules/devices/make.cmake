cmake_minimum_required(VERSION 2.8)

set(MODULE_DIR ${CMAKE_CURRENT_LIST_DIR})

include_directories(
  ${MODULE_DIR}/src
)

set(SOURCES
  ${MODULE_DIR}/src/gpio_lua.c
  ${MODULE_DIR}/src/i2c.c
  ${MODULE_DIR}/src/i2c_lua.c
  ${MODULE_DIR}/src/sdl_lua.c
)

if (WIN32)
  add_library(lsdl SHARED ${SOURCES})
  set_target_properties(lsdl PROPERTIES PREFIX "")

elseif (APPLE)
  add_library(lsdl STATIC ${SOURCES})

elseif (LINUX)
  add_library(lsdl SHARED ${SOURCES})
  set_target_properties(lsdl PROPERTIES PREFIX "")

endif ()
