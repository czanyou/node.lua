cmake_minimum_required(VERSION 2.8)

set(MODULE_DIR ${CMAKE_CURRENT_LIST_DIR})

include_directories(
  ${MODULE_DIR}
  ${MODULE_DIR}/../../core/deps/luautils/src/
)

set(SOURCES
  ${MODULE_DIR}/src/ble_lua.c
  ${CMAKE_CURRENT_LIST_DIR}/../../core/deps/luautils/src/buffer_queue.c
)

# You need to install libbluetooth-dev package for compiling your code
#$ sudo apt install -y libbluetooth-dev
# That should install the bluetooth header files.

# find libbluetooth
if (BUILD_BLUETOOTH)
  FIND_FILE(PATH_BLUETOOTH "bluetooth.h" "/usr/include/bluetooth")
  if (PATH_BLUETOOTH STREQUAL "PATH_BLUETOOTH-NOTFOUND")
      set(BUILD_BLUETOOTH OFF)
      MESSAGE(STATUS "Build: bluetooth dev not found")
  endif ()
endif (BUILD_BLUETOOTH)

if (BUILD_BLUETOOTH)
  add_library(lbluetooth SHARED ${SOURCES})

  target_link_libraries(lbluetooth bluetooth)
  set_target_properties(lbluetooth PROPERTIES PREFIX "")

  if (WIN32)
    target_link_libraries(lbluetooth lua53)
    
  elseif (APPLE)
    target_link_libraries(lbluetooth lua53)
    set_target_properties(lbluetooth PROPERTIES SUFFIX ".so")

  endif ()
endif (BUILD_BLUETOOTH)