#!/usr/bin/env sh

# 这个脚本用于把多个静态库文件合并成一个动态链接库

# 
# http://node.sae-sz.com/download/?dir=dist/hi3518/libs/
#

arm-hisiv100nptl-linux-ar -x libaec.a
arm-hisiv100nptl-linux-ar -x libanr.a
arm-hisiv100nptl-linux-ar -x libresampler.a
arm-hisiv100nptl-linux-ar -x libVoiceEngine.a

arm-hisiv100nptl-linux-gcc -shared *.o -o libvoice.so

rm -rf *.o