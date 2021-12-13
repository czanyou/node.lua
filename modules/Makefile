

.PHONY: all help test

all: help

help:
	@echo ""
	@echo "Some useful make targets:"
	@echo ""
	@echo '  test    Run all unit test cases'

test:
	lnode app/tests/run.lua
	lnode devices/tests/run.lua
#	lnode express/tests/run.lua
	lnode mbedtls/tests/run.lua
	lnode mqtt/tests/run.lua
	lnode rtmp/tests/run.lua
	lnode rtsp/tests/run.lua
	lnode sqlite/tests/run.lua
	lnode ssdp/tests/run.lua
	lnode wot/tests/run.lua
