cmake_minimum_required(VERSION 2.8)

set(MODULE_DIR ${CMAKE_CURRENT_LIST_DIR})

include_directories(
  ${MODULE_DIR}/src
)

set(SOURCES
  ${MODULE_DIR}/src/modbus-data.c
  ${MODULE_DIR}/src/modbus-rtu.c
  ${MODULE_DIR}/src/modbus-tcp.c
  ${MODULE_DIR}/src/modbus.c
  ${MODULE_DIR}/src/modbus-lua.c
)

if (WIN32)
  add_library(lmodbus SHARED ${SOURCES})
  set_target_properties(lmodbus PROPERTIES PREFIX "")
  target_link_libraries(lmodbus lualib)

elseif (APPLE)
  add_library(lmodbus STATIC ${SOURCES})

elseif (LINUX)
  add_library(lmodbus SHARED ${SOURCES})
  target_link_libraries(lmodbus modbus)
  set_target_properties(lmodbus PROPERTIES PREFIX "")

endif ()
