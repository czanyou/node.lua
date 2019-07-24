#!/bin/sh

# Install Node.lua files
export NODE_ROOT=/usr/local/lnode

mkdir -p ${NODE_ROOT}/
cp -rf usr/local/lnode/* ${NODE_ROOT}/
chmod -R 777 ${NODE_ROOT}/bin/*

# post install
export USR_SBIN=/usr/sbin

rm -rf ${USR_SBIN}/lnode
rm -rf ${USR_SBIN}/lpm

ln -s ${NODE_ROOT}/bin/lnode ${USR_SBIN}/lnode
ln -s ${NODE_ROOT}/bin/lpm ${USR_SBIN}/lpm

echo 'Finish!'
