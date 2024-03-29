--[[

Copyright 2012 The Luvit Authors. All Rights Reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

	http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS-IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

--]]

local path = require('path')

local path_base  = require('path')
local deepEqual = require('assert').isDeepEqual

local isWindows = os.platform() == "win32"

-- Test that path is set correctly for the current OS
if not isWindows then
  assert(path._internal == path_base.posix)
else
  assert(path._internal == path_base.nt)
end

local tap = require('util/tap')
local test = tap.test

test('path tests', function()
	-- Test path.dirname
	assert(path_base.posix:dirname('/usr/bin/vim') == '/usr/bin')
	assert(path_base.posix:dirname('/usr/bin/') == '/usr')
	assert(path_base.posix:dirname('/usr/bin') == '/usr')
	assert(path_base.posix:dirname('////') == '/')
	assert(path_base.nt:dirname('C:\\') == 'C:\\')
	assert(path_base.nt:dirname('C:\\Users\\philips\\vim.exe') == 'C:\\Users\\philips')
	assert(path_base.nt:dirname('C:/Users/philips/vim.exe') == 'C:\\Users\\philips')
	assert(path_base.nt:dirname('D:\\Users\\philips\\vim.exe') == 'D:\\Users\\philips')
	assert(path_base.nt:dirname('D:/Users/philips/vim.exe') == 'D:\\Users\\philips')
	assert(path_base.nt:dirname('\\\\server\\share\\Users\\philips\\vim.exe') == '\\\\server\\share\\Users\\philips')
	assert(path_base.nt:dirname('//server/share/Users/philips/vim.exe') == '\\\\server\\share\\Users\\philips')
	assert(path_base.nt:dirname('C:\\Users\\philips\\') == 'C:\\Users')
	assert(path_base.nt:dirname('C:/Users/philips/') == 'C:\\Users')
	assert(path_base.nt:dirname('D:\\Users\\philips\\') == 'D:\\Users')
	assert(path_base.nt:dirname('D:/Users/philips/') == 'D:\\Users')
	assert(path_base.nt:dirname('\\\\server') == '\\\\server\\')
	assert(path_base.nt:dirname('\\\\server\\') == '\\\\server\\')
	assert(path_base.nt:dirname('\\\\server\\share') == '\\\\server\\share\\')
	assert(path_base.nt:dirname('\\\\server\\share\\Users\\philips\\') == '\\\\server\\share\\Users')
	assert(path_base.nt:dirname('//server/share/Users/philips/') == '\\\\server\\share\\Users')
	assert(path_base.nt:dirname('\\\\server\\share\\') == '\\\\server\\share\\')
	assert(path_base.nt:dirname('//server/share/') == '\\\\server\\share\\')
	assert(path_base.nt:dirname('d:drive\\relative') == 'd:drive')
	assert(path_base.nt:dirname('d:driverelative') == 'd:')
	assert(path_base.nt:dirname('d:') == 'd:\\')

	-- test path.basename
	assert(path.basename('bar.lua') == 'bar.lua')
	assert(path.basename('bar.lua', '.lua') == 'bar')
	assert(path.basename('bar.lua.js', '.lua') == 'bar.lua.js')
	assert(path.basename('.lua', 'lua') == '.')
	assert(path.basename('bar', '.lua') == 'bar')
	assert(path.basename('') == '')
	assert(path.basename('basename.ext/') == 'basename.ext')
	assert(path.basename('basename.ext//') == 'basename.ext')

	-- test path.basename os specifics
	assert(path_base.posix:basename('/foo/bar.lua') == 'bar.lua')
	assert(path_base.posix:basename('/foo/bar.lua', '.lua') == 'bar')
	assert(path_base.nt:basename('c:\\foo\\bar.lua') == 'bar.lua')
	assert(path_base.nt:basename('c:/foo/bar.lua') == 'bar.lua')
	assert(path_base.nt:basename('c:\\foo\\bar.lua', '.lua') == 'bar')
	assert(path_base.nt:basename('c:/foo/bar.lua', '.lua') == 'bar')
	assert(path_base.nt:basename('D:\\foo\\bar.lua') == 'bar.lua')
	assert(path_base.nt:basename('D:/foo/bar.lua') == 'bar.lua')
	assert(path_base.nt:basename('D:\\foo\\bar.lua', '.lua') == 'bar')
	assert(path_base.nt:basename('D:/foo/bar.lua', '.lua') == 'bar')
	assert(path_base.nt:basename('\\\\server\\share\\bar.lua') == 'bar.lua')
	assert(path_base.nt:basename('//server/share/bar.lua') == 'bar.lua')
	assert(path_base.nt:basename('\\\\server\\share\\bar.lua', '.lua') == 'bar')
	assert(path_base.nt:basename('//server/share/bar.lua', '.lua') == 'bar')
	assert(path_base.nt:basename('basename.ext\\') == 'basename.ext')
	assert(path_base.nt:basename('basename.ext\\\\') == 'basename.ext')

	-- posix treats backslash as any other character
	assert(path_base.posix:basename('basename.ext\\') == 'basename.ext\\');
	assert(path_base.posix:basename('basename.ext\\\\') == 'basename.ext\\\\');

	-- posix filenames may include control characters
	assert(path_base.posix:basename("/foo/bar/"..string.char(13)) == string.char(13))

	-- test path.extname
	assert(path.extname('') == '')
	assert(path.extname('/path/to/file') == '')
	assert(path.extname('/path/to/file.ext') == '.ext')
	assert(path.extname('/path.to/file.ext') == '.ext')
	assert(path.extname('/path.to/file') == '')
	assert(path.extname('/path.to/.file') == '')
	assert(path.extname('/path.to/.file.ext') == '.ext')
	assert(path.extname('/path/to/f.ext') == '.ext')
	assert(path.extname('/path/to/..ext') == '.ext')
	assert(path.extname('file') == '')
	assert(path.extname('file.ext') == '.ext')
	assert(path.extname('.file') == '')
	assert(path.extname('.file.ext') == '.ext')
	assert(path.extname('/file') == '')
	assert(path.extname('/file.ext') == '.ext')
	assert(path.extname('/.file') == '')
	assert(path.extname('/.file.ext') == '.ext')
	assert(path.extname('.path/file.ext') == '.ext')
	assert(path.extname('file.ext.ext') == '.ext')
	assert(path.extname('file.') == '.')
	assert(path.extname('.') == '')
	assert(path.extname('./') == '')
	assert(path.extname('.file.ext') == '.ext')
	assert(path.extname('.file') == '')
	assert(path.extname('.file.') == '.')
	assert(path.extname('.file..') == '.')
	assert(path.extname('..') == '')
	assert(path.extname('../') == '')
	assert(path.extname('..file.ext') == '.ext')
	assert(path.extname('..file') == '.file')
	assert(path.extname('..file.') == '.')
	assert(path.extname('..file..') == '.')
	assert(path.extname('...') == '.')
	assert(path.extname('...ext') == '.ext')
	assert(path.extname('....') == '.')
	assert(path.extname('file.ext/') == '.ext')
	assert(path.extname('file.ext//') == '.ext')
	assert(path.extname('file/') == '')
	assert(path.extname('file//') == '')
	assert(path.extname('file./') == '.')
	assert(path.extname('file.//') == '.')
	assert(path_base.nt:extname('.\\') == '')
	assert(path_base.nt:extname('..\\') == '')
	assert(path_base.nt:extname('file.ext\\') == '.ext')
	assert(path_base.nt:extname('file.ext\\\\') == '.ext')
	assert(path_base.nt:extname('file\\') == '')
	assert(path_base.nt:extname('file\\\\') == '')
	assert(path_base.nt:extname('file.\\') == '.')
	assert(path_base.nt:extname('file.\\\\') == '.')
	-- posix treats backslash as any other character
	assert(path_base.posix:extname('.\\') == '')
	assert(path_base.posix:extname('..\\') == '.\\')
	assert(path_base.posix:extname('file.ext\\') == '.ext\\')
	assert(path_base.posix:extname('file.ext\\\\') == '.ext\\\\')
	assert(path_base.posix:extname('file\\') == '')
	assert(path_base.posix:extname('file\\\\') == '')
	assert(path_base.posix:extname('file.\\') == '.\\')
	assert(path_base.posix:extname('file.\\\\') == '.\\\\')

	-- test path.isAbsolute
	assert(path_base.posix:isAbsolute('/foo/bar.lua'))
	assert(not path_base.posix:isAbsolute('foo/bar.lua'))
	assert(path_base.nt:isAbsolute('c:'))
	assert(path_base.nt:isAbsolute('C:\\foo\\bar.lua'))
	assert(path_base.nt:isAbsolute('C:/foo/bar.lua'))
	assert(path_base.nt:isAbsolute('D:\\foo\\bar.lua'))
	assert(path_base.nt:isAbsolute('D:/foo/bar.lua'))
	assert(not path_base.nt:isAbsolute('foo\\bar.lua'))
	assert(not path_base.nt:isAbsolute('foo/bar.lua'))
	assert(path_base.nt:isAbsolute('\\\\server\\share\\bar.lua'))
	assert(path_base.nt:isAbsolute('//server/share/bar.lua'))
	assert(path_base.nt:isAbsolute('\\\\server\\'))
	assert(path_base.nt:isAbsolute('//server/'))
	assert(not path_base.nt:isAbsolute('c:drive\\relative'))

	-- test path.getRoot
	assert(path_base.posix:getRoot() == '/')
	assert(path_base.posix:getRoot('irrelevant') == '/')
	assert(path_base.nt:getRoot() == 'c:\\')
	assert(path_base.nt:getRoot('C:\\foo\\bar.lua') == 'C:\\')
	assert(path_base.nt:getRoot('C:/foo/bar.lua') == 'C:\\')
	assert(path_base.nt:getRoot('d:\\foo\\bar.lua') == 'd:\\')
	assert(path_base.nt:getRoot('d:/foo/bar.lua') == 'd:\\')
	assert(path_base.nt:getRoot('d:') == 'd:\\')
	assert(path_base.nt:getRoot('\\\\server\\share\\bar.lua') == '\\\\server\\share\\')
	assert(path_base.nt:getRoot('//server/share/bar.lua') == '\\\\server\\share\\')
	assert(path_base.nt:getRoot('\\\\server\\share') == '\\\\server\\share\\')
	assert(path_base.nt:getRoot('//server/share') == '\\\\server\\share\\')
	assert(path_base.nt:getRoot('\\\\server\\') == '\\\\server\\')
	assert(path_base.nt:getRoot('//server/') == '\\\\server\\')
	assert(path_base.nt:getRoot('\\\\server') == '\\\\server\\')
	assert(path_base.nt:getRoot('//server') == '\\\\server\\')
	assert(path_base.nt:getRoot('d:drive\\relative') == 'd:')

	-- test path._splitPath
	assert(deepEqual({"/", "", ""}, {path_base.posix:_splitPath('/')}))
	assert(deepEqual({"/", "", "foo"}, {path_base.posix:_splitPath('/foo')}))
	assert(deepEqual({"/", "", "foo"}, {path_base.posix:_splitPath('/foo/')}))
	assert(deepEqual({"/", "foo/", "bar"}, {path_base.posix:_splitPath('/foo/bar')}))
	assert(deepEqual({"/", "foo/", "bar"}, {path_base.posix:_splitPath('/foo/bar/')}))
	assert(deepEqual({"/", "foo/", "bar.lua"}, {path_base.posix:_splitPath('/foo/bar.lua')}))
	assert(deepEqual({"", "foo/", "bar.lua"}, {path_base.posix:_splitPath('foo/bar.lua')}))
	assert(deepEqual({"C:\\", "", ""}, {path_base.nt:_splitPath('C:\\')}))
	assert(deepEqual({"C:\\", "", "foo"}, {path_base.nt:_splitPath('C:\\foo')}))
	assert(deepEqual({"C:\\", "", "foo"}, {path_base.nt:_splitPath('C:\\foo\\')}))
	assert(deepEqual({"C:\\", "foo\\", "bar.lua"}, {path_base.nt:_splitPath('C:\\foo\\bar.lua')}))
	assert(deepEqual({"d:\\", "foo\\", "bar.lua"}, {path_base.nt:_splitPath('d:\\foo\\bar.lua')}))
	assert(deepEqual({"", "foo\\", "bar.lua"}, {path_base.nt:_splitPath('foo\\bar.lua')}))
	assert(deepEqual({"\\\\server\\share\\", "", "bar.lua"}, {path_base.nt:_splitPath('\\\\server\\share\\bar.lua')}))
	assert(deepEqual({"d:", "drive\\", "relative.lua"}, {path_base.nt:_splitPath('d:drive\\relative.lua')}))

	-- test path._normalizeArray
	local dotArray = {"foo", ".", "bar"}
	path._normalizeArray(dotArray)
	assert(deepEqual({"foo", "bar"}, dotArray))

	local dotdotArray = {"..", "foo", "..", "bar"}
	path._normalizeArray(dotdotArray)
	assert(deepEqual({"bar"}, dotdotArray))

	local dotdotRelativeArray = {"..", "foo", "..", "bar"}
	path._normalizeArray(dotdotRelativeArray, true)
	assert(deepEqual({"..", "bar"}, dotdotRelativeArray))

	-- test path.normalize
	-- trailing slash
	assert(path_base.posix:normalize("foo/bar") == "foo/bar")
	assert(path_base.posix:normalize("foo/bar/") == "foo/bar/")
	assert(path_base.posix:normalize("/foo/bar") == "/foo/bar")
	assert(path_base.posix:normalize("/foo/bar/") == "/foo/bar/")
	assert(path_base.nt:normalize("\\foo\\bar") == "foo\\bar")
	assert(path_base.nt:normalize("/foo/bar") == "foo\\bar")
	assert(path_base.nt:normalize("\\foo\\bar\\") == "foo\\bar\\")
	assert(path_base.nt:normalize("/foo/bar/") == "foo\\bar\\")
	assert(path_base.nt:normalize("C:\\foo\\bar") == "C:\\foo\\bar")
	assert(path_base.nt:normalize("C:/foo/bar") == "C:\\foo\\bar")
	assert(path_base.nt:normalize("C:\\foo\\bar\\") == "C:\\foo\\bar\\")
	assert(path_base.nt:normalize("C:/foo/bar/") == "C:\\foo\\bar\\")
	assert(path_base.nt:normalize("D:\\foo\\bar") == "D:\\foo\\bar")
	assert(path_base.nt:normalize("D:/foo/bar") == "D:\\foo\\bar")
	assert(path_base.nt:normalize("D:\\foo\\bar\\") == "D:\\foo\\bar\\")
	assert(path_base.nt:normalize("D:/foo/bar/") == "D:\\foo\\bar\\")
	assert(path_base.nt:normalize("\\\\server\\share\\bar") == "\\\\server\\share\\bar")
	assert(path_base.nt:normalize("//server/share/bar") == "\\\\server\\share\\bar")
	assert(path_base.nt:normalize("\\\\server\\share\\bar\\") == "\\\\server\\share\\bar\\")
	assert(path_base.nt:normalize("//server/share/bar/") == "\\\\server\\share\\bar\\")
	assert(path_base.nt:normalize("\\\\a") == "\\\\a\\")
	assert(path_base.nt:normalize("//a") == "\\\\a\\")
	assert(path_base.nt:normalize("\\\\a\\b") == "\\\\a\\b\\")
	assert(path_base.nt:normalize("//a/b") == "\\\\a\\b\\")
	-- dot and dotdot
	assert(path_base.posix:normalize("foo/../bar.lua") == "bar.lua")
	assert(path_base.posix:normalize("foo/./bar.lua") == "foo/bar.lua")
	assert(path_base.posix:normalize("/foo/../bar.lua") == "/bar.lua")
	assert(path_base.posix:normalize("/foo/./bar.lua") == "/foo/bar.lua")
	assert(path_base.nt:normalize("foo\\..\\bar.lua") == "bar.lua")
	assert(path_base.nt:normalize("foo/../bar.lua") == "bar.lua")
	assert(path_base.nt:normalize("foo\\.\\bar.lua") == "foo\\bar.lua")
	assert(path_base.nt:normalize("foo/./bar.lua") == "foo\\bar.lua")
	assert(path_base.nt:normalize("C:\\foo\\..\\bar.lua") == "C:\\bar.lua")
	assert(path_base.nt:normalize("C:/foo/../bar.lua") == "C:\\bar.lua")
	assert(path_base.nt:normalize("C:\\foo\\.\\bar.lua") == "C:\\foo\\bar.lua")
	assert(path_base.nt:normalize("C:/foo/./bar.lua") == "C:\\foo\\bar.lua")
	assert(path_base.nt:normalize("D:\\foo\\..\\bar.lua") == "D:\\bar.lua")
	assert(path_base.nt:normalize("D:/foo/../bar.lua") == "D:\\bar.lua")
	assert(path_base.nt:normalize("D:\\foo\\.\\bar.lua") == "D:\\foo\\bar.lua")
	assert(path_base.nt:normalize("D:/foo/./bar.lua") == "D:\\foo\\bar.lua")
	assert(path_base.nt:normalize("/foo/bar") == "foo\\bar")
	assert(path_base.nt:normalize('/foo/../../../bar'), '..\\..\\bar')
	assert(path_base.nt:normalize("\\\\server\\share\\foo\\..\\bar.lua") == "\\\\server\\share\\bar.lua")
	assert(path_base.nt:normalize("//server/share/foo/../bar.lua") == "\\\\server\\share\\bar.lua")
	assert(path_base.nt:normalize("\\\\server\\share\\.\\bar.lua") == "\\\\server\\share\\bar.lua")
	assert(path_base.nt:normalize("//server/share/./bar.lua") == "\\\\server\\share\\bar.lua")
	assert(path_base.nt:normalize("\\\\server\\share\\..\\bar.lua") == "\\\\server\\share\\bar.lua")
	assert(path_base.nt:normalize("//server/share/../bar.lua") == "\\\\server\\share\\bar.lua")
	assert(path_base.nt:normalize("\\\\server\\..\\bar.lua") == "\\\\server\\bar.lua")
	assert(path_base.nt:normalize("//server/../bar.lua") == "\\\\server\\bar.lua")
	-- dot and dotdot only (relative, absolute, with/without trailing slashes)
	assert(path_base.posix:normalize("./") == ".")
	assert(path_base.posix:normalize("../") == "../")
	assert(path_base.posix:normalize("/.") == "/")
	assert(path_base.posix:normalize("/./") == "/")
	assert(path_base.posix:normalize("/..") == "/")
	assert(path_base.posix:normalize("/../") == "/")
	assert(path_base.nt:normalize(".\\") == ".")
	assert(path_base.nt:normalize("./") == ".")
	assert(path_base.nt:normalize("..\\") == "..\\")
	assert(path_base.nt:normalize("../") == "..\\")
	assert(path_base.nt:normalize("C:\\.") == "C:\\")
	assert(path_base.nt:normalize("C:/.") == "C:\\")
	assert(path_base.nt:normalize("C:\\.\\") == "C:\\")
	assert(path_base.nt:normalize("C:/./") == "C:\\")
	assert(path_base.nt:normalize("C:\\..") == "C:\\")
	assert(path_base.nt:normalize("C:/..") == "C:\\")
	assert(path_base.nt:normalize("C:\\..\\") == "C:\\")
	assert(path_base.nt:normalize("C:/../") == "C:\\")
	assert(path_base.nt:normalize("D:\\.") == "D:\\")
	assert(path_base.nt:normalize("D:/.") == "D:\\")
	assert(path_base.nt:normalize("D:\\.\\") == "D:\\")
	assert(path_base.nt:normalize("D:/./") == "D:\\")
	assert(path_base.nt:normalize("D:\\..") == "D:\\")
	assert(path_base.nt:normalize("D:/..") == "D:\\")
	assert(path_base.nt:normalize("D:\\..\\") == "D:\\")
	assert(path_base.nt:normalize("D:/../") == "D:\\")
	assert(path_base.nt:normalize("\\\\server\\.") == "\\\\server\\")
	assert(path_base.nt:normalize("//server/.") == "\\\\server\\")
	assert(path_base.nt:normalize("\\\\server\\.\\") == "\\\\server\\")
	assert(path_base.nt:normalize("//server/./") == "\\\\server\\")
	assert(path_base.nt:normalize("\\\\server\\..") == "\\\\server\\")
	assert(path_base.nt:normalize("//server/..") == "\\\\server\\")
	assert(path_base.nt:normalize("\\\\server\\..\\") == "\\\\server\\")
	assert(path_base.nt:normalize("//server/../") == "\\\\server\\")
	-- drive relative paths stay as drive-relative when normalized
	assert(path_base.nt:normalize('d:drive\\relative') == 'd:drive\\relative')
	assert(path_base.nt:normalize('d:..') == 'd:..')
	assert(path_base.nt:normalize('d:.') == 'd:.')

	-- test path.join
	assert(path_base.posix:join('.', 'foo/bar', '..', '/foo/bar.lua') == 'foo/foo/bar.lua')
	assert(path_base.posix:join('/.', 'foo/bar', '..', '/foo/bar.lua') == '/foo/foo/bar.lua')
	assert(path_base.posix:join('/foo', '../../../bar') == '/bar')
	assert(path_base.posix:join('foo', '../../../bar') == '../../bar')
	assert(path_base.posix:join('foo/', '../../../bar') == '../../bar')
	assert(path_base.posix:join('foo/bar', '../../../bar') == '../bar')
	assert(path_base.posix:join('foo/bar', './bar') == 'foo/bar/bar')
	assert(path_base.posix:join('foo/bar/', './bar') == 'foo/bar/bar')
	assert(path_base.posix:join('foo/bar/', '.', 'bar') == 'foo/bar/bar')
	assert(path_base.posix:join('.', './') == '.')
	assert(path_base.posix:join('.', '.', '.') == '.')
	assert(path_base.posix:join('.', './', '.') == '.')
	assert(path_base.posix:join('.', '/./', '.') == '.')
	assert(path_base.posix:join('.', '/////./', '.') == '.')
	assert(path_base.posix:join('.') == '.')
	assert(path_base.posix:join('', '.') == '.')
	assert(path_base.posix:join('', 'foo') == 'foo')
	assert(path_base.posix:join('foo', '/bar') == 'foo/bar')
	assert(path_base.posix:join('', '/foo') == '/foo')
	assert(path_base.posix:join('', '', '/foo') == '/foo')
	assert(path_base.posix:join('', '', 'foo') == 'foo')
	assert(path_base.posix:join('foo', '') == 'foo')
	assert(path_base.posix:join('foo/', '') == 'foo/')
	assert(path_base.posix:join('foo', '', '/bar') == 'foo/bar')
	assert(path_base.posix:join('./', '..', '/foo') == '../foo')
	assert(path_base.posix:join('./', '..', '..', '/foo') == '../../foo')
	assert(path_base.posix:join('.', '..', '..', '/foo') == '../../foo')
	assert(path_base.posix:join('', '..', '..', '/foo') == '../../foo')
	assert(path_base.posix:join('/') == '/')
	assert(path_base.posix:join('/', '.') == '/')
	assert(path_base.posix:join('/', '..') == '/')
	assert(path_base.posix:join('/', '..', '..') == '/')
	assert(path_base.posix:join('') == '.')
	assert(path_base.posix:join('', '') == '.')
	assert(path_base.posix:join(' /foo') == ' /foo')
	assert(path_base.posix:join(' ', 'foo') == ' /foo')
	assert(path_base.posix:join(' ', '.') == ' ')
	assert(path_base.posix:join(' ', '/') == ' /')
	assert(path_base.posix:join(' ', '') == ' ')
	assert(path_base.posix:join('/', 'foo') == '/foo')
	assert(path_base.posix:join('/', '/foo') == '/foo')
	assert(path_base.posix:join('/', '//foo') == '/foo')
	assert(path_base.posix:join('/', '', '/foo') == '/foo')
	assert(path_base.posix:join('', '/', 'foo') == '/foo')
	assert(path_base.posix:join('', '/', '/foo') == '/foo')
	-- Interpretted as UNC paths
	assert(path_base.nt:join('\\\\foo\\bar') == '\\\\foo\\bar\\')
	assert(path_base.nt:join('//foo/bar') == '\\\\foo\\bar\\')
	assert(path_base.nt:join('\\\\foo', 'bar') == '\\\\foo\\bar\\')
	assert(path_base.nt:join('//foo', 'bar') == '\\\\foo\\bar\\')
	assert(path_base.nt:join('\\\\foo\\', 'bar') == '\\\\foo\\bar\\')
	assert(path_base.nt:join('//foo/', 'bar') == '\\\\foo\\bar\\')
	assert(path_base.nt:join('\\\\foo', '\\bar') == '\\\\foo\\bar\\')
	assert(path_base.nt:join('//foo', '\\bar') == '\\\\foo\\bar\\')
	assert(path_base.nt:join('\\\\foo', '', 'bar') == '\\\\foo\\bar\\')
	assert(path_base.nt:join('//foo', '', 'bar') == '\\\\foo\\bar\\')
	assert(path_base.nt:join('\\\\foo\\', '', 'bar') == '\\\\foo\\bar\\')
	assert(path_base.nt:join('//foo\\', '', 'bar') == '\\\\foo\\bar\\')
	assert(path_base.nt:join('\\\\foo\\', '', '\\bar') == '\\\\foo\\bar\\')
	assert(path_base.nt:join('//foo/', '', '\\bar') == '\\\\foo\\bar\\')
	assert(path_base.nt:join('', '\\\\foo', 'bar') == '\\\\foo\\bar\\')
	assert(path_base.nt:join('', '//foo', 'bar') == '\\\\foo\\bar\\')
	assert(path_base.nt:join('', '\\\\foo\\', 'bar') == '\\\\foo\\bar\\')
	assert(path_base.nt:join('', '//foo/', 'bar') == '\\\\foo\\bar\\')
	assert(path_base.nt:join('', '\\\\foo\\', '\\bar') == '\\\\foo\\bar\\')
	assert(path_base.nt:join('', '//foo/', '/bar') == '\\\\foo\\bar\\')
	assert(path_base.nt:join('\\\\foo') == '\\\\foo\\')
	assert(path_base.nt:join('//foo') == '\\\\foo\\')
	assert(path_base.nt:join('\\\\foo\\') == '\\\\foo\\')
	assert(path_base.nt:join('//foo/') == '\\\\foo\\')
	assert(path_base.nt:join('\\\\foo', '\\') == '\\\\foo\\')
	assert(path_base.nt:join('//foo', '\\') == '\\\\foo\\')
	assert(path_base.nt:join('\\\\foo', '', '\\') == '\\\\foo\\')
	assert(path_base.nt:join('//foo', '', '/') == '\\\\foo\\')
	-- Not interpretted as UNC paths
	assert(path_base.nt:join('\\', 'foo\\bar') == 'foo\\bar')
	assert(path_base.nt:join('/', 'foo/bar') == 'foo\\bar')
	assert(path_base.nt:join('\\', '\\foo\\bar') == 'foo\\bar')
	assert(path_base.nt:join('/', '/foo/bar') == 'foo\\bar')
	assert(path_base.nt:join('', '\\', '\\foo\\bar') == 'foo\\bar')
	assert(path_base.nt:join('', '/', '/foo/bar') == 'foo\\bar')
	assert(path_base.nt:join('\\\\', 'foo\\bar') == 'foo\\bar')
	assert(path_base.nt:join('//', 'foo/bar') == 'foo\\bar')
	assert(path_base.nt:join('\\\\', '\\foo\\bar') == 'foo\\bar')
	assert(path_base.nt:join('//', '/foo/bar') == 'foo\\bar')
	assert(path_base.nt:join('\\\\', '\\', '\\foo\\bar') == 'foo\\bar')
	assert(path_base.nt:join('//', '/', '/foo/bar') == 'foo\\bar')
	assert(path_base.nt:join('\\\\\\foo\\bar') == 'foo\\bar')
	assert(path_base.nt:join('///foo/bar') == 'foo\\bar')
	assert(path_base.nt:join('\\\\\\\\foo', 'bar') == 'foo\\bar')
	assert(path_base.nt:join('////foo', 'bar') == 'foo\\bar')
	assert(path_base.nt:join('\\\\\\\\foo\\bar') == 'foo\\bar')
	assert(path_base.nt:join('////foo/bar') == 'foo\\bar')
	-- absolute paths
	assert(path_base.nt:join('D:\\', 'foo\\bar') == 'D:\\foo\\bar')
	assert(path_base.nt:join('D:\\', '\\\\foo\\bar') == 'D:\\foo\\bar')
	assert(path_base.nt:join('D:\\..\\\\', '\\', 'foo\\bar') == 'D:\\foo\\bar')
	-- joining a drive letter will not create a drive-relative path
	assert(path_base.nt:join('D:', 'foo\\bar') == 'D:\\foo\\bar')
	-- joining a drive-relative path will output a drive-relative path
	assert(path_base.nt:join('D:drive\\relative', 'foo\\bar') == 'D:drive\\relative\\foo\\bar')

	-- test path.resolve
	if isWindows then
	  -- test drive relative path resolution
	  local current_drive = process.cwd():sub(1,2)
	  local relative_path = "drive\\relative"
	  local drive_relative_path = current_drive..relative_path
	  local resolved_path = path.join(process.cwd(), relative_path)
	  assert(path_base.nt:resolve(drive_relative_path) == resolved_path)
	  -- when the drive-specific cwd env variable does not contain a path,
	  -- drive-relative paths are resolved as relative to the drive root
	  process.env["="..current_drive] = "not a cwd path"
	  assert(path_base.nt:resolve(drive_relative_path) == current_drive..path.sep..relative_path)
	end
	assert(path.resolve('a/b/c/', '../../..') == process.cwd())
	assert(path.resolve('.') == process.cwd())
	assert(path_base.posix:resolve('/var/lib', '../', 'file/') == '/var/file/')
	assert(path_base.posix:resolve('/var/lib', '/../', 'file/') == '/file/')
	assert(path_base.posix:resolve('/some/dir', '.', '/absolute/') == '/absolute/')
	assert(path_base.nt:resolve('c:\\blah\\blah', 'd:\\games', 'c:\\..\\a') == 'c:\\a')
	assert(path_base.nt:resolve('c:/blah/blah', 'd:/games', 'c:/../a') == 'c:\\a')
	assert(path_base.nt:resolve('c:\\ignore', 'd:\\a\\b\\c\\d', '\\e.exe') == 'd:\\a\\b\\c\\d\\e.exe')
	assert(path_base.nt:resolve('c:/ignore', 'd:/a/b/c/d', '/e.exe') == 'd:\\a\\b\\c\\d\\e.exe')
	assert(path_base.nt:resolve('c:\\ignore', 'c:\\some\\file') == 'c:\\some\\file')
	assert(path_base.nt:resolve('c:/ignore', 'c:/some/file') == 'c:\\some\\file')
	assert(path_base.nt:resolve('d:\\ignore', 'd:\\some\\dir\\\\') == 'd:\\some\\dir\\')
	assert(path_base.nt:resolve('d:/ignore', 'd:/some/dir//') == 'd:\\some\\dir\\')
	assert(path_base.nt:resolve('\\\\server\\share', '..', 'relative\\') == '\\\\server\\share\\relative\\')
	assert(path_base.nt:resolve('//server/share', '..', 'relative/') == '\\\\server\\share\\relative\\')
	assert(path_base.nt:resolve('c:\\', '\\\\') == 'c:\\')
	assert(path_base.nt:resolve('c:/', '//') == 'c:\\')
	assert(path_base.nt:resolve('c:\\', '\\\\dir') == '\\\\dir\\')
	assert(path_base.nt:resolve('c:/', '//dir') == '\\\\dir\\')
	assert(path_base.nt:resolve('c:\\', '\\\\server\\share') == '\\\\server\\share\\')
	assert(path_base.nt:resolve('c:/', '//server/share') == '\\\\server\\share\\')
	assert(path_base.nt:resolve('c:\\', '\\\\server\\\\share') == '\\\\server\\share\\')
	assert(path_base.nt:resolve('c:/', '//server//share') == '\\\\server\\share\\')
	assert(path_base.nt:resolve('c:\\', '\\\\\\some\\\\dir') == 'c:\\some\\dir')
	assert(path_base.nt:resolve('c:/', '///some//dir') == 'c:\\some\\dir')
	-- resolving a drive-relative path will give an absolute path
	assert(path_base.nt:resolve('d:drive\\relative') == 'd:\\drive\\relative')
	assert(path_base.nt:resolve('d:..') == 'd:\\')
	assert(path_base.nt:resolve('d:.') == 'd:\\')
	assert(path_base.nt:resolve('d:.\\file') == 'd:\\file')
	assert(path_base.nt:resolve('c:\\blah\\blah', 'd:\\games', 'c:..\\a') == "c:\\blah\\a")
	assert(path_base.nt:resolve('d:\\foo', 'd:drive\\relative') == 'd:\\foo\\drive\\relative')
	assert(path_base.nt:resolve('C:\\foo', 'd:drive\\relative') == 'd:\\drive\\relative')
	assert(path_base.nt:resolve('d:foo', 'd:drive\\relative') == 'd:\\foo\\drive\\relative')
	assert(path_base.nt:resolve('c:foo', 'd:drive\\relative') == 'd:\\drive\\relative')

	-- test path._commonParts
	assert(deepEqual({"var"}, path_base.posix:_commonParts("/var/lib/", "/var")))
	assert(deepEqual({"foo"}, path_base.posix:_commonParts("/foo/bar/", "/foo/bark/")))
	assert(deepEqual({"foo", "bar"}, path_base.posix:_commonParts("/foo/bar///", "/foo/bar")))

	-- test path.relative
	assert(path_base.posix:relative('/var/lib', '/var') == '..')
	assert(path_base.posix:relative('/var/lib', '/bin') == '../../bin')
	assert(path_base.posix:relative('/var/lib', '/var/lib') == '')
	assert(path_base.posix:relative('/var/lib', '/var/apache') == '../apache')
	assert(path_base.posix:relative('/var/', '/var/lib') == 'lib')
	assert(path_base.posix:relative('/', '/var/lib') == 'var/lib')
	assert(path_base.nt:relative('c:/blah\\blah', 'd:/games') == 'd:\\games')
	assert(path_base.nt:relative('c:/aAAa/bbbb', 'c:/aaaa') == '..')
	assert(path_base.nt:relative('c:/aaaa/bbbb', 'c:/cccc') == '..\\..\\cccc')
	assert(path_base.nt:relative('c:/aaaa/bbbb', 'c:/aaaa/bbbb') == '')
	assert(path_base.nt:relative('c:/aaaa/bbbb', 'c:/aaaa/cccc') == '..\\cccc')
	assert(path_base.nt:relative('c:/aaaa/', 'c:/aaaa/cccc') == 'cccc')
	assert(path_base.nt:relative('c:/', 'c:\\aaaa\\bbbb') == 'aaaa\\bbbb')
	assert(path_base.nt:relative('c:/aaaa/bbbb', 'd:\\') == 'd:\\')
end)

tap.run()
