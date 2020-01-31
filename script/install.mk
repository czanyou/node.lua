# 用于在工作主机上安装运行环境
# 请在在项目根目录下执行 'make install' 来调用这个脚本
# It is used to install the run environment on the work host
# Please invoke this script by executing 'make install' in the project root directory

LOCAL_BIN_PATH  ?= /usr/local/bin
BUILD_PATH 		?= ${PWD}/build/${BOARD_TYPE}
NODE_ROOTPATH   ?= /usr/local/lnode

# Create links for files
define make_link
	rm -rf $2; if [ -e $1 ]; then echo make link: $2; ln -s $1 $2; fi;
endef

# Create links for lua files in the modules
define make_module_lua_links
	$(foreach name, ${shell ls modules}, $(call make_link, ${PWD}/modules/${name}/lua, ${NODE_ROOTPATH}/lib/${name}))
endef

define sdk_install
	@echo 'Install the files into ${NODE_ROOTPATH}'

	# Delete the installed files
	@rm -rf ${LOCAL_BIN_PATH}/lbuild
	@rm -rf ${LOCAL_BIN_PATH}/lci
	@rm -rf ${LOCAL_BIN_PATH}/lnode
	@rm -rf ${LOCAL_BIN_PATH}/lpm
	@rm -rf ${LOCAL_BIN_PATH}/lua

	# Delete the installed directory
	@rm -rf ${NODE_ROOTPATH}/app
	@rm -rf ${NODE_ROOTPATH}/bin
	@rm -rf ${NODE_ROOTPATH}/lib
	@rm -rf ${NODE_ROOTPATH}/lua

	# Create the desired directory
	@mkdir -p ${LOCAL_BIN_PATH}
	@mkdir -p ${NODE_ROOTPATH}/lib
	@mkdir -p ${NODE_ROOTPATH}/conf

	# Create links to project directory
	@$(call make_link, ${PWD}/core/lua, ${NODE_ROOTPATH}/lua)
	@$(call make_link, ${PWD}/app,      ${NODE_ROOTPATH}/app)
	@$(call make_link, ${BUILD_PATH},   ${NODE_ROOTPATH}/bin)
	@$(call make_module_lua_links)

	# Create links to the lnode executable file
	@$(call make_link, ${NODE_ROOTPATH}/bin/lnode, ${LOCAL_BIN_PATH}/lbuild)
	@$(call make_link, ${NODE_ROOTPATH}/bin/lnode, ${LOCAL_BIN_PATH}/lci)
	@$(call make_link, ${NODE_ROOTPATH}/bin/lnode, ${LOCAL_BIN_PATH}/lnode)
	@$(call make_link, ${NODE_ROOTPATH}/bin/lnode, ${LOCAL_BIN_PATH}/lpm)
	@$(call make_link, ${NODE_ROOTPATH}/bin/lua,   ${LOCAL_BIN_PATH}/lua)

	# Add execute permission
	@chmod 777 ${LOCAL_BIN_PATH}/l*

	@echo "Install finish!"
	@echo ""

endef

define sdk_remove
	# Delete the installed directory
	rm -rf ${NODE_ROOTPATH}/app
	rm -rf ${NODE_ROOTPATH}/bin
	rm -rf ${NODE_ROOTPATH}/conf
	rm -rf ${NODE_ROOTPATH}/lib
	rm -rf ${NODE_ROOTPATH}/lua

	# Delete the installed files
	rm -rf ${LOCAL_BIN_PATH}/lbuild
	rm -rf ${LOCAL_BIN_PATH}/lci
	rm -rf ${LOCAL_BIN_PATH}/lnode
	rm -rf ${LOCAL_BIN_PATH}/lpm
	rm -rf ${LOCAL_BIN_PATH}/lua

	@echo "Remove finish!"
	@echo ""

endef

