# 安装交叉编译环境

## 安装海思 arm-hisiv500-linux 交叉工具链

解压 arm-hisiv500-linux.zip

```shell
$ unzip arm-hisiv500-linux.zip
```

安装 arm-hisiv500-linux-gcc

```shell
$ chmod 777 arm-hisiv500-linux.install
$ sudo ./arm-hisiv500-linux.install
```

### 64 位 Ubuntu 兼容 32 位程序

第一步: 确认自己系统的架构

```shell
$ dpkg --print-architecture
# 输出：
# amd64
```

结果为 amd64 表示系统是 64 位的

第二步: 确认打开了多架构支持功能

```shell
$ dpkg --print-foreign-architectures
# 输出：
# i386
```

如果这里没有输出 i386，则需要打开多架构支持

```shell
$ sudo dpkg --add-architecture i386
$ sudo apt-get update
```

第三步: 安装对应的 32 位的库

```shell
# 这一步是更新所有的软件，如果你对新版本软件的需求不是那么迫切，可以不执行
$ sudo apt-get dist-upgrade 

# 安装相关库
$ sudo apt-get install lib32z1 lib32ncurses6 

# 有的还需要 32 位 stdc++ 库 lib32stdc++6-4.8-dbg

# 安装 gcc multilab
$ sudo apt-get install gcc-multilib g++-multilib
```
