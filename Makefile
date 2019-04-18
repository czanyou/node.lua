PWD 			= $(shell pwd)
BOARD_TYPE      ?= $(shell if [ -f build/target ]; then cat build/target; else echo 'local'; fi)
BOARDS 			= $(shell ls config)

## ------------------------------------------------------------

define sdk_build
	@mkdir -p build

	@echo "Build: ${BOARD_TYPE}"

	cmake -H. -Bbuild/${BOARD_TYPE} -DBOARD_TYPE=${BOARD_TYPE}
	cmake --build build/${BOARD_TYPE} --config Release

	@echo "Build Done."

endef

define make_config
	@echo "BOARD_TYPE: ${board}";
	@echo "${board}" > build/target;
	@make config
endef

define load_config_help
	@echo "Usage: make load board=<BOARD_TYPE>"
	@echo "Available boards:"
	@echo ""
	@ $(foreach name, ${BOARDS}, echo " -" $(basename ${name});)
	@echo ""
endef

define load_config
	@mkdir -p build

	# $(shell if [ -f $(FILE) ]; then echo "exist"; else echo "notexist"; fi;)
	$(if ${board}, $(call make_config), $(call load_config_help))
endef

## ------------------------------------------------------------

include script/install.mk

## ------------------------------------------------------------

.PHONY: all build config clean load help install local remove sdk patch tar deb

## ------------------------------------------------------------

help:
	@echo ""
	@echo "Welcome to Node.lua build system. Some useful make targets:"
	@echo ""

	@echo '  build   Build lnode and other modules'
	@echo '  config  Configure Node.lua project'
	@echo '  load    `board=<name>`, Load defaults configuration'

	@echo ""

	@echo '  clean   Clean all build output files'
	@echo '  sdk     Build the SDK package'
	@echo '  patch   Build the PATCH package'

	@echo ""
	@echo "  install Install the Lua runtime files of the SDK"
	@echo "  remove  Remove all installed Lua runtime files"
	@echo ""

	@echo "You can type 'make build' to build the SDK and then type 'make install' to install the Lua runtime."
	@echo ""

## ------------------------------------------------------------

all: help

build:
	$(call sdk_build)

clean:
	rm -rf build

config:
	cmake -H. -Bbuild/${BOARD_TYPE} -DBOARD_TYPE=${BOARD_TYPE}

load:
	$(call load_config)

local:
	@mkdir -p build; echo "$@" > build/target; make config;

## ------------------------------------------------------------
## SDK

install:
	$(call sdk_install)

remove:
	$(call sdk_remove)

## ------------------------------------------------------------
## shortcuts

sdk:
	lbuild sdk 

patch:
	lbuild patch

deb:
	lbuild deb

tar:
	lbuild tar

make_lib_link:
	$(call make_lib_link,${name})

make_bin_link:
	$(call make_bin_link,${name})

	