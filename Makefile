PWD 			= $(shell pwd)
NODE_ROOTPATH   ?= /usr/local/lnode
BOARD_TYPE      ?= $(shell if [ -f build/target ]; then cat build/target; else echo 'local'; fi)
LOCAL_BIN_PATH  ?= /usr/local/bin
NODE_BUILD 		?= ${PWD}/build/local
t               ?= local

## ------------------------------------------------------------

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

## ------------------------------------------------------------

define cmake_build
	@mkdir -p build

	@echo "Build: ${BOARD_TYPE}"

	cmake -H. -Bbuild/${BOARD_TYPE} -DBOARD_TYPE=${BOARD_TYPE}
	cmake --build build/${BOARD_TYPE} --config Release

	@echo "Build Done."

endef

## ------------------------------------------------------------

.PHONY: all build clean deconfig help local docs install sdk uninstall upload latest src

## ------------------------------------------------------------

all: help

clean:
	rm -rf build

deconfig:
	@mkdir -p build
	@echo "Usage: make config t=<BOARD_TYPE>"
	@echo "${t}" > build/target
	@echo "BOARD_TYPE: ${t}"

config:
	ccmake -H. -Bbuild/${BOARD_TYPE}

help:
	@echo ""
	@echo "Welcome to Node.lua build system. Some useful make targets:"
	@echo ""

	@echo '  build       Build lnode and other modules'
	@echo '  config      Configure Node.lua project'
	@echo '  deconfig    Set defaults for all new configuration options'

	@echo ""

	@echo '  clean       Clean all build output'
	@echo '  docs        Build the documentation package'
	@echo '  sdk         Build the SDK package'
	@echo '  patch       Build the PATCH package'
	@echo '  upload      Publish the PATCH package to the server'
	@echo '  latest      Publish the SDK package to the server'

	@echo ""
	@echo "  install     Install the SDK to current system"
	@echo "  uninstall   Remove all installed files"
	@echo ""

	@echo "You can type 'make build' to build the SDK and then type 'make install' to install it to '${NODE_ROOTPATH}' as usual."
	@echo ""

## ------------------------------------------------------------
## targets

build: 
	$(call cmake_build)

hi3518:
	@mkdir -p build; echo "$@" > build/target; make build

hi3516a:
	@mkdir -p build; echo "$@" > build/target; make build

local:
	@mkdir -p build; echo "$@" > build/target; make build

## ------------------------------------------------------------
## SDK

sdk:
	lpm build sdk

patch:
	lpm build patch

deb:
	lpm build deb

tar:
	lpm build tar

upload: patch
	lpm build upload

latest: sdk
	lpm build upload latest

install:
	@echo 'Install the files into ${NODE_ROOTPATH}'

	@sudo mkdir -p ${LOCAL_BIN_PATH}

	sudo mkdir -p ${NODE_ROOTPATH}/bin
	sudo mkdir -p ${NODE_ROOTPATH}/conf	

	sudo rm -rf ${NODE_ROOTPATH}/app
	sudo rm -rf ${NODE_ROOTPATH}/lib
	sudo rm -rf ${NODE_ROOTPATH}/lua

	@sudo chmod 777 ${NODE_ROOTPATH}/conf

	@echo "make link: ${NODE_ROOTPATH}/lua"
	@sudo ln -s ${PWD}/node.lua/lua ${NODE_ROOTPATH}/lua

	$(call make_link,${PWD}/app,${NODE_ROOTPATH}/app)
	$(call make_link,${PWD}/build/local/lnode,${LOCAL_BIN_PATH}/lnode)
	$(call make_link,${PWD}/modules/lua,${NODE_ROOTPATH}/lib)
	$(call make_link,${PWD}/node.lua/bin/ldb,${LOCAL_BIN_PATH}/ldb)
	$(call make_link,${PWD}/node.lua/bin/lpm,${LOCAL_BIN_PATH}/lpm)

	$(call make_bin_link,lsqlite)
	$(call make_bin_link,lmbedtls)
	$(call make_bin_link,lbluetooth)
	$(call make_bin_link,lmedia)
	$(call make_bin_link,lts)
	$(call make_bin_link,lsdl)	

	@sudo chmod 777 ${LOCAL_BIN_PATH}/lnode
	@sudo chmod 777 ${LOCAL_BIN_PATH}/lpm
	@sudo chmod 777 ${LOCAL_BIN_PATH}/ldb

	@echo "Install finish!"
	@echo ""

uninstall:
	sudo rm -rf ${NODE_ROOTPATH}/app
	sudo rm -rf ${NODE_ROOTPATH}/bin
	sudo rm -rf ${NODE_ROOTPATH}/lib
	sudo rm -rf ${NODE_ROOTPATH}/lua

	sudo rm -rf ${LOCAL_BIN_PATH}/lnode
	sudo rm -rf ${LOCAL_BIN_PATH}/lpm

	@echo "Uninstall finish!"
	@echo ""

## ------------------------------------------------------------
## document

docs:
	rm -rf docs/api
	rm -rf docs/vision
	ln -s ../node.lua/docs docs/api
	ln -s ../vision.lua/docs docs/vision

	rm -rf build/nodelua-docs.zip
	cd docs; zip -r ../build/nodelua-docs.zip *


## ------------------------------------------------------------
## source code

source:
	mkdir -p build/src/node.lua/
	cd node.lua; cp -ru bin deps docs libs lua src tests ../build/src/node.lua/
	cd node.lua; cp -u *.md *.bat *.txt *.lua Makefile ../build/src/node.lua/

	mkdir -p build/src/vision.lua/
	cd vision.lua; cp -ru docs lua examples tests ../build/src/vision.lua/
	cd vision.lua; cp -u *.md ../build/src/vision.lua/

	mkdir -p build/src/media.lua/
	cd media.lua; cp -ru src targets tests ../build/src/media.lua/
	cd media.lua; cp -u *.md *.txt *.bat Makefile ../build/src/media.lua/

	mkdir -p build/src/docs/
	cd docs; cp -ru assets docs download lua ../build/src/docs
	cd docs; cp -u *.php *.md *.ico ../build/src/docs/

	mkdir -p build/src/app/
	cd app; cp -ru build console httpd lhost mqtt netd settings ssdp ../build/src/app/

	cp -u  Makefile *.md *.bat build/src/

	rm -rf build/nodelua-src.zip
	cd build/src; zip -r ../nodelua-src-sdk.zip *


## ------------------------------------------------------------
## SVN

ci:
	svn ci -m "from `uname -a`"

up:
	svn up

