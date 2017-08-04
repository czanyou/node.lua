# 文件系统 (file system)

[TOC]

文件系统模块是一个简单包装的标准 POSIX 文件 I/O 操作方法集。您可以通过调用 require('fs')来获取该模块。文件系统模块中的所有方法均有异步和同步版本。

文件系统模块中的异步方法需要一个完成时的回调函数作为最后一个传入形参. 回调函数的构成由您调用的异步方法所决定, 通常情况下回调函数的第一个形参为返回的错误信息. 如果异步操作执行正确并返回, 该错误形参则为null或者undefined。

如果您使用的是同步版本的操作方法, 则一旦出现错误, 会以通常的抛出错误的形式返回错误. 你可以用try和catch等语句来拦截错误并使程序继续进行。

这里是一个异步版本的例子：

```lua
fs.unlink('/tmp/hello', function (err) 
  if (err) return nil, err
  print('successfully deleted /tmp/hello')
end);
```

这是同步版本的例子:

```lua
fs.unlinkSync('/tmp/hello')
print('successfully deleted /tmp/hello')
```

当使用异步版本时不能保证执行顺序,因此下面这个例子很容易出错:

```lua
fs.rename('/tmp/hello', '/tmp/world', function (err) 
  if (err) return nil, err
  print('renamed complete')
end)
fs.stat('/tmp/world', function (err, stats) 
  if (err) return nil, err
  print('stats: ' + JSON.stringify(stats))
end);
```

fs.stat有可能在fs.rename前执行.要等到正确的执行顺序应该用下面的方法:

```lua
fs.rename('/tmp/hello', '/tmp/world', function (err) 
  if (err) return nil, err
  fs.stat('/tmp/world', function (err, stats) {
    if (err) return nil, err
    print('stats: ' + json.stringify(stats))
  end)
end)
```

在繁重的任务中,强烈推荐使用这些函数的异步版本.同步版本会阻塞进程,直到完成处理,也就是说会暂停所有的连接.

可以使用文件名的相对路径, 但是记住这个路径是相对于process.cwd()的.

大部分的文件系统(fs)函数可以忽略回调函数(callback)这个参数.如果忽略它,将会由一个默认回调函数(callback)来重新抛出(rethrow)错误.要获得原调用点的堆栈跟踪(trace)信息,需要在环境变量里设置NODE_DEBUG.

```lua
$ env NODE_DEBUG=fs node script.js
fs.js:66
        throw err;
              ^
Error: EISDIR, read
    at rethrow (fs.js:61:21)
    at maybeCallback (fs.js:79:42)
    at Object.fs.readFile (fs.js:153:18)
    at bad (/path/to/script.js:2:17)
    at Object.<anonymous> (/path/to/script.js:5:1)
    <etc.>

fs.rename(oldPath, newPath, callback)#
```

异步版本的rename函数(2).完成时的回调函数(callback)只接受一个参数:可能出现的异常信息.

## fs.appendFile

    fs.appendFile(filename, data, [options], callback)

- filename {String}
- data {String | Buffer}
- options {Object}
    - encoding {String | Null} default = 'utf8'
    - mode {Number} default = 438 (aka 0666 in Octal)
    - flag {String} default = 'a'
- callback {Function}

异步的将数据添加到一个文件的尾部, 如果文件不存在, 会创建一个新的文件. data 可以是一个string, 也可以是原生buffer。

实例：

```lua
fs.appendFile('message.txt', 'data to append', function (err) 
  if (err) then return nil, err
  print('The "data to append" was appended to file!') --数据被添加到文件的尾部
end)
```

## fs.appendFileSync

    fs.appendFileSync(filename, data, [options])

fs.appendFile 的同步版本。

## fs.chmod

    fs.chmod(path, mode, callback)

异步版的 chmod(2). 完成时的回调函数 (callback) 只接受一个参数: 可能出现的异常信息.

## fs.chmodSync

    fs.chmodSync(path, mode)

同步版的 chmod(2).

## fs.chownSync

    fs.chownSync(path, uid, gid)

同步版本的chown(2).

## fs.close

    fs.close(fd, callback)

异步版 close(2). 完成时的回调函数(callback)只接受一个参数: 可能出现的异常信息.

## fs.closeSync
 
     fs.closeSync(fd)

同步版的 close(2).

## fs.exists

    fs.exists(path, callback)

检查指定路径的文件或者目录是否存在。接着通过 callback 传入的参数指明存在 (true) 或者不存在 (false)。示例:

```lua
fs.exists('/etc/passwd', function (exists) 
  util.debug(exists and "存在" or "不存在!")
end)
```

## fs.existsSync

    fs.existsSync(path)

fs.exists 函数的同步版。

## fs.fchmod

    fs.fchmod(fd, mode, callback)

异步版的 fchmod(2). 完成时的回调函数(callback)只接受一个参数:可能出现的异常信息.

## fs.fchmodSync

    fs.fchmodSync(fd, mode)

同步版的 fchmod(2).

## fs.fchown

    fs.fchown(fd, uid, gid, callback)

异步版本的fchown(2)。回调函数的参数除了出现错误时有一个错误对象外, 没有其它参数。

## fs.fchownSync

    fs.fchownSync(fd, uid, gid)

同步版本的fchown(2).

## fs.fstat

    fs.fstat(fd, callback)

异步版的 fstat(2). 回调函数（callback）接收两个参数： (err, stats) 其中 stats 是一个 fs.Stats 对象. fstat() 与 stat() 相同, 区别在于： 要读取的文件（译者注：即第一个参数）是一个文件描述符（file descriptor） fd 。

## fs.fstatSync

    fs.fstatSync(fd)

同步版的 fstat(2). 返回一个 fs.Stats 实例。

## fs.fsync

    fs.fsync(fd, callback)

异步版本的 fsync(2)。回调函数仅含有一个异常 (exception) 参数。

## fs.fsyncSync

    fs.fsyncSync(fd)

fsync(2) 的同步版本。

## fs.ftruncate

    fs.ftruncate(fd, len, callback)

异步版本的ftruncate(2). 完成时的回调函数(callback)只接受一个参数:可能出现的异常信息.

## fs.ftruncateSync

    fs.ftruncateSync(fd, len)

同步版本的ftruncate(2).

## fs.futimes

    fs.futimes(fd, atime, mtime, callback)

## fs.futimesSync

    fs.futimesSync(fd, atime, mtime)

更改文件描述符 (file discriptor) 所指向的文件的时间戳。

## fs.lchown

    fs.lchown(path, uid, gid, callback)

异步版的lchown(2)。完成时的回调函数(callback)只接受一个参数:可能出现的异常信息.

## fs.lchownSync

    fs.lchownSync(path, uid, gid)

同步版本的lchown(2).

## fs.lchmod

    fs.lchmod(path, mode, callback)

异步版的 lchmod(2). 完成时的回调函数(callback)只接受一个参数:可能出现的异常信息.

仅在 Mac OS X 系统下可用。

## fs.lchmodSync

    fs.lchmodSync(path, mode)

同步版的 lchmod(2).

## fs.link

    fs.link(srcpath, dstpath, callback)

异步版的 link(2). 完成时的回调函数（callback）只接受一个参数：可能出现的异常信息。

## fs.linkSync

    fs.linkSync(srcpath, dstpath)

同步版的 link(2).

## fs.lstat

    fs.lstat(path, callback)

异步版的 lstat(2). 回调函数（callback）接收两个参数： (err, stats) 其中 stats 是一个 fs.Stats 对象. lstat() 与 stat() 相同, 区别在于： 若 path 是一个符号链接时（symbolic link）,读取的是该符号链接本身, 而不是它所 链接到的文件。

## fs.lstatSync

    fs.lstatSync(path)

同步版的 lstat(2). 返回一个 fs.Stats 实例。

## fs.mkdir

    fs.mkdir(path, [mode], callback)

异步版的 mkdir(2). 完成时的回调函数（callback）只接受一个参数：可能出现的异常信息。文件 mode 默认为 0777。

## fs.mkdirSync

    fs.mkdirSync(path, [mode])

同步版的 mkdir(2)。

## fs.open

     fs.open(path, flags, [mode], callback)

异步版的文件打开. 详见 open(2). flags 可以是:

- 'r'  - 以【只读】的方式打开文件. 当文件不存在时产生异常.
- 'r+' - 以【读写】的方式打开文件. 当文件不存在时产生异常.
- 'rs' - 同步模式下, 以【只读】的方式打开文件. 

    指令绕过操作系统的本地文件系统缓存.

    该功能主要用于打开 NFS 挂载的文件, 因为它可以让你跳过默认使用的过时本地缓存. 但这实际上非常影响 I/O 操作的性能, 因此除非你确实有这样的需求, 否则请不要使用该标志.

    注意: 这并不意味着 fs.open() 变成了一个同步阻塞的请求. 如果你想要一个同步阻塞的请求你应该使用 fs.openSync().

'rs+' - 同步模式下, 以【读写】的方式打开文件. 请谨慎使用该方式, 详细请查看 'rs' 的注释.

- 'w' - 以【只写】的形式打开文件. 文件会被创建 (如果文件不存在) 或者覆盖 (如果存在).
- 'wx' - 类似 'w' 区别是如果文件存在则操作会失败.
- 'w+' - 以【读写】的方式打开文件. 文件会被创建 (如果文件不存在) 或者覆盖 (如果存在).
- 'wx+' - 类似 'w+' 区别是如果文件存在则操作会失败.

- 'a' - 以【附加】的形式打开文件, 即新写入的数据会附加在原来的文件内容之后. 如果文件不存在则会默认创建.
- 'ax' - 类似 'a' 区别是如果文件存在则操作会失败.
- 'a+' - 以【读取】和【附加】的形式打开文件. 如果文件不存在则会默认创建.
- 'ax+' - 类似 'a+' 区别是如果文件存在则操作会失败.

参数 mode 用于设置文件模式 (permission and sticky bits), 不过前提是这个文件是已存在的. 默认情况下是 0666, 有可读和可写权限.

该 callback 接收两个参数 (err, fd).

排除 (exclusive) 标识 'x'（对应 open(2) 的 O_EXCL 标识） 保证 path 是一个新建的文件. POSIX 操作系统上, 即使 path 是一个指向不存在位置的符号链接, 也会被认定为文件存在. 排除标识在网络文件系统不能确定是否有效。

在 Linux 上, 无法对以追加 (append) 模式打开的文件进行指定位置的写入操作. 内核会忽略位置参数并且总是将数据追加到文件尾部。

## fs.openSync

    fs.openSync(path, flags, [mode])

fs.open() 的同步版.

## fs.readdir

    fs.readdir(path, callback)

异步版的 readdir(3). 读取 path 路径所在目录的内容. 回调函数 (callback) 接受两个参数 (err, files) 其中 files 是一个存储目录中所包含的文件名称的数组, 数组中不包括 '.' 和 '..'。

## fs.readdirSync

    fs.readdirSync(path)

同步版的 readdir(3). 返回文件名数组, 其中不包括 '.' 和 '..' 目录.

## fs.read

    fs.read(fd, buffer, offset, length, position, callback)

从指定的文档标识符fd读取文件数据。

- buffer 是缓冲区, 数据将会写入这里。
- offset 是开始向缓冲区 buffer 写入的偏移量。
- length 是一个整形值, 指定了读取的字节数。
- position 是一个整形值, 指定了从哪里开始读取文件, 如果 position 为 null, 将会从文件当前的位置读取数据。

- callback 回调函数给定了三个参数,  (err, bytesRead, buffer),  分别为错误, 读取的字节和缓冲区。

## fs.readFile

    fs.readFile(filename, [options], callback)

- filename {String}
- options {Object}
    + flag {String} default = 'r'
- callback {Function}

异步读取一个文件的全部内容。举例：

```lua
fs.readFile('/etc/passwd', function (err, data)
  if (err) return nil, err;
  print(data);
end)
```

回调函数传递了两个参数 (err, data), data 就是文件的内容。

如果未指定编码方式, 原生buffer就会被返回。

## fs.readFileSync

    fs.readFileSync(filename, [options])

fs.readFile的同步版本. 返回文件名为 filename 的文件内容。

如果 encoding 选项被指定,  那么这个函数返回一个字符串。如果未指定, 则返回一个原生buffer。

## fs.readlink

    fs.readlink(path, callback)

异步版的 readlink(2). 回调函数（callback）接收两个参数： (err, linkString).

## fs.readlinkSync

    fs.readlinkSync(path)

同步版的 readlink(2). 返回符号链接（symbolic link）的字符串值。

## fs.readSync

    fs.readSync(fd, buffer, offset, length, position)

fs.read 函数的同步版本. 返回bytesRead的个数。

## fs.realpath

    fs.realpath(path, [cache], callback)

异步版的 realpath(2). 回调函数（callback）接收两个参数： (err, resolvedPath). May use process.cwd to resolve relative paths. cache is an object literal of mapped paths that can be used to force a specific path resolution or avoid additional fs.stat calls for known real paths.

实例：

```lua
local cache = {'/etc':'/private/etc'};
fs.realpath('/etc/passwd', cache, function (err, resolvedPath)
  if (err) return nil, err;
  print(resolvedPath)
end)
```

## fs.realpathSync

    fs.realpathSync(path, [cache])

realpath(2) 的同步版本。返回解析出的路径。

## fs.renameSync

    fs.renameSync(oldPath, newPath)

同步版本的rename(2).

## fs.rmdir

    fs.rmdir(path, callback)

异步版的 rmdir(2).  完成时的回调函数（callback）只接受一个参数：可能出现的异常信息。

## fs.rmdirSync

    fs.rmdirSync(path)

同步版的 rmdir(2).

## fs.stat

    fs.stat(path, callback)

异步版的 stat(2). 回调函数（callback） 接收两个参数： (err, stats) , 其中 stats 是一个 fs.Stats 对象. 详情请参考 fs.Stats

## fs.statSync
 
    fs.statSync(path)

同步版的 stat(2). 返回一个 fs.Stats 实例。

## fs.symlink

    fs.symlink(srcpath, dstpath, [type], callback)

异步版的 symlink(2). 完成时的回调函数（callback）只接受一个参数：可能出现的异常信息. type 可以是 'dir', 'file', 或者'junction' (默认是 'file'), 此参数仅用于 Windows 系统（其他系统平台会被忽略）. 注意： Windows 系统要求目标路径（译者注：即 dstpath 参数）必须是一个绝对路径, 当使用 'junction' 时, dstpath 参数会自动转换为绝对路径。

## fs.symlinkSync

    fs.symlinkSync(srcpath, dstpath, [type])

同步版的 symlink(2).

## fs.truncate

    fs.truncate(path, len, callback)

异步版本的truncate(2). 完成时的回调函数(callback)只接受一个参数:可能出现的异常信息.

## fs.truncateSync

    fs.truncateSync(path, len)

同步版本的truncate(2).

异步版本的chown.完成时的回调函数(callback)只接受一个参数:可能出现的异常信息.

异步版本的chown(2).完成时的回调函数(callback)只接受一个参数:可能出现的异常信息.

## fs.unlink

    fs.unlink(path, callback)

异步版的 unlink(2). 完成时的回调函数（callback）只接受一个参数：可能出现的异常信息.

## fs.unlinkSync

    fs.unlinkSync(path)

同步版的 unlink(2).

## fs.utimes

    fs.utimes(path, atime, mtime, callback)

## fs.utimesSync

    fs.utimesSync(path, atime, mtime)

更改 path 所指向的文件的时间戳。

## fs.write

    fs.write(fd, buffer, offset, length[, position], callback)

通过文件标识fd, 向指定的文件中写入buffer。


offset 和length 可以确定从哪个位置开始写入buffer。


position 是参考当前文档光标的位置, 然后从该处写入数据。如果typeof position !== 'number', 那么数据会从当前文档位置写入, 请看pwrite(2)。


回调中会给出三个参数 (err, written, buffer), written 说明从buffer写入的字节数。


注意, fs.write多次地在同一个文件中使用而没有等待回调是不安全的。在这种情况下, 强烈推荐使用fs.createWriteStream。


在 Linux 上, 无法对以追加 (append) 模式打开的文件进行指定位置的写入操作. 内核会忽略位置参数并且总是将数据追加到文件尾部。


## fs.write

    fs.write(fd, data[, position[, encoding]], callback)

把data写入到文档中通过指定的fd,如果data不是buffer对象的实例则会把值强制转化成一个字符串。

position 是参考当前文档光标的位置, 然后从该处写入数据。如果typeof position !== 'number', 那么数据会从当前文档位置写入, 请看pwrite(2)。

encoding 是预期得到一个字符串编码

回调会得到这些参数 (err, written, string), written表明传入的string需要写入的字符串长度。注意字节的写入跟字符串写入是不一样的。请看Buffer.byteLength.

与写入buffer不同, 必须写入完整的字符串, 截取字符串不是符合规定的。这是因为返回的字节的位移跟字符串的位移是不一样的。

注意, fs.write多次地在同一个文件中使用而没有等待回调是不安全的。在这种情况下, 强烈推荐使用fs.createWriteStream。

在 Linux 上, 无法对以追加 (append) 模式打开的文件进行指定位置的写入操作. 内核会忽略位置参数并且总是将数据追加到文件尾部。

## fs.writeFile

    fs.writeFile(filename, data, [options], callback)

- filename {String}
- data {String | Buffer}
- options {Object}
    + mode {Number} default = 438 (aka 0666 in Octal)
    + flag {String} default = 'w'
- callback {Function}

异步的将数据写入一个文件, 如果文件原先存在, 会被替换. data 可以是一个string, 也可以是一个原生buffer。

实例：

```lua
fs.writeFile('message.txt', 'Hello Node', function (err) 
  if (err) return nil, err
  print('It\'s saved!') --文件被保存
end);
```

## fs.writeFileSync

    fs.writeFileSync(filename, data, [options])

fs.writeFile的同步版本。

## fs.writeSync

    fs.writeSync(fd, buffer, offset, length[, position])
    fs.writeSync(fd, data[, position[, encoding]])

同步版本的fs.write()。返回写入的字节数。

## fs.watchFile

    fs.watchFile(filename, [options], listener)

尽可能的话推荐使用 fs.watch 来代替。

监视 filename 指定的文件的改变. 回调函数 listener 会在文件每一次被访问时被调用。

第二个参数是可选的。如果提供此参数, options 应该是包含两个成员 persistent 和 interval 的对象, 其中 persistent 值为 boolean 类型。persistent 指定进程是否应该在文件被监视（watch）时继续运行, interval 指定了目标文件被查询的间隔, 以毫秒为单位。缺省值为 { persistent: true, interval: 5007 }。

listener 有两个参数, 第一个为文件现在的状态, 第二个为文件的前一个状态。

```lua
fs.watchFile('message.text', function (curr, prev) 
  print('the current mtime is: ' + curr.mtime)
  print('the previous mtime was: ' + prev.mtime)
end)
```

listener中的文件状态对象类型为 fs.Stat。

如果你只想在文件被修改时被告知, 而不是仅仅在被访问时就告知, 你应当在 listener 回调函数中比较下两个状态对象的 mtime 属性。即 curr.mtime 和 prev.mtime.

## fs.unwatchFile

    fs.unwatchFile(filename, [listener])

尽可能的话推荐使用 fs.watch 来代替。

停止监视文件名为 filename的文件. 如果 listener 参数被指定, 会移除在 fs.watchFile 函数中指定的那一个 listener 回调函数. 否则, 所有的 回调函数都会被移除, 你将彻底停止监视 filename 文件。

调用 fs.unwatchFile() 时, 传递的文件名为未被监视的文件时, 不会发生错误, 而会发生一个no-op。

## fs.watch

    fs.watch(filename, [options], [listener])

观察指定路径的改变, filename 路径可以是文件或者目录。改函数返回的对象是 fs.FSWatcher。

第二个参数是可选的. 如果 options 选项被提供那么它应当是一个只包含成员 persistent 的对象,  persistent 为 boolean 类型。persistent 指定了进程是否 “只要文件被监视就继续执行” 缺省值为 { persistent: true }.

监听器的回调函数得到两个参数 (event, filename)。其中 event 是 'rename'（重命名）或者 'change'（改变）, 而 filename 则是触发事件的文件名。

### 注意事项

fs.watch 不是完全跨平台的, 且在某些情况下不可用。

### 可用性

此功能依赖于操作系统底层提供的方法来监视文件系统的变化。

- 在 Linux 操作系统上, 使用 inotify。
- 在 BSD 操作系统上 (包括 OS X), 使用 kqueue。
- 在 SunOS 操作系统上 (包括 Solaris 和 SmartOS), 使用 event ports。
- 在 Windows 操作系统上, 该特性依赖于 ReadDirectoryChangesW。

如果系统底层函数出于某些原因不可用, 那么 fs.watch 也就无法工作。例如, 监视网络文件系统(如 NFS, SMB 等)的文件或者目录, 就时常不能稳定的工作, 有时甚至完全不起作用。

你仍然可以调用使用了文件状态调查的 fs.watchFile, 但是会比较慢而且比较不可靠。

### 文件名参数

在回调函数中提供的 filename 参数不是在每一个操作系统中都被支持（当下仅在 Linux 和 Windows 上支持）. 即便是在支持的系统中, filename 也不能保证在每一次回调都被提供。因此, 不要假设filename参数总会会在 回调函数中提供, 在回调函数中添加检测 filename 是否为 null 的 if 判断语句。

```lua
fs.watch('somedir', function (event, filename) 
  print('event is: ' + event)
  if (filename) then
    print('filename provided: ' + filename)
  else
    print('filename not provided')
  end
end);
```

## Class: fs.Stats

fs.stat(), fs.lstat() 和 fs.fstat() 以及他们对应的同步版本返回的对象。

- stats.isFile()
- stats.isDirectory()
- stats.isBlockDevice()
- stats.isCharacterDevice()
- stats.isSymbolicLink() (仅在与 fs.lstat()一起使用时合法)
- stats.isFIFO()
- stats.isSocket()

对于一个普通文件使用 util.inspect(stats) 将会返回一个类似如下输出的字符串：

```lua
{ dev: 2114,
  ino: 48064969,
  mode: 33188,
  nlink: 1,
  uid: 85,
  gid: 100,
  rdev: 0,
  size: 527,
  blksize: 4096,
  blocks: 8,
  atime: Mon, 10 Oct 2011 23:24:11 GMT,
  mtime: Mon, 10 Oct 2011 23:24:11 GMT,
  ctime: Mon, 10 Oct 2011 23:24:11 GMT,
  birthtime: Mon, 10 Oct 2011 23:24:11 GMT }
```

请注意 atime, mtime, birthtime, and ctime 是 Date 对象的实例。而且在比较这些对象的值时你应当使用合适的方法. 大部分情况下, 使用 getTime() 将会返回自 1 January 1970 00:00:00 UTC 以来逝去的毫秒数,  而且这个整形值应该能满足任何比较的使用条件。但是仍然还有一些额外的方法可以用来显示一些模糊的信息。

### Stat Time Values

在状态对象（stat object）中的时间有以下语义：

- atime "Access Time" - 文件数据上次被访问的时间.
会被 mknod(2), utimes(2), and read(2) 等系统调用改变。
- mtime "Modified Time" - 文件上次被修改的时间. 会被 mknod(2), utimes(2), and write(2) 等系统调用改变。
- ctime "Change Time" - 文件状态上次改变的时间. (inode data modification). 会被 chmod(2), chown(2), link(2), mknod(2), rename(2), unlink(2), utimes(2), read(2), and write(2) 等系统调用改变。
- birthtime "Birth Time" - 文件被创建的时间. 会在文件被创建时生成. 在一些不提供文件birthtime的文件系统中, 这个字段会被 ctime 或 1970-01-01T00:00Z (ie, unix epoch timestamp 0)来填充. 在 Darwin 和其他 FreeBSD 系统变体中, 也将 atime 显式地设置成比它现在的 birthtime 更早的一个时间值, 这个过程使用了utimes(2)系统调用。

## fs.createReadStream

    fs.createReadStream(path, [options])

返回一个新的 ReadStream 对象 (详见 Readable Stream).

options 是一个包含下列缺省值的对象：

```lua
{ flags: 'r',
  encoding: null,
  fd: null,
  mode: 0666,
  autoClose: true
}
```

options 可以提供 start 和 end 值用于读取文件内的特定范围而非整个文件. start 和 end 都是包含在范围内的（inclusive, 可理解为闭区间）并且以 0 开始. encoding 可选为 'utf8', 'ascii' 或者 'base64'。


如果 autoClose 为 false 则即使在发生错误时也不会关闭文件描述符 (file descriptor). 此时你需要负责关闭文件, 避免文件描述符泄露 (leak). 如果 autoClose 为 true （缺省值）,  当发生 error 或者 end 事件时, 文件描述符会被自动释放。


一个从100字节的文件中读取最后10字节的例子：

    fs.createReadStream('sample.txt', {start: 90, end: 99});

## Class: fs.ReadStream

ReadStream 是一个可读的流(Readable Stream).

### 事件: 'open'

- fd number ReadStream 所使用的文件描述符。

当文件的 ReadStream 被创建时触发。

## fs.createWriteStream

    fs.createWriteStream(path, [options])

返回一个新的 WriteStream 对象 (详见 Writable Stream).

options 是一个包含下列缺省值的对象：

```lua
{ flags: 'w',
  encoding: null,
  mode: 0666 }
```

options 也可以包含一个 start 选项用于指定在文件中开始写入数据的位置. 修改而不替换文件需要 flags 的模式指定为 r+ 而不是默值的 w.

## Class: fs.WriteStream

WriteStream 是一个可写的流(Writable Stream).

### 事件: 'open'

fd number WriteStream 所使用的文件描述符。

当 WriteStream 创建时触发。

### file.bytesWritten

已写的字节数。不包含仍在队列中准备写入的数据。


## Class: fs.FSWatcher

fs.watch() 返回的对象类型。

### 事件: 'change'

- event string fs 改变的类型
- filename string 改变的文件名 (if relevant/available)

当正在观察的目录或文件发生变动时触发。更多细节, 详见 fs.watch。

### 事件: 'error'

- error {Error 对象}

当产生错误时触发

### watcher.close

    watcher.close()

停止观察 fs.FSWatcher 对象中的更改。
