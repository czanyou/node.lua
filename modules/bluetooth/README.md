# 蓝牙主机

## 打开蓝牙设备

```sh
# 打开所有无线设备
rfkill unblock all

# 查看所有无线设备
rfkill list all

# 启用蓝牙主机
sudo hciconfig hci0 up

# 安装 libbluetooth 以及头文件
sudo apt-get install libbluetooth-dev

```

## 使用

访问蓝牙设备必须有管理员权限

```sh

```

