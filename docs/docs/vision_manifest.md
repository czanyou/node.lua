# Node.lua package.json 文件


## 字段

| 名称          | 类型      | 详情 
| ---           | ---       | ---
| depends       | string[]  | 表示这个包依赖的包，依赖的包必须在当前包安装前被安装, 格式为字符串数组
| description   | string    | 表示这个包的简要描述
| filename      | string    | 表示这个包的文件名
| md5sum        | string    | 表示这个包文件的 MD5 hash 值，用来确定下载的文件是否被篡改
| name          | string    | 表示这个包的名称，只能包含小写字母数字以及下划线
| size          | number    | 表示这个包的文件的大小 
| tags          | string[]  | 表示这个包的标签名称, 格式为字符串数组
| version       | string    | 表示这个包的版本，格式为 a.b.c, a 表示主版本号，b 表示子版号，c 一般表示构建版本号


## 示例

```json
{
    "depends": ["lnode"],
    "description": "Vision Framework",
    "filename": "vision.package",
    "md5sum": "bffc98e4121a62e576669a81f9849851",
    "name": "vision",
    "size": 102004,
    "tags": ["vision", "runtime"],
    "version": "1.0.0"
}
```