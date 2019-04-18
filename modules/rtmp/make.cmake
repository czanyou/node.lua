cmake_minimum_required(VERSION 2.8)

set(MBEDTLS_DIR ${CMAKE_CURRENT_LIST_DIR}/src)

include_directories(
  ${MBEDTLS_DIR}/srs/
)

set(SOURCES
  ${MBEDTLS_DIR}/srs/srs_librtmp.cpp
)

set(MAIN_SOURCES
  ${MBEDTLS_DIR}/main.cpp
)

if (WIN32)
  add_library(lrtmp SHARED ${SOURCES})
  set_target_properties(lrtmp PROPERTIES PREFIX "")
  target_link_libraries(lrtmp lualib)
  
elseif (APPLE)
  add_library(lrtmp STATIC ${SOURCES})

else ()
  add_library(lrtmp SHARED ${SOURCES})
  set_target_properties(lrtmp PROPERTIES PREFIX "")

  add_executable(rtmpc ${MAIN_SOURCES})
  target_link_libraries(rtmpc lrtmp m)

endif ()
