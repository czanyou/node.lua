PWD 			= $(shell pwd)
BOARD_TYPE      ?= $(shell if [ -f build/board ]; then cat build/board; else echo 'local'; fi)
BOARDS 			= $(shell ls config)
BOARD_CHANGED   = 

ifneq (${board},)
	BOARD_TYPE = ${board}
	BOARD_CHANGED = 1
endif

## ------------------------------------------------------------

# build lnode
define make_build
	@mkdir -p build

	@echo ""
	@echo "= Building: build/${1}"
	@cmake --build build/${1} --config Release

	@echo "--"
	@echo "-- Executable building done: 'build/${1}/lnode'"
endef

# save current board name
define make_config_save
	@mkdir -p build
	@echo "= Save board type: 'build/board': ${1}";
	@echo "${1}" > build/board;
endef

# load build config
define make_config_board
	@mkdir -p build
	$(call make_config_save,${1})

	@echo ""
	@echo "= Configuring: build/${1}"
	@cmake -H. -Bbuild/${1} -DBOARD_TYPE=${1}
endef

# show board names
define make_show_boards
	@echo "Available board types:"
	@echo ""
	@ $(foreach name, ${BOARDS}, echo " -" $(basename ${name});)
	@echo ""

	@echo "Usage: make config board=<BOARD_TYPE>"
endef

# config cmake script
define make_config
	$(if ${board}, $(call make_config_board,${board}), $(call make_show_boards))
endef

define make_board
	@echo 'make board:' ${1}
	$(call make_config_board,${1})
	@make build board=${1} --no-print-directory
endef

# make core, build and sdk
define make_sdk
	@echo 'make board:' ${1}
	$(call make_config_board,${1})
	
	@echo ''
	@echo '= Build lua packages:'
	@lpm lbuild core

	$(call make_build,${1})
	
	@make sdk board=${1} --no-print-directory
endef

## ------------------------------------------------------------

include script/install.mk

## ------------------------------------------------------------

.PHONY: all board build config core clean load help install local remove sdk test

## ------------------------------------------------------------

help:
	@echo ""
	@echo "Welcome to Node.lua build system. Some useful make targets:"
	@echo ""

	@echo '  boards  - Shows the list of supported `BOARD`'
	@echo '  [BOARD] - Build for board [BOARD]'

	@echo ""
	@echo '  save board=<name> - Saves the board under `build/board`, for use in subsequent runs of make'
	@echo '  config  - Configuring `lnode` build files'
	@echo '  build   - Build `lnode` and other executable files'
	@echo '  test    - Run all unit test cases'
	@echo '  clean   - Removes all build output files'

	@echo ""

	@echo '  sdk     - Build the SDK package for current `BOARD`'
	@echo '  version - Update build version number from SVN'

	@echo ""
	@echo "  install - Install the native Node.Lua runtime to current system"
	@echo "  remove  - Remove all installed Node.Lua runtime files"
	@echo ""

	@echo "You can type 'make build' to build the SDK and then type 'make install' to install the Node.Lua runtime."
	@echo ""

## ------------------------------------------------------------
## make

all: help

build:
	$(call make_build,${BOARD_TYPE})

clean:
	rm -rf build

save:
	$(if ${board}, $(call make_config_save,${board}))

config:
	$(call make_config,${BOARD_TYPE})

test:
	cd core/tests; lnode ./test-all.lua

boards:
	$(call make_show_boards)

board:
	$(if ${board}, $(call make_sdk,${board}))

## ------------------------------------------------------------
## Boards

local:
	$(call make_board,$@)

	@echo ""
	@echo "-- Executable: `build/$@/lnode -v`"

dt02:
	@make board board=$@ --no-print-directory

dt02b:
	@make board board=$@ --no-print-directory

linux:
	@make board board=$@ --no-print-directory

darwin:
	@make board board=$@ --no-print-directory

## ------------------------------------------------------------
## SDK & Runtime

core:
	@echo ''
	@echo '= Build lua packages:'
	@lpm lbuild core

sdk:
	@echo ''
	@echo '= Build SDK package:'
	@lpm lbuild sdk

version:
	@lpm lbuild version

install:
	$(call sdk_install)

remove:
	$(call sdk_remove)
