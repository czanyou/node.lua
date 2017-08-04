# NanoPi Air

[TOC]

## 登录

The password for "root" is "fa".

## Wi-Fi

Open the file "/etc/wpa_supplicant/wpa_supplicant.conf" with vi or gedit and append the following lines:

```
network={
        ssid="YourWiFiESSID"
        psk="YourWiFiPassword"
}
```

The "YourWiFiESSID" and "YourWiFiPassword" need to be replaced with your actual ESSID and password.


Save, exit and run the following commands your board will be connected to your specified WiFi:

```
ifdown wlan0
ifup wlan0
```

## 挂接远程文件系统

```
sudo mkdir -p /media/hfs
sudo chmod 777 /media/hfs
sshfs root@192.168.77.116:/ /media/hfs/


sshfs sae@10.10.38.60:/ /media/hfs/
sshfs root@112.74.210.14:/ /media/sfs/
sshfs pi@172.16.222.43:/ /media/sfs/

```

密码为 fa

### 设置运行环境

将多媒体相关的 lib 文件复制到 /usr/local/lib/, 还需要将这个目录添加到环境变量中.

```
export LD_LIBRARY_PATH=/usr/local/lib/
```

## SSH

通过 SSH 登录到开发板:

```
ssh 192.168.77.116 -l root
```

密码为 fa

## alsa 

```
sudo apt install libasound2-dev
```




