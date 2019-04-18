BOARD_TYPE      ?= $(shell if [ -f ../../build/target ]; then cat ../../build/target; else echo 'local'; fi)

.PHONY: all build config clean json ubox install luci lubus

all:
	make ubox
	make luci
	make lubus
	make json
	make lmosquitto
	make install

json:
	cmake -H./json-c -Bbuild/json-c -DBUILD_SHARED_LIBS=On -DBOARD_TYPE=${BOARD_TYPE}
	cmake --build build/json-c --config Release

ubox:
	cmake -H./libubox -Bbuild/libubox -DBOARD_TYPE=${BOARD_TYPE}
	cmake --build build/libubox --config Release

luci:
	cmake -H./uci -Bbuild/uci -DBOARD_TYPE=${BOARD_TYPE}
	cmake --build build/uci --config Release

lubus:
	cmake -H./ubus -Bbuild/ubus -DBOARD_TYPE=${BOARD_TYPE}
	cmake --build build/ubus --config Release

lmosquitto:
	cmake -H./mosquitto -Bbuild/mosquitto -DBOARD_TYPE=${BOARD_TYPE}
	cmake --build build/mosquitto --config Release

install:
	cp build/json-c/*.so ../../build/${BOARD_TYPE}
	cp build/libubox/*.so ../../build/${BOARD_TYPE}
	cp build/ubus/*.so ../../build/${BOARD_TYPE}
	cp build/uci/*.so ../../build/${BOARD_TYPE}
	cp build/mosquitto/lib/*.so ../../build/${BOARD_TYPE}

clean:
	rm -rf build
	