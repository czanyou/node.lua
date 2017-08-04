# Visual Studio Code 开发提示

[TOC]

> @author 成真

为了方便使用 Visual Studio Code 开发 Node.lua, 可以安装如下插件以及修改相关的设置.

## 有用的插件

### lua-for-vscode (xxxg0001)

- 能显示函数符号列表
- 有显示查看定义功能

### CMake (twxs)

- 支持 CMake 语法高亮

### C/C++ (Microsoft)

- 支持更好的 C/C++ 开发
- 不支持 Windows

### Code Runner (Jun Han)

- 直接运行单个文件


## 自定义键盘绑定

| Key         | Description
| ---         | ---
| f8:         | 显示符号列表 (函数列表)
| f9:         | 对选中的行排序
| ctrl+b:     | 运行当前文件
| alt+b:      | 停止正在运行的程序

```json

// 将键绑定放入此文件中以覆盖默认值
[
    { "key": "ctrl+r",          "command": "workbench.action.gotoSymbol" },
    { "key": "f8",              "command": "workbench.action.gotoSymbol" },
    { "key": "f9",              "command": "editor.action.sortLinesAscending",
                                     "when": "editorTextFocus" },

    { "key": "ctrl+b",           "command": "code-runner.run" },
    { "key": "ctrl+alt+j",       "command": "code-runner.runByLanguage" },
    { "key": "alt+b",            "command": "code-runner.stop" }

]

```

