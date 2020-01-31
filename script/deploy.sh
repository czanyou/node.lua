#!/bin/sh

PWD=`pwd`
PROJECT_ROOT="`dirname ${PWD}`"
BOARD_TYPE="hi3516"
BUILD_PATH="${PROJECT_ROOT}/build/${BOARD_TYPE}"
NODE_ROOTPATH="/usr/local/lnode"

MODULES=`ls ${PROJECT_ROOT}/modules`

make_link() {

	rm -rf $2

    if [ -e $1 ]
    then 
        echo make link: $2; 
        cp -rf $1 $2; 
    fi
}

# Create link for lua module
make_lib_link() {
    mkdir -p ${NODE_ROOTPATH}/lib/$1
	make_link "${PROJECT_ROOT}/modules/$1/lua" "${NODE_ROOTPATH}/lib/$1"
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

    rm -rf ${NODE_ROOTPATH}/app
    rm -rf ${NODE_ROOTPATH}/bin
    rm -rf ${NODE_ROOTPATH}/lib
    rm -rf ${NODE_ROOTPATH}/lua
    rm  /usr/bin/lpm
    rm  /usr/bin/lnode
    rm  /usr/sbin/lpm
    rm  /usr/sbin/lnode
    rm -rf /usr/share/udhcpc

    mkdir -p ${NODE_ROOTPATH}/lib
    mkdir -p ${NODE_ROOTPATH}/conf
    mkdir -p ${NODE_ROOTPATH}/app/gateway
    mkdir -p ${NODE_ROOTPATH}/app/wotc
    mkdir -p ${NODE_ROOTPATH}/app/lci
    mkdir -p ${NODE_ROOTPATH}/app/lpm
    mkdir -p ${NODE_ROOTPATH}/bin
    mkdir -p /usr/share/udhcpc

    cp "${BUILD_PATH}/lnode" "${NODE_ROOTPATH}/bin/lnode"

    make_link "${PROJECT_ROOT}/core/lua" "${NODE_ROOTPATH}/lua"
    make_link "${PROJECT_ROOT}/app/gateway" "${NODE_ROOTPATH}/app/gateway"
    make_link "${PROJECT_ROOT}/app/lci" "${NODE_ROOTPATH}/app/lci"
    make_link "${PROJECT_ROOT}/app/lpm" "${NODE_ROOTPATH}/app/lpm"
    make_link "${PROJECT_ROOT}/app/wotc" "${NODE_ROOTPATH}/app/wotc"

    make_link "${PROJECT_ROOT}/app/lci/data/network.default.conf" "/usr/local/lnode/conf/network.default.conf"
    make_link "${PROJECT_ROOT}/app/lci/data/S88lnode" "/etc/init.d/S88lnode"
    make_link "${PROJECT_ROOT}/app/lci/data/default.script" "/usr/share/udhcpc/default.script"

    cp "${BUILD_PATH}/lmodbus.so" "${NODE_ROOTPATH}/lib"
    cp "${BUILD_PATH}/lmbedtls.so" "${NODE_ROOTPATH}/lib"

    cp "/usr/local/lnode/app/lpm/bin/lpm"      "${NODE_ROOTPATH}/bin/lpm"

    make_lua_lib_links

    ln -s /usr/local/lnode/bin/lnode /usr/bin/lnode
    ln -s /usr/local/lnode/bin/lpm /usr/bin/lpm  

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
