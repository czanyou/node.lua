cmake_minimum_required(VERSION 2.8)

include_directories(
  ${CMAKE_CURRENT_LIST_DIR}/src
  ${CMAKE_CURRENT_LIST_DIR}/../deps/
  ${CMAKE_CURRENT_LIST_DIR}/../deps/ubus
)

set(SOURCES
  ${CMAKE_CURRENT_LIST_DIR}/src/ubus.c
)

LINK_DIRECTORIES("${CMAKE_CURRENT_SOURCE_DIR}/build/${BOARD_TYPE}/")

add_library(lubus SHARED ${SOURCES})
target_link_libraries(lubus ubox ubus)
set_target_properties(lubus PROPERTIES PREFIX "")