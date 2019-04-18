cmake_minimum_required(VERSION 2.8)

set(LUAUTILSDIR ${CMAKE_CURRENT_LIST_DIR})

include_directories(
  ${LUAUTILSDIR}/src
)

set(SOURCES
  ${LUAUTILSDIR}/src/message_lua.c

)

add_library(lmessage SHARED ${SOURCES})
set_target_properties(lmessage PROPERTIES PREFIX "")
