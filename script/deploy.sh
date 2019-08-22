#!/bin/sh

PWD=`pwd`
PROJECT_ROOT="`dirname ${PWD}`"
BOARD_TYPE="hi3516"
LOCAL_BIN_PATH="/usr/local/bin"
BUILD_PATH="${PROJECT_ROOT}/build/${BOARD_TYPE}"
NODE_ROOTPATH="/usr/local/lnode"

MODULES=`ls ${PROJECT_ROOT}/modules`

make_link() {
    # echo $1 $2
	rm -rf $2

    if [ -e $1 ]
    then 
        echo make link: $2; 
        cp -rf $1 $2; 
    fi
}

make_module_bin_link() {
  
	make_link "${NODE_ROOTPATH}/app/$1/bin/$1" "${LOCAL_BIN_PATH}/$1"
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
    cp "${BUILD_PATH}/lmodbus.so" "${NODE_ROOTPATH}/lib"
}

make_install() {
    echo "Install the files '$BUILD_PATH' into ${NODE_ROOTPATH}"


    mkdir -p ${LOCAL_BIN_PATH}

    rm -rf ${NODE_ROOTPATH}/app
    rm -rf ${NODE_ROOTPATH}/bin
    rm -rf ${NODE_ROOTPATH}/lib
    rm -rf ${NODE_ROOTPATH}/lua




    



    

    mkdir -p ${NODE_ROOTPATH}/lib
    mkdir -p ${NODE_ROOTPATH}/conf
    mkdir -p ${NODE_ROOTPATH}/bin
    mkdir -p ${NODE_ROOTPATH}/app/gateway
    mkdir -p ${NODE_ROOTPATH}/app/wotc
    mkdir -p ${NODE_ROOTPATH}/app/lci
    mkdir -p ${NODE_ROOTPATH}/app/lpm

    make_link "${BUILD_PATH}/lnode" "${NODE_ROOTPATH}/bin/lnode"
    make_link "${PROJECT_ROOT}/app/lpm/bin/lpm" "${NODE_ROOTPATH}/bin/lpm"

    make_link "${PROJECT_ROOT}/core/lua" "${NODE_ROOTPATH}/lua"
    make_link "${PROJECT_ROOT}/app/gateway" "${NODE_ROOTPATH}/app/gateway"
    make_link "${PROJECT_ROOT}/app/lci" "${NODE_ROOTPATH}/app/lci"
    make_link "${PROJECT_ROOT}/app/lpm" "${NODE_ROOTPATH}/app/lpm"
    make_link "${PROJECT_ROOT}/app/wotc" "${NODE_ROOTPATH}/app/wotc"

    make_link "${PROJECT_ROOT}/app/lci/data/S88lnode" "/etc/init.d/S88lnode"

    cp "${BUILD_PATH}/lmodbus.so" "${NODE_ROOTPATH}/lib"


    # make_link "${BUILD_PATH}" "${NODE_ROOTPATH}/bin"
    make_link "${NODE_ROOTPATH}/bin/lnode" "${LOCAL_BIN_PATH}/lnode"
    make_link "${NODE_ROOTPATH}/bin/lua" "${LOCAL_BIN_PATH}/lua"

    make_module_bin_link "lpm"
    # make_module_bin_link "lbuild"

    make_lua_lib_links

    # chmod 777 ${LOCAL_BIN_PATH}/l*

    rm /usr/bin/lnode
    rm /usr/bin/lpm

    ln -s /usr/local/bin/lnode /usr/bin/lnode
    ln -s /usr/local/bin/lpm /usr/bin/lpm  

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
