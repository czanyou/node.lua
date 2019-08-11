#!/bin/sh

# 用于在开发板上安装运行环境
# 用法:
#
# 在 hi3516 开发板上安装运行环境
# $ ./install.sh hi3516
#
# 删除安装的文件或者链接
# $ ./install.sh uninstall
#

PROJECT_ROOT=`pwd`
PROJECT_ROOT="`dirname ${PROJECT_ROOT}`"

BOARD_TYPE="hi3516"
LOCAL_BIN_PATH="/usr/bin"
NODE_ROOTPATH="/usr/local/lnode"

make_link() {
    # echo $1 $2
	rm -rf $2

    if [ -e $1 ]
    then 
        echo make link: $2; 
        ln -s $1 $2; 
    fi
}

# Create link for bin file
make_module_bin_link() {
	make_link "${NODE_ROOTPATH}/app/$1/bin/$1" "${LOCAL_BIN_PATH}/$1"
}

# Create link for lua module
make_lib_link() {
	make_link "${PROJECT_ROOT}/modules/$1/lua" "${NODE_ROOTPATH}/lib/$1"
}

# Create links for all lua modules
make_lua_lib_links() {
    MODULES=`ls ${PROJECT_ROOT}/modules`
    for name in ${MODULES} 
    do
        # echo $name
        make_lib_link $name
    done
}

sdk_install() {
    echo "Install the files '$PROJECT_ROOT' into '${NODE_ROOTPATH}'"

    mkdir -p ${LOCAL_BIN_PATH}
    mkdir -p ${NODE_ROOTPATH}/lib
    mkdir -p ${NODE_ROOTPATH}/conf

    make_link "${PROJECT_ROOT}/app" "${NODE_ROOTPATH}/app"
    make_link "${PROJECT_ROOT}/build/${BOARD_TYPE}" "${NODE_ROOTPATH}/bin"
    make_link "${PROJECT_ROOT}/core/lua" "${NODE_ROOTPATH}/lua"

    make_lua_lib_links

    # bin
    make_link "${NODE_ROOTPATH}/bin/lnode" "${LOCAL_BIN_PATH}/lnode"
    make_module_bin_link "lpm"

    chmod 777 ${LOCAL_BIN_PATH}/lnode
    chmod 777 ${LOCAL_BIN_PATH}/lpm

    echo "Finish!"
    echo ""
}

# 清除安装的文件或链接
sdk_clean() {
    rm -rf ${NODE_ROOTPATH}/app
    rm -rf ${NODE_ROOTPATH}/bin
    rm -rf ${NODE_ROOTPATH}/lib
    rm -rf ${NODE_ROOTPATH}/lua

    rm -rf ${LOCAL_BIN_PATH}/lnode
    rm -rf ${LOCAL_BIN_PATH}/lpm

    rm -rf /usr/local/bin/lnode
    rm -rf /usr/local/bin/lpm
    rm -rf /usr/bin/lnode
    rm -rf /usr/bin/lpm
}

if [ -z $1 ]
then
    echo "Usage: '$0 <board type>'' or '$0 clean'"
    echo ""
    echo "ex:"
    echo "$ $0 hi3516"
    echo ""

elif [ $1 = "clean" ]
then
    echo "Clean ($NODE_ROOTPATH) ..."
    sdk_clean
    echo "Done."

else
    BOARD_TYPE=$1

    if [ $BOARD_TYPE = "local" ]
    then
        LOCAL_BIN_PATH="/usr/local/bin"
    fi

    sdk_clean
    sdk_install $1
fi
