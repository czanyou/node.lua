cmake_minimum_required(VERSION 2.8)

# 

set(MAINDIR ${CMAKE_CURRENT_LIST_DIR})

include_directories(
  ${MAINDIR}/src
)

set(SOURCES
  ${MAINDIR}/src/lnode.c
  ${MAINDIR}/src/main.c
)

add_executable(lnode ${SOURCES})

target_link_libraries(lualib luazip luajson luautils luauv uv)
target_link_libraries(lnode lualib)

if (APPLE)
target_link_libraries(lnode lsqlite)

elseif (LINUX)
target_link_libraries(lnode dl m rt)

endif ()

