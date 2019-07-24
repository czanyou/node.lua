# !/bin/sh

	cd /usr/local/lnode/lib
	rm lmodbus.so
	cp /mnt/nfs/node.lua-master/build/hi3516/lmodbus.so ./
	cd /mnt/nfs/node.lua-master/test
