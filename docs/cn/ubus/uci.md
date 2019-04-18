# UCI

## Overview

UCI是 **U**nified **C**onfiguration **I**nterface的缩写，翻译成中文就是统一配置接口，用途就是为OpenWrt提供一个集中控制的接口。OpenWrt实现的这个工具，能够让你的不管是Lua还是PHP程序，或者SHELL程序或C程序，只要执行命令传输参数就能达到修改系统参数的目的，请参考本文后面的*命令行实用工具*。

UCI目前已经支持有一小部分应用程序，因而对这些应用程序的控制会变得更加简单一些。这些第三方应用程序都会有自己的配置文件，不同的语法，不同的文件位置，如

```
/etc/network/interfaces

/etc/exports

/etc/dnsmasq.conf

/etc/samba/samba.conf
```

由于UCI统一配置接口的出现，对这些第三方应用程序的配置只需要修改UCI的配置文件即可，就不必再去找不同的目录，写不同的语法了。当然，你安装的大多数第三方应用程序都没有提供UCI配置接口，很可能是因为这些应用程序本身就不需要向普通用户提供应用程序接口，配置文件是给开发者使用的，从这个角度上来看，没有提供UCI接口反而更好。因而，OpenWrt包维护人员只选定了一小部分必需的程序实现了UCI配置接口

许多第三方程序是根据它自己对应于/etc/config下的UCI配置文件的选项去设置程序的原始配置文件，这样就实现了程序对UCI配置的兼容，然后执行一次/etc/init.d[脚本](http://wiki.openwrt.org/doc/techref/initscripts)完成一次配置。因而当你启动一个某个程序的UCI兼容的进程脚本时，该脚本应该不只是修改/etc/config下对应的UCI配置文件，同时也应该覆盖程序自己的原配置文件。比如[Samba/CIFS](http://wiki.openwrt.org/doc/howto/cifs.server)程序，其原配置文件是在/etc/samba/smb.conf，而对应的UCI文件是/etc/config/samba，当/etc/config/samba文件被修改了之后，需要运行一次

```
/etc/init.d/samba start
```

之后UCI文件中的设置才会更新到原配置文件中去。

![img](https://images0.cnblogs.com/i/577327/201404/251250147015278.png) 

除此之外，应用程序的配置文件常常是存放在RAM而不是FLASH中，因为它不需要每次修改参数之后就去写非易性闪存了，而只在应用改变的时候它才会根据UCI文件去写非易性闪存



# 文件语法

uci配置文件通常包含有一个或多个语句。所谓段（section），包含有一个或多个 option 语句，这些语句定义了实际的值。

下面是一个简单的配置文件：

```
package 'example'

config 'example' 'test'
        option   'string'      'some value'
        option   'boolean'     '1'
        list     'collection'  'first item'
        list     'collection'  'second item'
```

- *config 'example' 'test'*表示一个段的开始，其中example是段的*类型*，test为段的*名字*。段也可以没有名字，像config 'example'，但是必须要有类型，类型指示了uci程序怎么去处理后面的option内容；
- option 'string' 'some value'和option 'boolean' '1'两个语句定义了段内的两个*标识符*的值，虽然它们一个是string一个是boolean，但是在语法没有任何区别。boolean后面可以跟'0', 'no', 'off', 'false'中的一个作为否的值，或者'1', 'yes', 'on', 'true'作为逻辑是的值；
- 后面两行以 list 开头的语句，是为某个有多种选项值的 option 所定义的，在同一 option 中的选项值，它们应该有同样的名字，在这里的名字为 collection。最终这两个值为收纳到同一个 list 表中，表中出现的顺序即你这里所定义的；
- 标识符 option 和 list 是为了更易读而加上的，没有它们也是可以的；
- 如果某个 option 没有但它不是必须的，那么 uci 处理程序会假定一个默认值；如果该 option 是必须的，而文件中没有定义，那么 uci 会报错或者显现出奇怪的结果；

语句中的标识和值可不必使用引号引起，除非你的字段值含有空格或者 tab 键。如果使用引号，那你可以随意使用单引号或者双引号。比如这样子：

```
option example value
option 'example' value
option example "value"
option "example" 'value'
option 'example' "value"
```

不过不能这样子（引号混用，字段中有空格但未用引号引起来）：

```
option 'example" "value' (quotes are unbalanced)
option example some value with space (note the missing quotes around the value)
```

UCI 的文件名和标识符（像 option example value 中的 example 即为标识符，value 为 option 的值）可以使用a-z, 0-9和下划线_组合的任意字符串，不允许使用横杠线-，而 option 的值可以傅任意字符（像空格这样子的字段值需要用引号引起）。 

# 命令行工具

修改配置参数的一般方法是直接去修改 UCI 配置文件。不过，UCI 配置文件读写操作都可以通过 uci 命令行工具来完成，因此你自己去写一个脚本来解析或输出 UCI 配置文件不是一个明智的选择，既浪费时间又不一定写得好。以下介绍如何使用 uci 命令行工具，并有一些实例参考：

## 用法

> root@OpenWrt:~#uci

```
Usage: uci [<options>] <command> [<arguments>]

Commands:
	batch
	export     [<config>]
	import     [<config>]
	changes    [<config>]
	commit     [<config>]
	add        <config> <section-type>
	add_list   <config>.<section>.<option>=<string>
	del_list   <config>.<section>.<option>=<string>
	show       [<config>[.<section>[.<option>]]]
	get        <config>.<section>[.<option>]
	set        <config>.<section>[.<option>]=<value>
	delete     <config>[.<section[.<option>]]
	rename     <config>.<section>[.<option>]=<name>
	revert     <config>[.<section>[.<option>]]
	reorder    <config>.<section>=<position>

Options:
	-c <path>  set the search path for config files (default: /etc/config)
	-d <str>   set the delimiter for list values in uci show
	-f <file>  use <file> as input instead of stdin
	-m         when importing, merge data into an existing package
	-n         name unnamed sections on export (default)
	-N         don't name unnamed sections
	-p <path>  add a search path for config change files
	-P <path>  add a search path for config change files and use as default
	-q         quiet mode (don't print error messages)
	-s         force strict mode (stop on parser errors, default)
	-S         disable strict mode
	-X         do not use extended syntax on 'show'
```

| 命令       | 目标                                    | 描述                                                         |
| ---------- | --------------------------------------- | ------------------------------------------------------------ |
| `commit`   | `[<config>]`                            | 保存所有修改过的参数， 如果没有指定文件名称， 则保存所有修改过的配置文件。即通过 uci add, set, delete 等命令修改的参数会暂存在临时文件中， 只有执行了 commit 命令后才会写入 Flash |
| `batch`    | -                                       | 执行多行 UCI 命令                                            |
| `export`   | `[<config>]`                            | 将指定的配置文件导出为机器可读的格式                         |
| `import`   | `[<config>]`                            | 导入 UCI 语法的配置文件                                      |
| `changes`  | `[<config>]`                            | 列出所有修改了但还未保存的参数， 如果没有指定文件则列出文件的修改内容 |
| `add`      | `<config>  <section-type>`              | 添加一个匿名的 section 到指定的配置文件中                    |
| `add_list` | `<config>.<section>.<option>=<string>`  | 添加一个字符串到已存在的列表选项中                           |
| `del_list` | `<config>.<section>.<option>=<string>`  | 从已存在的列表选项中删除指定的字符串                         |
| `show`     | `[<config>[.<section>[.<option>]]]`     | 指定指定选项，section 或配置文件的内容                       |
| `get`      | `<config>.<section>[.<option>]`         | 返回指定的选项或者指定类型的 section 的值                    |
| `set`      | `<config>.<section>[.<option>]=<value>` | 设置指定的选项的值，如果不存在的话则会添加相应类型的 section |
| `delete`   | `<config>[.<section[.<option>]]`        | 删除指定的选项或 section                                     |
| `rename`   | `<config>.<section>[.<option>]=<name>`  | 重命名指定的选项或 section                                   |
| `revert`   | `<config>[.<section>[.<option>]]`       | 复原指定的选项或 section                                     |
| `reorder`  | `<config>.<section>=<position>`         | 重新排序                                                     |

## 例子

### 设置一个值

把 uhttpd 的监听端口从 80 换成 8080

```
root@OpenWrt:~# uci set uhttpd.main.listen_http=8080 
root@OpenWrt:~# uci commit uhttpd 
root@OpenWrt:~# /etc/init.d/uhttpd restart 
root@OpenWrt:~#
```

### 导出配置信息

```
root@OpenWrt:~# uci export httpd 
package 'httpd' 

config 'httpd' 
    option 'port' '80' 
    option 'home' '/www' 

root@OpenWrt:~#
```

### 显示一个给定配置的树

```
root@OpenWrt:~# uci show httpd 
httpd.@httpd[0]=httpd 
httpd.@httpd[0].port=80 
httpd.@httpd[0].home=/www 
root@OpenWrt:~#
```

### 显示一个 option 的值

```
root@OpenWrt:~# uci get httpd.@httpd[0].port
80 
root@OpenWrt:~#
```

### 追加 list 的一个条目

```
uci add_list system.ntp.server='0.de.pool.ntp.org'
```

### 替换一个list

```
uci delete system.ntp.server 
uci add_list system.ntp.server='0.de.pool.ntp.org' 
uci add_list system.ntp.server='1.de.pool.ntp.org' 
uci add_list system.ntp.server='2.de.pool.ntp.org'
```

### UCI 路径

假设有下面的UCI文件

```
# /etc/config/foo 
config bar 'first'
    option name 'Mr. First' 
config bar
    option name 'Mr. Second' 
config bar 'third'
    option name 'Mr. Third'
```

那么下面三组路径的执行得到的值分别各自相等

```
# Mr. First 
uci get foo.@bar[0].name
uci get foo.@bar[-0].name
uci get foo.@bar[-3].name
uci get foo.first.name

# Mr. Second 
uci get foo.@bar[1].name
uci get foo.@bar[-2].name
# uci get foo.second.name 本条语句不工作，因为 second 没有定义 

# Mr. Third 
uci get foo.@bar[2].name
uci get foo.@bar[-1].name
uci get foo.third.name
```

如果 show，则会得到这样的值

```
# uci show foo 
foo.first=bar 
foo.first.name=Mr. First 
foo.@bar[1=bar 
foo.@bar[1].name=Mr. Second 
foo.third=bar 
foo.third.name=Mr. Third
```

执行uci show foo.@bar[0]得到

```
# uci show foo.@bar[0] 
foo.first=bar 
foo.first.name=Mr. First
```

### 查询输出

```
root@OpenWrt:~# uci -P/var/state show network.wan
uci: Entry not found
network.loopback=interface
network.loopback.ifname=lo
network.loopback.proto=static
network.loopback.ipaddr=127.0.0.1
network.loopback.netmask=255.0.0.0
network.loopback.up=1
network.loopback.connect_time=10749
network.loopback.device=lo
network.lan=interface
network.lan.type=bridge
network.lan.proto=static
network.lan.netmask=255.255.255.0
network.lan.ipaddr=10.0.11.233
network.lan.gateway=10.0.11.254
network.lan.dns=8.8.8.8
network.lan.up=1
network.lan.connect_time=10747
network.lan.device=eth0
network.lan.ifname=br-lan
```

### 添加防火墙规则

这个例子不仅演示了如何添加TCP SSH防火墙规则，同时也演示uci的negative (-1)语法。

```
root@OpenWrt:~# uci add firewall rule 
root@OpenWrt:~# uci set firewall.@rule[-1].src=wan 
root@OpenWrt:~# uci set firewall.@rule[-1].target=ACCEPT 
root@OpenWrt:~# uci set firewall.@rule[-1].proto=tcp 
root@OpenWrt:~# uci set firewall.@rule[-1].dest_port=22 
root@OpenWrt:~# uci commit firewall 
root@OpenWrt:~# /etc/init.d/firewall restart
```

### 获取 SSID

```
root@OpenWrt:~# uci get wireless.@wifi-iface[-1].ssid
NGTestRouter
```

**1.参考：http://wiki.openwrt.org/doc/techref/uci#api**

**2.增删查改函数.**

定义local x = luci.model.uci.cursor()

个人理解这个函数是提供uci的API的句柄

以下是对配置文件的增删查改

**2.1增.**

x:set("config","name","type") --增加一个section

x:set("config","sectionname","option","exp") --在section下增加配置

参数说明

config --- 配置文件的名字，配置文件位于/etc/config/下

name --- 配置文件中某个类型的具体名字

type --- 配置文件中类型（type）

option -- 具体配置

exp ---配置文件中具体参数类型的值



例：

\#-----------------------------------------------------

x:set("wificonfig","0","wifi")

config wifi '0'

\#-----------------------------------------------------

x:set("wificonfig","0","ip","192.168.0.1")

option ip '192.168.0.1'

\#----------------------------------------------------

\#以上两个函数联合起来如下：

\#-----------------------------------------------------

config wifi '0'

     option ip '192.168.0.1'



**2.2 删**

x:delete("config","section") --删除section

x:delete("config,"section","option") -- 在section下删除option

删除某个section

2.1中的config wifi '0'直接可以用此函数删除

x:delete("wificonfig","wifi")



**2.3查**

x:foreach("config","type","function(s) ... end") -- 遍历整个config文件

x:get("config","sectionname","option") ---获得option的值

在foreach中有个两个变量

s[".type"] -->section type

s[".name"] -->section name

其中s[".name"] 就是x:get的第二个参数

例:有如下一个配置文件

config globals '0'

     option hostname 'iphone'

     option ip '192.168.0.1'

     option mac '00:11:22:33:44:55:66'

config globals '1'

     option hostname 'iphone1'

     option ip '192.168.0.2'

     option mac '00:11:22:33:44:55:77'

遍历并且打印每一个option

x:foreach("wificonfig","globals",function(s)

     local lcName = s[".name"]

     local lcHostname = x:get("wificonfig",lcName,"hostname")

     local lcIp = x:get("wificonfig",lcName,"ip")

     local lcMac = x:get("wificonfig",lcName,"mac")

     print("hostname = " .. lcHostname .. ",ip = " .. lcIp .. ",mac= " .. lcMac)

end

)

**2.4修改**

直接用2.1中的函数即可

**3.commit函数**

当修改后的配置文件，必须调用x:commit函数才能生效。

**4.位置插入函数**

x:reorder("config","sectionname",position)

将某个section放到postion位置（配置的section是从0开始计数）