cmake_minimum_required(VERSION 2.8)

# 

set(UPDATEDIR ${CMAKE_CURRENT_LIST_DIR})

include_directories(
  ${UPDATEDIR}/src
)

set(SOURCES
  ${UPDATEDIR}/src/main.c
)

add_executable(lupdate ${SOURCES})

if (LINUX)

target_link_libraries(lupdate dl m rt)

endif ()

