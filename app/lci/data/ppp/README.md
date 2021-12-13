# README

## Pay attention

Pay attention: Donot modify the 3 files in Windows.
Pay attention: It will make the 3 file become Dos format. 
Pay attention: Dos Format files cannot be parsed by pppd and chat.
Pay attention: dos2unix command can convert files in DOS format to Unix format.

customize your 'serial device name' & 'user' & 'passowrd' in quectel-ppp
customize your 'apn' in quectel-chat-connect

copy the 3 file to /etc/ppp/peers/

exec command 'pppd call quectel-ppp'

## Pay attention

注意不要在 windows 下编辑该目录下的文件、否则会使得这些文件变成 dos 格式.
windows 的 dos 格式是指文件的每行以 \r\n 结尾，而 linux 的文件默认是以 \n 结尾的。
pppd 和 chat 不能解析 dos 格式的文件。
工具 dos2unix 可以把 dos 格式的文件转成 linux 格式。

## 启动ppp拨号

有 2 种方法启动 ppp 拨号

### 方式 1

方式 1：拷贝 quectel-chat-connect quectel-chat-disconnect quectel-ppp 到 /etc/ppp/peers 目录下。

并在 quectel-ppp 里修改你的串口设备名，pppd 拨号使用的 username，password。

在 quectel-chat-connect 里修改你的 APN。APN/username/password 是从你的网络提供商那里获取的。

然后使用下面的命令启动 ppp 拨号， 命令最后的 & 可以让 pppd 后台运行

pppd call quectel-ppp &

### 方式 2

方式 2：使用 quectel-pppd.sh 拨号，命令形式如下:

./quectel-pppd.sh 串口设备名(比如/dev/ttyUSB3) APN username password

ip-up：pppd 在获取 ip 和 dns 之后，会自动调用这个脚本文件来设置系统的 DNS

嵌入式系统一般需要拷贝这个文件到 /etc/ppp 目录下。
请确保该文件在你的系统里有可执行权限。

quectel-ppp-kill 用来挂断拨号的，pppd 必须被正常的挂断，否则可能会导致你下次 ppp 拨号失败。

使用下面方式来调用这个脚本

./quectel-ppp-kill 