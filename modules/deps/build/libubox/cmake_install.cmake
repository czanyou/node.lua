# Install script for directory: /mnt/c/work/node.lua.tour/modules/deps/libubox

# Set the install prefix
IF(NOT DEFINED CMAKE_INSTALL_PREFIX)
  SET(CMAKE_INSTALL_PREFIX "/usr/local")
ENDIF(NOT DEFINED CMAKE_INSTALL_PREFIX)
STRING(REGEX REPLACE "/$" "" CMAKE_INSTALL_PREFIX "${CMAKE_INSTALL_PREFIX}")

# Set the install configuration name.
IF(NOT DEFINED CMAKE_INSTALL_CONFIG_NAME)
  IF(BUILD_TYPE)
    STRING(REGEX REPLACE "^[^A-Za-z0-9_]+" ""
           CMAKE_INSTALL_CONFIG_NAME "${BUILD_TYPE}")
  ELSE(BUILD_TYPE)
    SET(CMAKE_INSTALL_CONFIG_NAME "")
  ENDIF(BUILD_TYPE)
  MESSAGE(STATUS "Install configuration: \"${CMAKE_INSTALL_CONFIG_NAME}\"")
ENDIF(NOT DEFINED CMAKE_INSTALL_CONFIG_NAME)

# Set the component getting installed.
IF(NOT CMAKE_INSTALL_COMPONENT)
  IF(COMPONENT)
    MESSAGE(STATUS "Install component: \"${COMPONENT}\"")
    SET(CMAKE_INSTALL_COMPONENT "${COMPONENT}")
  ELSE(COMPONENT)
    SET(CMAKE_INSTALL_COMPONENT)
  ENDIF(COMPONENT)
ENDIF(NOT CMAKE_INSTALL_COMPONENT)

# Install shared libraries without execute permission?
IF(NOT DEFINED CMAKE_INSTALL_SO_NO_EXE)
  SET(CMAKE_INSTALL_SO_NO_EXE "1")
ENDIF(NOT DEFINED CMAKE_INSTALL_SO_NO_EXE)

IF(NOT CMAKE_INSTALL_COMPONENT OR "${CMAKE_INSTALL_COMPONENT}" STREQUAL "Unspecified")
  FILE(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/include/libubox" TYPE FILE FILES
    "/mnt/c/work/node.lua.tour/modules/deps/libubox/avl-cmp.h"
    "/mnt/c/work/node.lua.tour/modules/deps/libubox/avl.h"
    "/mnt/c/work/node.lua.tour/modules/deps/libubox/blob.h"
    "/mnt/c/work/node.lua.tour/modules/deps/libubox/blobmsg.h"
    "/mnt/c/work/node.lua.tour/modules/deps/libubox/blobmsg_json.h"
    "/mnt/c/work/node.lua.tour/modules/deps/libubox/json_script.h"
    "/mnt/c/work/node.lua.tour/modules/deps/libubox/kvlist.h"
    "/mnt/c/work/node.lua.tour/modules/deps/libubox/list.h"
    "/mnt/c/work/node.lua.tour/modules/deps/libubox/md5.h"
    "/mnt/c/work/node.lua.tour/modules/deps/libubox/runqueue.h"
    "/mnt/c/work/node.lua.tour/modules/deps/libubox/safe_list.h"
    "/mnt/c/work/node.lua.tour/modules/deps/libubox/ulog.h"
    "/mnt/c/work/node.lua.tour/modules/deps/libubox/uloop.h"
    "/mnt/c/work/node.lua.tour/modules/deps/libubox/usock.h"
    "/mnt/c/work/node.lua.tour/modules/deps/libubox/ustream.h"
    "/mnt/c/work/node.lua.tour/modules/deps/libubox/utils.h"
    "/mnt/c/work/node.lua.tour/modules/deps/libubox/vlist.h"
    )
ENDIF(NOT CMAKE_INSTALL_COMPONENT OR "${CMAKE_INSTALL_COMPONENT}" STREQUAL "Unspecified")

IF(NOT CMAKE_INSTALL_COMPONENT OR "${CMAKE_INSTALL_COMPONENT}" STREQUAL "Unspecified")
  FILE(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/share/libubox" TYPE FILE FILES "/mnt/c/work/node.lua.tour/modules/deps/libubox/sh/jshn.sh")
ENDIF(NOT CMAKE_INSTALL_COMPONENT OR "${CMAKE_INSTALL_COMPONENT}" STREQUAL "Unspecified")

IF(CMAKE_INSTALL_COMPONENT)
  SET(CMAKE_INSTALL_MANIFEST "install_manifest_${CMAKE_INSTALL_COMPONENT}.txt")
ELSE(CMAKE_INSTALL_COMPONENT)
  SET(CMAKE_INSTALL_MANIFEST "install_manifest.txt")
ENDIF(CMAKE_INSTALL_COMPONENT)

FILE(WRITE "/mnt/c/work/node.lua.tour/modules/deps/build/libubox/${CMAKE_INSTALL_MANIFEST}" "")
FOREACH(file ${CMAKE_INSTALL_MANIFEST_FILES})
  FILE(APPEND "/mnt/c/work/node.lua.tour/modules/deps/build/libubox/${CMAKE_INSTALL_MANIFEST}" "${file}\n")
ENDFOREACH(file)
