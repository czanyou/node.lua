# Sublime Text 3 开发提示

[TOC]

> @author 成真

为了方便使用 Sublime Text 3 开发 Node.lua, 可以安装如下插件以及修改相关的设置.


## 常用插件

## Sublime Text Key Bindings

| Key         | Description
| ---         | ---
| f8:         | 显示符号列表 (函数列表)
| f9:         | 对选中的行排序
| ctrl+b:     | 运行当前文件
| alt+b:      | 停止正在运行的程序

```json
[
    { "keys": ["f9"], "command": "sort_lines", "args": {"case_sensitive": false} },
    { "keys": ["f8"], "command": "show_overlay", "args": {"overlay": "goto", "text": "@"} },
    { "keys": ["alt+b"], "command": "exec", "args": {"kill": true} },

]
```

### 配置 Node.lua 编译/运行配置

通过下面的配置就可以在 Sublime Text 3 中直接运行 Lua 程序了

更多的信息请参考 Sublime Text Build System.

D:\Program Files (x86)\Sublime Text 3\Data\Packages\User

Node.lua.sublime-build:

```json
{
    "shell_cmd": "lnode $file"
}

```

这里使用了 lnode 来执行 Lua 程序, 所以需要安装 Node.lua 开发环境.

