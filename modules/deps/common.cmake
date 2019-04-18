if (BOARD_TYPE STREQUAL mt7688)
    # for libraries and headers in the target directories
    set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
    set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)

        # 设置目标系统
    set(CMAKE_SYSTEM_NAME Linux)
    set(CMAKE_SYSTEM_PROCESSOR mips)

    # 设置工具链目录
    set(TOOL_CHAIN_DIR /opt/mt7688/staging_dir/toolchain-mipsel_24kc_gcc-7.3.0_musl)
    set(TOOL_CHAIN_DIR /opt/mt7688/staging_dir/toolchain-mipsel_24kec+dsp_gcc-4.8-linaro_uClibc-0.9.33.2)

    set(TOOL_CHAIN_INCLUDE 
        ${TOOL_CHAIN_DIR}/include
        )
    set(TOOL_CHAIN_LIB 
        ${TOOL_CHAIN_DIR}/lib

        )

    # 设置编译器位置
    set(CMAKE_C_COMPILER "mipsel-openwrt-linux-gcc")
    set(CMAKE_CXX_COMPILER "mipsel-openwrt-linux-g++")

    # 设置Cmake查找主路径
    set(CMAKE_FIND_ROOT_PATH ${TOOL_CHAIN_DIR}/)

    set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
    # 只在指定目录下查找库文件
    set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
    # 只在指定目录下查找头文件
    set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
    # 只在指定目录下查找依赖包
    set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

    include_directories(
        ${TOOL_CHAIN_DIR}/include
        )

    set(CMAKE_INCLUDE_PATH 
        ${TOOL_CHAIN_INCLUDE}
        )

    set(CMAKE_LIBRARY_PATH 
        ${TOOL_CHAIN_LIB}
        )
endif ()
