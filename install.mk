LOCAL_BIN_PATH  ?= /usr/local/bin
NODE_BUILD 		?= ${PWD}/build/local
NODE_ROOTPATH   ?= /usr/local/lnode

define make_copy
	@if [ -f $1 ]; then echo "cp $1 $2"; cp $1 $2; fi;
endef

define make_link
	@sudo rm -rf $2
	@if [ -e $1 ]; then echo make link: $2; sudo ln -s $1 $2; fi;
endef

define make_bin_link
	$(call make_link,${NODE_BUILD}/$1.so,${NODE_ROOTPATH}/bin/$1.so)
endef

define make_lib_link
	$(call make_link,${PWD}/modules/$1/lua,${NODE_ROOTPATH}/lib/$1)
endef

define sdk_install
	@echo 'Install the files into ${NODE_ROOTPATH}'

	@sudo mkdir -p ${LOCAL_BIN_PATH}

	sudo rm -rf ${NODE_ROOTPATH}/app
	sudo rm -rf ${NODE_ROOTPATH}/lib
	sudo rm -rf ${NODE_ROOTPATH}/lua

	sudo mkdir -p ${NODE_ROOTPATH}/bin
	sudo mkdir -p ${NODE_ROOTPATH}/lib

	@echo "make link: ${NODE_ROOTPATH}/lua"
	@sudo ln -s ${PWD}/node.lua/lua ${NODE_ROOTPATH}/lua

	$(call make_link,${PWD}/app,${NODE_ROOTPATH}/app)
	$(call make_link,${PWD}/build/local/lnode,${LOCAL_BIN_PATH}/lnode)
	$(call make_link,${PWD}/node.lua/bin/lpm,${LOCAL_BIN_PATH}/lpm)

	$(call make_lib_link,bluetooth)
	$(call make_lib_link,express)
	$(call make_lib_link,mqtt)
	$(call make_lib_link,sdl)
	$(call make_lib_link,sqlite3)
	$(call make_lib_link,ssdp)

	$(call make_bin_link,lsqlite)
	$(call make_bin_link,lmbedtls)
	$(call make_bin_link,lbluetooth)
	$(call make_bin_link,lmedia)
	$(call make_bin_link,lts)
	$(call make_bin_link,lsdl)	

	@sudo chmod 777 ${LOCAL_BIN_PATH}/lnode
	@sudo chmod 777 ${LOCAL_BIN_PATH}/lpm

	@echo "Install finish!"
	@echo ""

endef

define sdk_remove
	sudo rm -rf ${NODE_ROOTPATH}/app
	sudo rm -rf ${NODE_ROOTPATH}/bin
	sudo rm -rf ${NODE_ROOTPATH}/lib
	sudo rm -rf ${NODE_ROOTPATH}/lua
	sudo rm -rf ${NODE_ROOTPATH}/conf

	sudo rm -rf ${LOCAL_BIN_PATH}/lnode
	sudo rm -rf ${LOCAL_BIN_PATH}/lpm

	@echo "Remove finish!"
	@echo ""

endef

