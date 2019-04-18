cmake_minimum_required(VERSION 2.6)
INCLUDE(CheckLibraryExists)
INCLUDE(CheckFunctionExists)

include(../common.cmake)

PROJECT(ubox C)
ADD_DEFINITIONS(-Os -Wall -Werror --std=gnu99 -g3 -Wmissing-declarations)
ADD_DEFINITIONS(-fPIC)

OPTION(BUILD_LUA "build Lua plugin" OFF)
OPTION(BUILD_EXAMPLES "build examples" ON)

#INCLUDE(FindPkgConfig)
#PKG_SEARCH_MODULE(JSONC json-c)

SET(JSONC_FOUND ON)

SET(JSONC_INCLUDE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/../json-c/")
LINK_DIRECTORIES("${CMAKE_CURRENT_SOURCE_DIR}/../build/json-c/")

SET(json, "json-c")

ADD_DEFINITIONS(-DJSONC)
INCLUDE_DIRECTORIES(${JSONC_INCLUDE_DIRS})
INCLUDE_DIRECTORIES("${CMAKE_CURRENT_SOURCE_DIR}/../build/json-c/")

SET(SOURCES avl.c avl-cmp.c blob.c blobmsg.c uloop.c usock.c ustream.c ustream-fd.c vlist.c utils.c safe_list.c runqueue.c md5.c kvlist.c ulog.c base64.c)

ADD_LIBRARY(ubox SHARED ${SOURCES})
#ADD_LIBRARY(ubox-static STATIC ${SOURCES})
#SET_TARGET_PROPERTIES(ubox-static PROPERTIES OUTPUT_NAME ubox)
TARGET_LINK_LIBRARIES(ubox ${json})

CHECK_FUNCTION_EXISTS(clock_gettime HAVE_GETTIME)
IF(NOT HAVE_GETTIME)
	CHECK_LIBRARY_EXISTS(rt clock_gettime "" NEED_GETTIME)
	IF(NEED_GETTIME)
		TARGET_LINK_LIBRARIES(ubox rt)
	ENDIF()
ENDIF()

FILE(GLOB headers *.h)
INSTALL(FILES ${headers}
	DESTINATION include/libubox
)
#INSTALL(TARGETS ubox ubox-static
#	ARCHIVE DESTINATION lib
#	LIBRARY DESTINATION lib
#)

#ADD_SUBDIRECTORY(lua)
#ADD_SUBDIRECTORY(examples)

ADD_LIBRARY(blobmsg_json SHARED blobmsg_json.c)
TARGET_LINK_LIBRARIES(blobmsg_json ubox ${json})

#ADD_LIBRARY(blobmsg_json-static STATIC blobmsg_json.c)
#SET_TARGET_PROPERTIES(blobmsg_json-static
#				PROPERTIES OUTPUT_NAME blobmsg_json)

#ADD_EXECUTABLE(jshn jshn.c)
#TARGET_LINK_LIBRARIES(jshn blobmsg_json ${json})

ADD_LIBRARY(json_script SHARED json_script.c)
TARGET_LINK_LIBRARIES(json_script ubox)

#INSTALL(TARGETS blobmsg_json blobmsg_json-static jshn json_script
#	ARCHIVE DESTINATION lib
#	LIBRARY DESTINATION lib
#	RUNTIME DESTINATION bin
#)

FILE(GLOB scripts sh/*.sh)
INSTALL(FILES ${scripts}
	DESTINATION share/libubox
)

