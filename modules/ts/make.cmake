cmake_minimum_required(VERSION 2.8)

set(MODULE_DIR ${CMAKE_CURRENT_LIST_DIR})

include_directories(
  ${MODULE_DIR}/src
)

set(SOURCES
  ${MODULE_DIR}/src/ts_common.c 
  ${MODULE_DIR}/src/ts_reader.c 
  ${MODULE_DIR}/src/ts_reader_lua.c
  ${MODULE_DIR}/src/ts_writer.c
  ${MODULE_DIR}/src/ts_writer_lua.c
)

if (WIN32)
  add_library(lts SHARED ${SOURCES})
  set_target_properties(lts PROPERTIES PREFIX "")

  target_link_libraries(lts lualib uv)
  target_link_libraries(lts ws2_32.lib shell32.lib psapi.lib iphlpapi.lib advapi32.lib Userenv.lib)


elseif (APPLE)
  add_library(lts STATIC ${SOURCES})

elseif (LINUX)
  add_library(lts SHARED ${SOURCES})
  set_target_properties(lts PROPERTIES PREFIX "")

endif ()
