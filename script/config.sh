#!/bin/sh
udhcpc -b -i eth0 -p /var/run/udhcpc.pid
ifconfig eth0 192.168.8.254 netmask 255.255.255.0
route add default gw 192.168.8.1
sleep 3
ifconfig
sleep 3
mount -t nfs -o nolock 192.168.8.38:/mnt/nfs  /mnt/dt02
cd /mnt/nfs
echo 24 > /sys/class/gpio/export
echo out > /sys/class/gpio/gpio24/direction
echo 63 > /sys/class/gpio/export
echo out > /sys/class/gpio/gpio63/direction
echo 62 > /sys/class/gpio/export
echo in > /sys/class/gpio/gpio62/direction
echo 53 > /sys/class/gpio/export
echo out > /sys/class/gpio/gpio53/direction
echo 54 > /sys/class/gpio/export
echo out > /sys/class/gpio/gpio54/direction
echo 55 > /sys/class/gpio/export
echo out > /sys/class/gpio/gpio55/direction

echo 1 > /sys/class/gpio/gpio63/value
himm 0x12098000 0xe2
himm 0x120400c4 0x02
himm 0x120400c8 0x02
himm 0x120400f0 0x01
telnetd &

