# MT7688 开发指南

[TOC]

Widora 板载了 USB 转 TTL 调试芯片 CP2104，调试串口是丝印为 “USB-TTL” 的 microusb 接口，可以通过一根 microusb 线缆连接到PC即可。

## 通过串口登录

OS X和Linux建议自行安装minicom，安装完设置步骤如下
查看串口设备，Linux内一般是/dev/ttyUSB0，OS X一般是/dev/tty.SLAB_USBtoUART

设置 minicom，”$ sudo minicom -s”, 选择 Serial port setup 后，将 A 设置为对应的串口设备，E 设置为 115200 8N1，F 设置为 No

设置好后选择 “Save setup as dfl ”保存配置， 选择 Exit 退出设置即可

## 通过 SSH 登录

请先通过 串口登录 为 root 账号设置初始密码, 如设置密码为 'root'

通过 WiFi 连接到开发板的 AP

然后在 Linux 命令行执行如下命令:

`$ ssh 192.168.1.1 -l root`

按提示输入密码即可登录

## 网络配置

Widora 板默认为 AP 模式, 可以通过修改配置文件改为其他网络模式.

https://wiki.openwrt.org/doc/uci

板子默认固件的状态是网口和 AP 处于 LAN 端，只有用 connect2ap 配置了中继才会有 WAN 端，此时 WAN 端为APCLI0. 
就是我们常规理解的 WIFI 转网口。
如果要用 widora 的网口链接路由器，那么只需要运行一次 eth_set_wan 命令，网口此时会变为 WAN 端，链接到路由器后可以获取 IP 地址。

连接 WiFi:

```
config wifi-iface                                                               
        option device 'mt7628'                                                  
        option ifname 'ra0'                                                     
        option network 'wwan'                                                   
        option mode 'sta'                                                       
        option ssid 'CM3'                                                       
        option encryption 'psk'                                                 
        option key '12345678'                                                   
        option ApCliSsid 'CM3'                                                  
        option ApCliEnable '1'                                                  
        option ApCliAuthMode 'WPA2PSK'                                          
        option ApCliEncrypType 'AES'                                            
        option ApCliWPAPSK '12345678'  
```

connect2ap CM3 12345678

连接路由器:

eth_set_wan

## 在线安装

```
opkg update

# 安装 unzip
opkg install unzip

# 安装 NFS
opkg install nfs-utils


```

## 编译工具链

有时候，想简单编译些小程序，用 openwrt 的框架反而会不方便（主要是写那个 Makefile 不太方便）。
其实方法很简单，我们需要找到 openwrt 下 MT7688 的编译器即可。

假设绝对目录是:

`/opt/mt7688/staging_dir/toolchain-mipsel_24kec+dsp_gcc-4.8-linaro_uClibc-0.9.33.2/bin`

修改用户目录的".bashrc"文件，在末尾位置添加一句：

```sh
cp sdk.tar.bz2 /opt
cd /opt
tar jxvf sdk.tar.bz2
mv OpenWrt... mt7688
```

```sh
export PATH=$PATH:/opt/mt7688/staging_dir/toolchain-mipsel_24kec+dsp_gcc-4.8-linaro_uClibc-0.9.33.2/bin
export STAGING_DIR=/opt/mt7688/staging_dir/
```

保存，使.bashrc有效：

```sh
source .bashrc
```

接下来终端里输入 mipsel-openwrt-linux-gcc 会出现：

```sh
mango@Ubuntu1404:~$ mipsel-openwrt-linux-gcc
mipsel-openwrt-linux-gcc: fatal error: no input files
compilation terminated.
mango@Ubuntu1404:~$
```

## 首次安装 node.lua

```sh

mkdir /tmp/node
cd /tmp/node
wget http://192.168.1.117/nodelua-mt7688-sdk.zip


unzip nodelua-mt7688-sdk.zip




```

## SSH filesystem

sshfs –o cache=yes,allow_other user@192.168.1.200:/home/user/code home/user/code  


## OpenWrt无线Wifi客户端模式

在OpenWrt下主要是设置/etc/config/network、/etc/config/wireless这两个文件，其他的都与默认的LAN和WAN模式相同。

/etc/config/network下，关闭VLAN（enable_valn=0）,lan接口设置成静态并 去掉网桥 
（默认为'option type bridge'，Wifi通常自动桥接到lan接口），
wan去掉'option ifname '选项（无线Wifi接口会自动加入wan作为ifname）。

```
config switch eth1
    option reset 0
    option enable_vlan 0

config interface loopback
    option ifname lo
    option proto static
    option ipaddr 127.0.0.1
    option netmask 255.0.0.0

config interface lan
    option ifname eth1
    option proto static
    option ipaddr 192.168.2.1
    option netmask 255.255.255.0

config interface wan
    option proto dhcp
```

配置以后所有交换机上的接口都变为内部LAN，而无线Wifi作为WAN连接外网。
LAN和WAN之间用NAT方式进行地址转换（具体在 firewall 的WAN设置masq=1，默认已经设置好了），
firewall的NAT选项叫Masquerade（伪装），就是WAN接口把内网的数据包源地址伪装成自己的，很形象:)。

我一开始连接失败用Tcpdump查看wlan0，发现数据包还没有NAT伪装，最后发现是firewall没启动，所以确保firewall开机启动：

/etc/init.d/firewall enable

查看firewall是否启动：

/etc/init.d/firewall enabled && echo on

/etc/config/wireless下，设置Wifi参数：

```
config wifi-device radio0
    option type mac80211
    option channel 0
    option hwmode 11g
    option txpower 0

config wifi-iface
    option device     radio0
    option network    wan
    option mode       sta
    option ssid       yourAPssid
    option encryption psk2
    option key        yourkey
```

主要是设置mode为sta，network选择要自动加入wan，填上要连接Wifi AP的ssid、加密方式encryption和密钥key，
全部完成后重启网络，Wifi连接成功后WLAN LED灯会亮起。

/etc/init.d/network restart

把你的台式电脑网线随便插入LAN口，这样你就成为了一台有无线网卡的台式机了，省去了用网线想方设法连接其他房间路由器的烦恼:)。


## PPPOE 

uci set network.wan.proto=pppoe
uci set network.wan.username='yougotthisfromyour@isp.su'
uci set network.wan.password='yourpassword'
uci commit network
ifup wan

http://www.2cto.com/net/201306/223534.html

root@Widora:/bin# cat eth_set_lan                                               
#!/bin/sh                                                                       
uci set    network.lan.ifname='eth0'                                            
uci set    network.lan.ipaddr='192.168.1.1'                                     
uci delete    network.wan                                                       
uci commit                                                                      
nr                                                                              
root@Widora:/bin# cat eth_set_wan                                               
#!/bin/sh                                                                       
uci delete network.lan.ifname                                                   
uci set    wireless.sta.disabled='1'                                            
uci set    network.lan.ipaddr='192.168.2.1'                                     
uci set    network.wan=interface                                                
uci set    network.wan.ifname='eth0'                                            
uci set    network.wan.proto='dhcp'                                             
uci commit                                                                      
nr  

root@Widora:/bin# cat /usr/bin/connect2ap                                       
#!/bin/sh                                                                       
                                                                                
ussid=$1                                                                        
upass=$2                                                                        
iwpriv ra0 set SiteSurvey=0                                                     
sleep 2                                                                         
OUTPUT=`iwpriv ra0 get_site_survey | grep '^[0-9]'`                             
while read line                                                                 
do                                                                              
        ssid=`echo $line | awk '{print $2}'`                                    
        echo $line                                                              
        if [ "$ssid"x = "$ussid"x ]; then                                       
#       # Set interfaces file                                                   
                umode=""                                                        
                uencryp=""                                                      
                                                                                
                channel=`echo $line | awk '{print $1}'`                         
                security=`echo $line | awk '{print $5}'`                        
                mac=`echo $line | awk '{print $4}'`                             
                                                                                
                if [ "$security"x = "WPA1PSKWPA2PSK/TKIPAES"x ]; then           
                        umode="WPA2PSK"                                         
                        uencryp="AES"                                           
                elif [ "$security"x = "WPA1PSKWPA2PSK/AES"x ]; then             
                        umode="WPA2PSK"                                         
                        uencryp="AES"                                           
                elif [ "$security"x = "WPA2PSK/AES"x ]; then                    
                        umode="WPA2PSK"                                         
                        uencryp="AES"                                           
                elif [ "$security"x = "WPA2PSK/TKIP"x ]; then                   
                        umode="WPA2PSK"                                         
                        uencryp="TKIP"                                          
                elif [ "$security"x = "WPAPSK/TKIPAES"x ]; then                 
                        umode="WPAPSK"                                          
                        uencryp="TKIP"                                          
                elif [ "$security"x = "WPAPSK/AES"x ]; then                     
                        umode="WPAPSK"                                          
                uencryp="AES"                                                   
                elif [ "$security"x = "WPAPSK/TKIP"x ]; then                    
                umode="WPAPSK"                                                  
                uencryp="TKIP"                                                  
                elif [ "$security"x = "WEP"x ]; then                            
                umode="WEP"                                                     
                uencryp="WEP"                                                   
                fi                                                              
                                                                                
                echo $umode                                                     
                echo $uencryp                                                   
                echo $channel                                                   
#               nvram_set 2860  ApCliSsid $ussid                                
#               nvram_set 2860  ApCliBssid  $mac                                
#               nvram_set 2860  ApCliAuthMode $umode                            
#               nvram_set 2860  ApCliEncrypType $uencryp                        
#               nvram_set 2860  ApCliWPAPSK $upass                              
#               nvram_set 2860  Channel $chanel                                 
                echo "start uci set ..."                                        
                uci set wireless.@wifi-iface[0].ApCliSsid=$ussid                
#               uci set wireless.@wifi-iface[0].ApCliBssid=$mac                 
                uci set wireless.@wifi-iface[0].ApCliEnable=1                   
                uci set wireless.@wifi-iface[0].ApCliAuthMode=$umode            
                uci set wireless.@wifi-iface[0].ApCliEncrypType=$uencryp        
                uci set wireless.@wifi-iface[0].ApCliWPAPSK=$upass              
                uci set wireless.mt7628.channel=$channel                        
                uci set network.wan=interface                                   
                uci set network.wan.ifname=apcli0                               
                uci set network.wan.proto=dhcp                                  
                uci set network.lan.ipaddr=192.168.99.1                         
                uci commit                                                      
                /etc/init.d/network restart                                     
        exit 0                                                                  
        fi                                                                      
done <<EOF                                                                      
$OUTPUT                                                                         
EOF    

