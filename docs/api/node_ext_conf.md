# conf 配置文件

[TOC]

conf 用于读写配置文件, 可以用来在文件系统保存一些较简单的配置参数等信息.

通过 `require('ext/conf')` 调用。

目前只实现了读写 JSON 格式的配置文件

注意参数值只支持 number, boolean 和 string 等基本数据类型

参数名应当只包含字母, 数字以及下划线

参数名可以多级, 不同级别间以 '.' 分隔, 比如 'video.width' 在配置文件中会如此保存:

```json
{
    "video": {
        "width": 1280
    }
}
```

## conf

    conf(name)

加载指定名称的配置文件, 并返回相关的 Profile 对象

这个方法为同步方法

- name {String} 如 'user', 则会自动加载 `<NodeLua root>/conf/user.conf` 文件

## conf.load

    conf.load(name, callback)

- name {String}
- callback {Function} - function(err, result)

异步的方式加载指定的配置文件

## Class Profile

代表一个配置文件

### profile:initialize

    profile:initialize(filename)

- filename 相关配置文件全名

### profile:commit

    profile:commit(callback)

保存当前内存中的配置文件内容的文件中

- callback {Function} - function(err, result) 当保存完成后调用这个函数

如果 callback 为 nil, 表示同步的方式执行

### profile:get

    profile:get(name)

返回指定名称的参数的值

- name {String} 参数名, 多级参数名则以 '.' 分隔, 如 'video.width'

### profile:set

    profile:set(name, value)

设置指定名称的参数的值

- name {String} 参数名, 多级参数名则以 '.' 分隔, 如 'video.width'
- value {nil|String|Number|Boolean|Object|Array} 参数值,
    如果传入不支持的其他类型会自动转为字符串类型值

如果 value 的值为 nil 表示**删除**这个参数

注意 set 只会修改内存中的值, 要保存到文件还需要调用 commit 方法.

### profile:load

    profile:load(text)

从字符串加载.

- text {String} JSON 格式的字符串

### profile:reload

    profile:reload(callback)

重新从文件加载.

- callback {Function} - function(err, result) 当加载完成后调用这个函数

如果 callback 为 nil, 表示同步的方式执行

如果相关配置文件在外部被修改, 可以通过这个方法重新加载其内容.

### profile:toString

    profile:toString()

返回代表这个 Profile 的字符串, 目前只支持返回 JSON 格式.

