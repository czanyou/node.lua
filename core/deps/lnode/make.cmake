cmake_minimum_required(VERSION 2.8)

# lnode
set(MAINDIR ${CMAKE_CURRENT_LIST_DIR})

# lualia
target_link_libraries(lualib luazip luajson luautils luauv uv)
if (LINUX)
  target_link_libraries(lualib dl m rt)
endif ()

include_directories(
  ${MAINDIR}/src
)

# luv
set(LUV_SOURCES
  ${MAINDIR}/src/lnode.c
)
add_library(luv SHARED ${LUV_SOURCES})
target_link_libraries(luv lualib)

# lnode
set(MAIN_SOURCES
  ${MAINDIR}/src/node.c
)
add_executable(lnode ${MAIN_SOURCES} ${LUV_SOURCES})
target_link_libraries(lnode lualib)

# nm -D xxx.so | grep T 查看动态库导出的函数列表
