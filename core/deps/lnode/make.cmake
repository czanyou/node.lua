cmake_minimum_required(VERSION 2.8)

# 

set(MAINDIR ${CMAKE_CURRENT_LIST_DIR})

include_directories(
  ${MAINDIR}/src
)

set(SOURCES
  ${MAINDIR}/src/lnode.c
)

set(MAIN_SOURCES
  ${MAINDIR}/src/node.c
)

set(LUA_SOURCES
  ${MAINDIR}/src/main.c
)

add_executable(lnode ${MAIN_SOURCES} ${SOURCES})

target_link_libraries(lualib luazip luajson luautils luauv uv)
target_link_libraries(lnode lualib)

add_library(luv SHARED ${SOURCES})
target_link_libraries(luv lualib)

add_executable(lua ${LUA_SOURCES})
target_link_libraries(lua lualib)
set_target_properties(luv PROPERTIES PREFIX "")

if (APPLE)

elseif (LINUX)
target_link_libraries(lnode dl m rt)
target_link_libraries(luv dl m rt)
target_link_libraries(lua dl m rt)

endif ()

