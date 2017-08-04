cmake_minimum_required(VERSION 2.8)

set(MODULE_DIR ${CMAKE_CURRENT_LIST_DIR})

include_directories(
  ${MODULE_DIR}/src
)

set(SOURCES
  ${MODULE_DIR}/src/sqlite3.c
  ${MODULE_DIR}/src/sqlite3_lua.c
)

if (WIN32)
  add_library(lsqlite SHARED ${SOURCES})
  set_target_properties(lsqlite PROPERTIES PREFIX "")
  target_link_libraries(lsqlite lualib)
  
elseif (APPLE)
  add_library(lsqlite STATIC ${SOURCES})

else ()
  add_library(lsqlite SHARED ${SOURCES})
  set_target_properties(lsqlite PROPERTIES PREFIX "")

endif ()
