# DNS

[TOC]

显示原文其他翻译纠错
使用 require('dns') 引入此模块。dns 模块中的所有方法都使用了 C-Ares，除了 dns.lookup 使用了线程池中的 getaddrinfo(3)。C-Ares 比 getaddrinfo 要快得多，但系统解析器相对于其它程序的操作要更固定。当一个用户使用 net.connect(80, 'google.com') 或 http.get({ host: 'google.com' }) 时会使用 dns.lookup 方法。如果用户需要进行大量的快速查询，则最好使用 C-Ares 提供的方法。

## dns.lookup

    dns.lookup(domain, [family], callback)

将一个域名（比如 'google.com'）解析为第一个找到的 A 记录（IPv4）或 AAAA 记录（IPv6）。地址族 family 可以是数字 4 或 6，缺省为 null 表示同时允许 IPv4 和 IPv6 地址族。

回调参数为 (err, address, family)。地址 address 参数为一个代表 IPv4 或 IPv6 地址的字符串。地址族 family 参数为数字 4 或 6，地表 address 的地址族（不一定是之前传入 lookup 的值）。

当错误发生时，err 为一个 Error 对象，其中 err.code 为错误代码。请记住 err.code 被设定为 'ENOENT' 的情况不仅是域名不存在，也可能是查询在其它途径出错，比如没有可用文件描述符时。

## dns.resolve

    dns.resolve(domain, [rrtype], callback)

将一个域名（比如 'google.com'）解析为一个 rrtype 指定记录类型的数组。有效 rrtypes 取值有 'A'（IPv4 地址，缺省）、'AAAA'（IPv6 地址）、'MX'（邮件交换记录）、'TXT'（文本记录）、'SRV'（SRV 记录）、'PTR'（用于 IP 反向查找）、'NS'（域名服务器记录）和 'CNAME'（别名记录）。

回调参数为 (err, addresses)。其中 addresses 中每一项的类型取决于记录类型，详见下文对应的查找方法。

当出错时，err 参数为一个 Error 对象，其中 err.code 为下文所列出的错误代码之一。


## dns.resolve4

    dns.resolve4(domain, callback)

于 dns.resolve() 一样，但只用于查询 IPv4（A 记录）。addresses 是一个 IPv4 地址的数组（比如 ['74.125.79.104', '74.125.79.105', '74.125.79.106']）。


## dns.resolve6

    dns.resolve6(domain, callback)

