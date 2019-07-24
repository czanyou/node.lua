PWD 			= $(shell pwd)
BOARD_TYPE      ?= $(shell if [ -f build/target ]; then cat build/target; else echo 'local'; fi)
BOARDS 			= $(shell ls config)

## ------------------------------------------------------------

define make_build
	@mkdir -p build

	@echo "Build: ${BOARD_TYPE}"

	cmake -H. -Bbuild/${BOARD_TYPE} -DBOARD_TYPE=${BOARD_TYPE}
	cmake --build build/${BOARD_TYPE} --config Release

	@echo "Build Done."
endef

define make_load_config
	@echo "BOARD_TYPE: ${board}";
	@echo "${board}" > build/target;
	@echo "Next, you can type 'make build' to build the SDK";
endef

define make_load_help
	@echo "Usage: make load board=<BOARD_TYPE>"
	@echo "Available boards:"
	@echo ""
	@ $(foreach name, ${BOARDS}, echo " -" $(basename ${name});)
	@echo ""
endef

define make_load
	@mkdir -p build

	$(if ${board}, $(call make_load_config), $(call make_load_help))
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

	@echo '  load    `board=<name>`, Load make configuration'
	@echo '  build   Build `lnode` and other native modules'

	@echo ""

	@echo '  sdk     Build the SDK package'
	@echo '  patch   Build the PATCH package'
	@echo '  clean   Clean all build output files'

	@echo ""
	@echo "  install Install the Node.Lua runtime to current system"
	@echo "  remove  Remove all installed Node.Lua runtime files"
	@echo ""

	@echo "You can type 'make build' to build the SDK and then type 'make install' to install the Node.Lua runtime."
	@echo ""

## ------------------------------------------------------------
## make

all: help

load:
	$(call make_load)

build:
	$(call make_build)

clean:
	rm -rf build

config:
	cmake -H. -Bbuild/${BOARD_TYPE} -DBOARD_TYPE=${BOARD_TYPE}

local:
	@make load board=local

## ------------------------------------------------------------
## SDK

install:
	$(call sdk_install)

remove:
	$(call sdk_remove)

## ------------------------------------------------------------
## shortcuts

sdk:
	lpm lbuild sdk

patch:
	lpm lbuild patch

deb:
	lpm lbuild deb

tar:
	lpm lbuild tar
