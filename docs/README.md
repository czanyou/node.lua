# 文档

## 概述

本文主要描述了如何编写，组织并发布项目文档。

## 文档格式

说明文档以 Markdown 格式为主 (扩展名为 `.md`).

本文描述了编写项目文档的一些规范

## 显示方式

本项目使用 PHP 来解析并显示 Markdown 文档, 所以要需要有一个支持 PHP 的 WEB 服务器.

然后将 `/docs` 目录下的文件都复制到 WEB 服务指定目录下即可访问.


## 添加新文档

要添加新文档则直接在上述的文件夹中新建 md 类型文件即可.

同时需修改相应的 'books.json' 文件, 添加对这个文档的链接:

比如添加一个名为 'vision_test.md' 的新文档:

```html
["vision_test", "测试新文档"]
```

### PHP 多字节字符串

PHP 7.0 启用 `mbstring` 模块 (多字节字符串) 的方法:

> sudo nano /etc/php/7.0/fpm/php.ini

去掉这一行前面的注释并保存退出:

> extension=php_mbstring.so

```sh
sudo apt-get install php7.0-mbstring
sudo /etc/init.d/php7.0-fpm restart
```
