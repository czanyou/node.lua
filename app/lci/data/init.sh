#!/bin/sh

# mount a memory file system
mount -t tmpfs -o size=16m tmpfs /tmp/

# init the network interface
ifconfig eth0 192.168.1.12

# nfs
# mount -t nfs -o nolock 192.168.1.38:/mnt/nfs /mnt/nfs

# init the FTP server
echo "21 stream tcp nowait root ftpd ftpd -w /" > /etc/inetd.conf
killall inetd
inetd

# upload...
mkdir -p /tmp/node

# unzip & install ...
unzip /tmp/upload -d /tmp/node/

chmod +x /tmp/node/bin/lnode

/tmp/node/bin/lnode /tmp/node/app/lpm/bin/lpm install /tmp/upload

