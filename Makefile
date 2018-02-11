PWD 			= $(shell pwd)
BOARD_TYPE      ?= $(shell if [ -f build/target ]; then cat build/target; else echo 'local'; fi)
t               ?= local

## ------------------------------------------------------------

define sdk_build
	@mkdir -p build

	@echo "Build: ${BOARD_TYPE}"

	cmake -H. -Bbuild/${BOARD_TYPE} -DBOARD_TYPE=${BOARD_TYPE}
	cmake --build build/${BOARD_TYPE} --config Release

	@echo "Build Done."

endef

## ------------------------------------------------------------

include install.mk

## ------------------------------------------------------------

.PHONY: all build clean deconfig help install local remove sdk

## ------------------------------------------------------------

help:
	@echo ""
	@echo "Welcome to Node.lua build system. Some useful make targets:"
	@echo ""

	@echo '  build       Build lnode and other modules'
	@echo '  config      Configure Node.lua project'
	@echo '  deconfig    Set defaults for all new configuration options'

	@echo ""

	@echo '  clean       Clean all build output'
	@echo '  sdk         Build the SDK package'
	@echo '  patch       Build the PATCH package'

	@echo ""
	@echo "  install     Install the Lua runtime files of the SDK"
	@echo "  remove      Remove all installed Lua runtime files"
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
	ccmake -H. -Bbuild/${BOARD_TYPE}

deconfig:
	@mkdir -p build
	@echo "Usage: make config t=<BOARD_TYPE>"
	@echo "${t}" > build/target
	@echo "BOARD_TYPE: ${t}"

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

install:
	$(call sdk_install)

remove:
	$(call sdk_remove)

