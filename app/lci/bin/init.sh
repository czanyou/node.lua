#!/bin/sh

# device /dev/ttyAMA2
himm 0x12098000 0xe2
himm 0x120400c4 0x02
himm 0x120400c8 0x02
himm 0x120400f0 0x01

# watchdog
# total = 64M (osmem=48M,mmz=16M,os_offset=0x80000000,mmz_offset=0x83000000)
insmod /ko/sys_config.ko
insmod /ko/hi_osal.ko mmz=anonymous,0,0x83000000,16M anony=1
insmod /ko/hi3516cv300_wdt.ko
