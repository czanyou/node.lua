cmake_minimum_required(VERSION 2.8)

set(MAINDIR ${CMAKE_CURRENT_LIST_DIR})

# lua.lia
target_link_libraries(lualib luazip luajson luautils luauv libuv)
if (LINUX)
  target_link_libraries(lualib dl m rt)
endif ()

include_directories(${MAINDIR}/src)

# luv
if (BUILD_LUV)
  set(LUV_SOURCES ${MAINDIR}/src/lnode.c)
  add_library(luv SHARED ${LUV_SOURCES})
  target_link_libraries(luv lualib)

  if (BUILD_MBEDTLS)
    add_definitions(-DBUILD_MBEDTLS)
    target_link_libraries(luv lmbedtls)
  endif ()

  if (BUILD_MODBUS)
    add_definitions(-DBUILD_MODBUS)
    target_link_libraries(luv lmodbus)
  endif ()
endif ()

# lnode
if (BUILD_LNODE)
  set(MAIN_SOURCES ${MAINDIR}/src/lnode.c ${MAINDIR}/src/node.c)
  add_executable(lnode ${MAIN_SOURCES})
  target_link_libraries(lnode lualib)

  if (BUILD_MBEDTLS)
    add_definitions(-DBUILD_MBEDTLS)
    target_link_libraries(lnode lmbedtls)
  endif ()

  if (BUILD_MODBUS)
    add_definitions(-DBUILD_MODBUS)
    target_link_libraries(lnode lmodbus)
  endif ()
endif ()

# nm -D xxx.so | grep T 查看动态库导出的函数列表
