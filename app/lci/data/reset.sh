#!/bin/sh

# udhcp
mkdir -p /usr/share/udhcpc/
cp default.script /usr/share/udhcpc/default.script
rm /usr/share/udhcpc/udhcp.txt
chmod 777 /usr/share/udhcpc/default.script

# init.d
cp S88lnode /etc/init.d/S88lnode
chmod 777 /etc/init.d/S88lnode

# bin
ln -s /usr/local/lnode/bin/lnode /usr/sbin/lnode
ln -s /usr/local/lnode/bin/lpm /usr/sbin/lpm
rm -rf /usr/local/bin/

# passwd
cp passwd /etc/passwd

# lnode.key
cp lnode.key /usr/local/lnode/conf/lnode.key
cp network.default.conf /usr/local/lnode/conf/network.default.conf
cp default.conf /usr/local/lnode/conf/default.conf

# lpm
echo "# Device ID (MAC)"
echo "lpm set did xxxxxx"
echo ""

