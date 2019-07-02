#!/bin/sh

PWD=`pwd`
PROJECT_ROOT="`dirname ${PWD}`"
BOARD_TYPE="local"
LOCAL_BIN_PATH="/usr/local/bin"
BUILD_PATH="${PROJECT_ROOT}/build/${BOARD_TYPE}"
NODE_ROOTPATH="/usr/local/lnode"

MODULES=`ls ${PROJECT_ROOT}/modules`
BIN_LIBS=`cd ../build/${BOARD_TYPE}/; ls *.so`

# echo $MODULES, $BIN_LIBS

make_link() {
    # echo $1 $2
	rm -rf $2

    if [ -e $1 ]
    then 
        echo make link: $2; 
        ln -s $1 $2; 
    fi
}

make_module_bin_link() {
	make_link "${PROJECT_ROOT}/app/$1/bin/$1" "${LOCAL_BIN_PATH}/$1"
}

# Create link for bin module
make_bin_link() {
	make_link "${BUILD_PATH}/$1" "${NODE_ROOTPATH}/bin/$1"
}

# Create link for lua module
make_lib_link() {
	make_link "${PROJECT_ROOT}/modules/$1/lua" "${NODE_ROOTPATH}/lib/$1"
}

# Create links for all bin modules
make_bin_lib_links() {
    for name in ${BIN_LIBS} 
    do
        # echo $name
        make_bin_link $name
    done
}

# Create links for all lua modules
make_lua_lib_links() {
    for name in ${MODULES} 
    do
        # echo $name
        make_lib_link $name
    done
}

make_install() {
    echo "Install the files '$BUILD_PATH' into ${NODE_ROOTPATH}"

    mkdir -p ${LOCAL_BIN_PATH}

    rm -rf ${NODE_ROOTPATH}/app
    rm -rf ${NODE_ROOTPATH}/bin
    rm -rf ${NODE_ROOTPATH}/lib
    rm -rf ${NODE_ROOTPATH}/lua

    mkdir -p ${NODE_ROOTPATH}/bin
    mkdir -p ${NODE_ROOTPATH}/lib
    mkdir -p ${NODE_ROOTPATH}/conf

    make_link "${PROJECT_ROOT}/core/lua" "${NODE_ROOTPATH}/lua"
    make_link "${PROJECT_ROOT}/app" "${NODE_ROOTPATH}/app"

    make_link "${PROJECT_ROOT}/build/local/lnode" "${LOCAL_BIN_PATH}/lnode"
    make_link "${PROJECT_ROOT}/build/local/lua" "${LOCAL_BIN_PATH}/lua"

    make_module_bin_link "lpm"
    make_module_bin_link "lbuild"

    make_lua_lib_links
    make_bin_lib_links

    chmod 777 ${LOCAL_BIN_PATH}/l*

    echo "Install finish!"
    echo ""
}

make_uninstall() {
    echo "uninstall..."

    rm -rf ${NODE_ROOTPATH}/bin
    rm -rf ${NODE_ROOTPATH}/app
    rm -rf ${NODE_ROOTPATH}/lib
    rm -rf ${NODE_ROOTPATH}/lua

    echo ""
}

if [ -z $1 ]
then
    make_install

elif [ $1 = "uninstall" ]
then
    make_uninstall  
fi
