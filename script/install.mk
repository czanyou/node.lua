LOCAL_BIN_PATH  ?= /usr/local/bin
BUILD_PATH 		?= ${PWD}/build/${BOARD_TYPE}
NODE_ROOTPATH   ?= /usr/local/lnode

MODULES = $(shell ls modules)
BIN_LIBS = $(shell cd build/${BOARD_TYPE}/; ls *.so)

define make_copy
	@if [ -f $1 ]; then echo "cp $1 $2"; cp $1 $2; fi;
endef

# Create links for files
define make_link
	@rm -rf $2; if [ -e $1 ]; then echo make link: $2; ln -s $1 $2; fi;
endef

# Create links for executable files of the module
define make_module_bin_link
	$(call make_link,${PWD}/app/$1/bin/$1,${LOCAL_BIN_PATH}/$1)
endef

# Create link for bin module
define make_bin_link
	$(call make_link,${BUILD_PATH}/$1.so,${NODE_ROOTPATH}/bin/$1.so)
endef

# Create link for lua module
define make_lib_link
	$(call make_link,${PWD}/modules/$1/lua,${NODE_ROOTPATH}/lib/$1)
endef

# Create links for all bin modules
define make_bin_lib_links
	@ $(foreach name, ${BIN_LIBS}, make -s make_bin_link name=$(basename ${name});)
endef

# Create links for all lua modules
define make_lua_lib_links
	@ $(foreach name, ${MODULES}, make -s make_lib_link name=${name};)
endef

define sdk_install
	@echo 'Install the files into ${NODE_ROOTPATH}'

	@mkdir -p ${LOCAL_BIN_PATH}

	@rm -rf ${NODE_ROOTPATH}/app
	@rm -rf ${NODE_ROOTPATH}/lib
	@rm -rf ${NODE_ROOTPATH}/lua

	@mkdir -p ${NODE_ROOTPATH}/bin
	@mkdir -p ${NODE_ROOTPATH}/lib
	@mkdir -p ${NODE_ROOTPATH}/conf

	$(call make_link,${PWD}/core/lua,${NODE_ROOTPATH}/lua)
	$(call make_link,${PWD}/app,${NODE_ROOTPATH}/app)

	$(call make_link,${PWD}/build/local/lnode,${LOCAL_BIN_PATH}/lnode)

	$(call make_module_bin_link,lpm)
	$(call make_module_bin_link,lbuild)
	$(call make_module_bin_link,lhost)
	$(call make_module_bin_link,lhttpd)

	$(call make_lua_lib_links)
	$(call make_bin_lib_links)

	@chmod 777 ${LOCAL_BIN_PATH}/l*

	@echo "Install finish!"
	@echo ""

endef

define sdk_remove
	rm -rf ${NODE_ROOTPATH}/app
	rm -rf ${NODE_ROOTPATH}/bin
	rm -rf ${NODE_ROOTPATH}/lib
	rm -rf ${NODE_ROOTPATH}/lua
	rm -rf ${NODE_ROOTPATH}/conf

	rm -rf ${LOCAL_BIN_PATH}/lnode
	rm -rf ${LOCAL_BIN_PATH}/lpm
	rm -rf ${LOCAL_BIN_PATH}/lbuild
	rm -rf ${LOCAL_BIN_PATH}/lhttpd

	@echo "Remove finish!"
	@echo ""

endef

