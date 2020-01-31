#!/bin/sh

# 用于在开发板上安装运行环境
# 用法:
#
# 在 hi3516 开发板上安装运行环境:
# - 先通过 nfs 挂载开发主机项目目录
# $ mount -t nfs -o nolock workhost:/path/to/node.lua /mnt/nfs
# - 然后跳转项目的 script 目录下执行这个脚本
# $ cd /mnt/nfs/path/to/node.lua/script/
# $ ./install.sh hi3516
#
# 删除安装的文件或者链接
# $ ./install.sh clean
#

PROJECT_CWD=`pwd`
PROJECT_ROOT="`dirname ${PROJECT_CWD}`"

BOARD_TYPE="hi3516"
LOCAL_BIN_PATH="/usr/bin"
NODE_ROOTPATH="/usr/local/lnode"

# Create link file
make_link() {
    # echo $1 $2
	rm -rf $2

    if [ -e $1 ]
    then 
        echo make link: $2; 
        ln -s $1 $2; 
    fi
}

# Create link for directory in modules
make_lib_link() {
	make_link "${PROJECT_ROOT}/modules/$1/lua" "${NODE_ROOTPATH}/lib/$1"
}

# Create links for all directory in modules
make_all_lib_links() {
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
    mkdir -p ${NODE_ROOTPATH}/conf
    mkdir -p ${NODE_ROOTPATH}/lib

    # Create links to project directory
    make_link "${PROJECT_ROOT}/app" "${NODE_ROOTPATH}/app"
    make_link "${PROJECT_ROOT}/build/${BOARD_TYPE}" "${NODE_ROOTPATH}/bin"
    make_link "${PROJECT_ROOT}/core/lua" "${NODE_ROOTPATH}/lua"
    make_all_lib_links

    # Create links to the lnode executable file
    make_link "${NODE_ROOTPATH}/bin/lnode" "${LOCAL_BIN_PATH}/lci"
    make_link "${NODE_ROOTPATH}/bin/lnode" "${LOCAL_BIN_PATH}/lnode"
    make_link "${NODE_ROOTPATH}/bin/lnode" "${LOCAL_BIN_PATH}/lpm"

    # Add execute permission
    chmod 777 ${LOCAL_BIN_PATH}/lnode
    chmod 777 ${LOCAL_BIN_PATH}/lpm
    chmod 777 ${LOCAL_BIN_PATH}/lci

    echo "Finish!"
    echo ""
}

# 清除安装的文件或链接
sdk_clean() {
    rm -rf ${NODE_ROOTPATH}/app
    rm -rf ${NODE_ROOTPATH}/bin
    rm -rf ${NODE_ROOTPATH}/lib
    rm -rf ${NODE_ROOTPATH}/lua

    rm -rf ${LOCAL_BIN_PATH}/lci
    rm -rf ${LOCAL_BIN_PATH}/lnode
    rm -rf ${LOCAL_BIN_PATH}/lpm

    rm -rf /usr/local/bin/lci
    rm -rf /usr/local/bin/lnode
    rm -rf /usr/local/bin/lpm
}

if [ -z $1 ] # Display usage information
then
    echo "Usage: '$0 <board type>'' or '$0 clean'"
    echo ""
    echo "ex:"
    echo "$ $0 hi3516"
    echo ""

elif [ $1 = "clean" ] # clean installed files
then
    echo "Clean ($NODE_ROOTPATH) ..."
    sdk_clean
    echo "Done."

else # install
    BOARD_TYPE=$1

    if [ $BOARD_TYPE = "local" ]
    then
        LOCAL_BIN_PATH="/usr/local/bin"
    fi

    sdk_clean
    sdk_install $1
fi
