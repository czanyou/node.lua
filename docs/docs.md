# 文档

[TOC]

本文主要描述了如何编写，组织并发布项目文档。


## 格式

说明文档以 Markdown 格式为主 (扩展名为 .md).

本文描述了编写项目文档的一些规范


## 显示方式

本项目使用 PHP 来解析并显示 Markdown 文档, 所以要需要有一个支持 PHP 的 WEB 服务器.

然后将 /node/docs 目录下的文件都复制到 WEB 服务指定目录下即可访问.


## 目录结构

文档首页是 /node/docs/index.php

其他文档分成了 3 个主要模块: 基本文档 (node/docs/docs), 核心 API 文档 (/node/node.lua/docs), 扩展 API 文档 (/node/vision/docs).

每个模块下有一个列表文件: 'index.php'

```html
+- index.php            文档首页
+-
+- Parsedown.class.php  Markdown 文件解析类
 +-- assets             静态资源文件目录
   +- style.css         全局样式表
 +- docs                文档分类文档
   +- index.php         左侧文档索引文件
   +- vision_xxx.md
 +- api                 API 分类文档 
   +- index.php         左侧文档索引文件
   +- node_xxx.md
 +- vision              扩展分类文档
   +- index.php         左侧文档索引文件
   +- vision_xxx.md

```


## 添加新文档

要添加新文档则直接在上述的文件夹中新建 md 类型文件即可.

同时需修改相应的 'index.php' 文件, 添加对这个文档的链接:

比如添加一个名为 'vision_test.md' 的新文档:

```html
<li><a href="vision_test">Test - 测试新文档</a></li>
```


## 文档目录(标题列表)

请在文档头部添加 \[ TOC \] 标记, 这样就会自动生成目录列表, 方便用户阅读.


## 引用代码

文档中可以直接插入代码


## 流程图

文档中可以直接插入流程图


## 文档目录

每个项目下都应有一个 docs 目录专门用来存放该项目的文档文件。


## 其他项目开发备忘

### SVN 常用命令使用提示

#### svn up 更新代码

    svn up

#### svn ci 提交代码

    svn ci -m "<message>"

- message 本次提交的日志消息内容

#### svn st 查看 SVN 本地修改状态

    svn st

#### svn info 查看当前项目信息

    svn info


### PHP mbstring

nginx:

```

```


PHP 7.0 启用 mbstring 模块的方法:

    sudo gedit /etc/php/7.0/fpm/php.ini

去掉这一行前面的注释并保存退出:

    extension=php_mbstring.so

```sh
sudo apt-get install php7.0-mbstring
sudo /etc/init.d/php7.0-fpm restart
```

### Memo

    ffmpeg -i bbd.mp4 -codec copy -bsf h264_mp4toannexb a.ts