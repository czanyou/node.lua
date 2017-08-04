# 路径 (path)

[TOC]

本模块包含一套用于处理和转换文件路径的工具集。几乎所有的方法只做字符串变换， 不会调用文件系统检查路径是否有效。

通过 `require('path')` 来加载此模块。以下是本模块所提供的方法：

## path.basename

    path.basename(p, [ext])

返回路径中的最后哦一部分. 类似于Unix 的 basename 命令.

实例：

```lua
path.basename('/foo/bar/baz/asdf/quux.html', '.html')
-- returns 'quux'
```

## path.dirname

    path.dirname(p)

返回路径中文件夹的名称. 类似于 Unix 的 dirname 命令.

实例：

```lua
path.dirname('/foo/bar/baz/asdf/quux')
-- returns '/foo/bar/baz/asdf'
```

## path.extname

    path.extname(p)

返回路径中文件的扩展名, 在从最后一部分中的最后一个'.'到字符串的末尾。 如果在路径的最后一部分没有'.'，或者第一个字符是'.'，就返回一个 空字符串。 例子：

```lua
path.extname('index')
--returns ''
```

## path.isAbsolute

    path.isAbsolute(path)

判定path是否为绝对路径。一个绝对路径总是指向一个相同的位置，无论当前工作目录是在哪里。

Posix 示例:

```lua
path.isAbsolute('/foo/bar') -- true
path.isAbsolute('/baz/..')  -- true
path.isAbsolute('qux/')     -- false
path.isAbsolute('.')        -- false
```

Windows 示例:

```lua
path.isAbsolute('//server')  -- true
path.isAbsolute('C:/foo/..') -- true
path.isAbsolute('bar\\baz')   -- false
path.isAbsolute('.')         -- false
```

## path.normalize

     path.normalize(p)

规范化字符串路径，注意 '..' 和 `'.' 部分

多个斜杠会被替换成一个； 路径末尾的斜杠会被保留； Windows 系统上, 会使用反斜杠。

实例：

```lua
path.normalize('/foo/bar//baz/asdf/quux/..')
-- returns '/foo/bar/baz/asdf'
```

## path.join

    path.join([path1], [path2], [...])

连接所有参数, 并且规范化得到的路径.

参数必须是字符串。否则将会抛出一个异常。

实例：

```lua
path.join('foo', {}, 'bar')
-- 抛出异常 TypeError: Arguments to path.join must be strings
```

## path.relative

    path.relative(from, to)

破解从from到to的相对路径。

有时我们有2个绝对路径, 我们需要从中找出相对目录的起源目录。这完全是path.resolve的相反实现,我们可以看看是什么意思:

    path.resolve(from, path.relative(from, to)) == path.resolve(to)

示例:

```lua
path.relative('/data/orandea/test/aaa', '/data/orandea/impl/bbb')
-- returns '../../impl/bbb'
```

## path.resolve

    path.resolve([from ...], to)

把 to 解析为一个绝对路径。

如果to不是一个相对于from 参数的绝对路径，to会被添加到from的右边，直到找出一个绝对路径为止。如果使用from路径且仍没有找到绝对路径时，使用当时路径作为目录。返回的结果已经规范化，得到的路径会去掉结尾的斜杠，除非得到的当前路径为root目录。非字符串参数将被忽略。

另一种思路, 是把它看做一系列 cd 命令.

    path.resolve('foo/bar', '/tmp/file/', '..', 'a/../subfile')

相当于:

```
cd foo/bar
cd /tmp/file/
cd ..
cd a/../subfile
pwd
```

不同的是，不同的路径不需要存在的，也可能是文件。

示例:

```lua
path.resolve('wwwroot', 'static_files/png/', '../gif/image.gif')
-- 如果当前工作目录为 /home/myself/node，它返回：
-- '/home/myself/node/wwwroot/static_files/gif/image.gif'
```

## path.delimiter

特定平台的路径分隔符, ; 或者 ':'.

*nix 上的例子:

```lua
process.env.PATH.split(path.delimiter)
-- returns ['/usr/bin', '/bin', '/usr/sbin', '/sbin', '/usr/local/bin']
```

Windows 上的例子:

```lua
print(process.env.PATH)
-- 'C:\Windows\system32;C:\Windows;C:\Program Files\nodejs\'

process.env.PATH.split(path.delimiter)
-- returns ['C:\Windows\system32', 'C:\Windows', 'C:\Program Files\nodejs\']

```

## path.sep

特定平台的文件分隔工具. '\' 或者 '/'.

*nix 上的例子:

```lua
'foo/bar/baz'.split(path.sep)
-- returns ['foo', 'bar', 'baz']
```

Windows 上的例子:

```lua
'foo\\bar\\baz'.split(path.sep)
-- returns ['foo', 'bar', 'baz']
```

