#!/usr/bin/env sh

# 这个脚本用于把多个静态库文件合并成一个动态链接库

# http://node.sae-sz.com/download/?dir=dist/hi3516a/libs/


arm-hisiv300-linux-ar -x libmpi.a
arm-hisiv300-linux-ar -x libtde.a
arm-hisiv300-linux-ar -x libisp.a
arm-hisiv300-linux-ar -x libive.a
arm-hisiv300-linux-ar -x libsns_imx178.a

arm-hisiv300-linux-ar -x lib_hiae.a
arm-hisiv300-linux-ar -x lib_hiaf.a
arm-hisiv300-linux-ar -x lib_hiawb.a
arm-hisiv300-linux-ar -x libmem.a

arm-hisiv300-linux-ar -x libdvqe.a
arm-hisiv300-linux-ar -x libdnvqe.a
arm-hisiv300-linux-ar -x libupvqe.a
arm-hisiv300-linux-ar -x libvqev2.a
arm-hisiv300-linux-ar -x libresampler.a
arm-hisiv300-linux-ar -x libVoiceEngine.a
arm-hisiv300-linux-ar -x lib_cmoscfg.a
arm-hisiv300-linux-ar -x lib_hidefog.a

arm-hisiv300-linux-gcc -shared *.o -o libmpp.so
arm-hisiv300-linux-strip libmpp.so

rm -rf *.o
