#!/bin/sh

# udhcp
mkdir -p /usr/share/udhcpc/

dos2unix default.script
cp default.script /usr/share/udhcpc/default.script
chmod 777 /usr/share/udhcpc/default.script

# init.d
dos2unix S88lnode
cp S88lnode /etc/init.d/S88lnode
chmod 777 /etc/init.d/S88lnode

# conf
mkdir -p /usr/local/lnode/conf/
