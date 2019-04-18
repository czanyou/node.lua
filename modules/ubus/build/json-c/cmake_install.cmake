# Install script for directory: /mnt/c/work/node.lua.tour/modules/ubus/json-c

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
  FILE(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/lib" TYPE STATIC_LIBRARY FILES "/mnt/c/work/node.lua.tour/modules/ubus/build/json-c/libjson-c.a")
ENDIF(NOT CMAKE_INSTALL_COMPONENT OR "${CMAKE_INSTALL_COMPONENT}" STREQUAL "Unspecified")

IF(NOT CMAKE_INSTALL_COMPONENT OR "${CMAKE_INSTALL_COMPONENT}" STREQUAL "Unspecified")
  list(APPEND CMAKE_ABSOLUTE_DESTINATION_FILES
   "/usr/local/include/json-c/config.h;/usr/local/include/json-c/json_config.h;/usr/local/include/json-c/json.h;/usr/local/include/json-c/arraylist.h;/usr/local/include/json-c/debug.h;/usr/local/include/json-c/json_c_version.h;/usr/local/include/json-c/json_inttypes.h;/usr/local/include/json-c/json_object.h;/usr/local/include/json-c/json_object_iterator.h;/usr/local/include/json-c/json_pointer.h;/usr/local/include/json-c/json_tokener.h;/usr/local/include/json-c/json_util.h;/usr/local/include/json-c/linkhash.h;/usr/local/include/json-c/printbuf.h")
  IF (CMAKE_WARN_ON_ABSOLUTE_INSTALL_DESTINATION)
    message(WARNING "ABSOLUTE path INSTALL DESTINATION : ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
  ENDIF (CMAKE_WARN_ON_ABSOLUTE_INSTALL_DESTINATION)
  IF (CMAKE_ERROR_ON_ABSOLUTE_INSTALL_DESTINATION)
    message(FATAL_ERROR "ABSOLUTE path INSTALL DESTINATION forbidden (by caller): ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
  ENDIF (CMAKE_ERROR_ON_ABSOLUTE_INSTALL_DESTINATION)
FILE(INSTALL DESTINATION "/usr/local/include/json-c" TYPE FILE FILES
    "/mnt/c/work/node.lua.tour/modules/ubus/build/config.h"
    "/mnt/c/work/node.lua.tour/modules/ubus/build/json_config.h"
    "/mnt/c/work/node.lua.tour/modules/ubus/json-c/json.h"
    "/mnt/c/work/node.lua.tour/modules/ubus/json-c/arraylist.h"
    "/mnt/c/work/node.lua.tour/modules/ubus/json-c/debug.h"
    "/mnt/c/work/node.lua.tour/modules/ubus/json-c/json_c_version.h"
    "/mnt/c/work/node.lua.tour/modules/ubus/json-c/json_inttypes.h"
    "/mnt/c/work/node.lua.tour/modules/ubus/json-c/json_object.h"
    "/mnt/c/work/node.lua.tour/modules/ubus/json-c/json_object_iterator.h"
    "/mnt/c/work/node.lua.tour/modules/ubus/json-c/json_pointer.h"
    "/mnt/c/work/node.lua.tour/modules/ubus/json-c/json_tokener.h"
    "/mnt/c/work/node.lua.tour/modules/ubus/json-c/json_util.h"
    "/mnt/c/work/node.lua.tour/modules/ubus/json-c/linkhash.h"
    "/mnt/c/work/node.lua.tour/modules/ubus/json-c/printbuf.h"
    )
ENDIF(NOT CMAKE_INSTALL_COMPONENT OR "${CMAKE_INSTALL_COMPONENT}" STREQUAL "Unspecified")

