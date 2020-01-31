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
	@echo "-- Load: BOARD_TYPE=${board}";
	@echo "${board}" > build/target;
	@cmake -H. -Bbuild/${board} -DBOARD_TYPE=${board}
	@echo ""
	@echo "Next step, you can type 'make build' to build the SDK";
endef

define make_load_help
	@echo "Usage: make load board=<BOARD_TYPE>"
	@echo "Available BOARD_TYPE:"
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

.PHONY: all build config clean load help install local remove sdk

## ------------------------------------------------------------

help:
	@echo ""
	@echo "Welcome to Node.lua build system. Some useful make targets:"
	@echo ""

	@echo '  load    `board=<name>`, Load make configuration'
	@echo '  build   Build `lnode` and other native modules'

	@echo ""

	@echo '  sdk     Build the SDK package'
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

test:
	cd core/tests; lnode ./test-all.lua

clean:
	rm -rf build

## ------------------------------------------------------------
## Board

local:
	@make load board=$@
	@make build

hi3516:
	@make load board=$@
	@make build

dt02:
	@make load board=$@
	@make build

## ------------------------------------------------------------
## SDK

sdk:
	lpm lbuild sdk

version:
	lpm lbuild version

install:
	$(call sdk_install)

remove:
	$(call sdk_remove)


