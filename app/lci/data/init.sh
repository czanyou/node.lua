#!/bin/sh

mount -t tmpfs -o size=16m tmpfs /tmp/

echo "21 stream tcp nowait root ftpd ftpd -w /" > /etc/inetd.conf

inetd

mkdir -p /tmp/node

unzip /tmp/upload -d /tmp/node/

chmod +x /tmp/node/bin/lnode

/tmp/node/bin/lnode /tmp/node/app/lpm/bin/lpm install /tmp/upload

