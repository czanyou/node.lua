cmake_minimum_required(VERSION 2.6)

PROJECT(ubus C)
ADD_DEFINITIONS(-Os -Wall -Werror --std=gnu99 -g3 -Wmissing-declarations)

include(../common.cmake)

OPTION(BUILD_LUA "build Lua plugin" OFF)
OPTION(BUILD_EXAMPLES "build examples" OFF)

SET(CMAKE_SHARED_LIBRARY_LINK_C_FLAGS "")
SET(UBUS_UNIX_SOCKET "/var/run/ubus.sock")
SET(UBUS_MAX_MSGLEN 1048576)
SET(BUILD_STATIC OFF)

ADD_DEFINITIONS( -DUBUS_UNIX_SOCKET="${UBUS_UNIX_SOCKET}")
ADD_DEFINITIONS( -DUBUS_MAX_MSGLEN=${UBUS_MAX_MSGLEN})

SET(CMAKE_PREFIX_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../build/libubox")

LINK_DIRECTORIES("${CMAKE_CURRENT_SOURCE_DIR}/../build/libubox/")
LINK_DIRECTORIES("${CMAKE_CURRENT_SOURCE_DIR}/../build/json-c/")

SET(ubox_library, "ubox")
SET(blob_library, "blobmsg_json")
SET(json, "json-c")

SET(CMAKE_INCLUDE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../")

INCLUDE_DIRECTORIES(${CMAKE_CURRENT_SOURCE_DIR}/../)

ADD_LIBRARY(ubus SHARED libubus.c libubus-io.c libubus-obj.c libubus-sub.c libubus-req.c libubus-acl.c)
TARGET_LINK_LIBRARIES(ubus ubox)

ADD_EXECUTABLE(ubusd ubusd.c ubusd_id.c ubusd_obj.c ubusd_proto.c ubusd_event.c ubusd_acl.c ubusd_monitor.c)
TARGET_LINK_LIBRARIES(ubusd ubox blobmsg_json json-c)

ADD_EXECUTABLE(cli cli.c)
SET_TARGET_PROPERTIES(cli PROPERTIES OUTPUT_NAME ubus)
TARGET_LINK_LIBRARIES(cli ubus ubox blobmsg_json json-c)

#ADD_SUBDIRECTORY(lua)
#ADD_SUBDIRECTORY(examples)

INSTALL(TARGETS ubus cli
	LIBRARY DESTINATION lib
	RUNTIME DESTINATION bin
)
INSTALL(TARGETS ubusd
	RUNTIME DESTINATION sbin
)

INSTALL(FILES ubusmsg.h ubus_common.h libubus.h DESTINATION include)
