cmake_minimum_required(VERSION 2.8)

set(MODULE_DIR ${CMAKE_CURRENT_LIST_DIR})

include_directories(
  ${MODULE_DIR}/src
)

set(SOURCES
  ${MODULE_DIR}/src/flv.c 
  ${MODULE_DIR}/src/rtmp_lua.c 
)

if (WIN32)
  add_library(lrtmp SHARED ${SOURCES})
  set_target_properties(lrtmp PROPERTIES PREFIX "")

  target_link_libraries(lrtmp lualib libuv)
  target_link_libraries(lrtmp ws2_32.lib shell32.lib psapi.lib iphlpapi.lib advapi32.lib Userenv.lib)

elseif (APPLE)
  add_library(lrtmp STATIC ${SOURCES})

elseif (LINUX)
  add_library(lrtmp SHARED ${SOURCES})
  set_target_properties(lrtmp PROPERTIES PREFIX "")

endif ()
