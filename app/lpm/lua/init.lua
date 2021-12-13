--[[

Copyright 2016-2020 The Node.lua Authors. All Rights Reserved.

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

local fs		= require('fs')
local json		= require('json')
local path		= require('path')
local app		= require('app')

local config    = require('./config')

-------------------------------------------------------------------------------
-- meta

local meta = { }
meta.description = "Lua package manager (Node.lua command-line tool)."

-------------------------------------------------------------------------------
-- exports

local exports = { meta = meta }

exports.rootPath = app.rootPath

-------------------------------------------------------------------------------
-- config

function exports.config(action, ...)
	local method = config[action or 'help']
	if (method) then
		return method(...)

	else
		config.help()
	end
end

exports.c    	= exports.config
exports.conf 	= exports.config
exports.unset  	= config.unset
exports.get  	= config.get
exports.set  	= config.set
exports.setjson = config.setjson

-------------------------------------------------------------------------------
-- application

local _executeApplication = function (name, action, ...)
	--print(name, action, ...)
	if (not name) then
		print("Error: missing required argument '<name>'.")
		print("")
		return
	end

	local ret, err = app.execute(name, action, ...)
	if (not ret) or (ret < 0) then
		print("Error: unknown command or application: '" .. tostring(name) .. "', see 'lpm help'")
		print("")
	end
end

-- Stop and delete the specified process
function exports.delete(...)
	local ret, err = app.delete(...)
	console.printr(err or ret or '')
end

-- Kill the specified application process
function exports.kill(...)
	local ret, err = app.kill(...)
	console.printr(err or ret or '')
end

-- List all installed applications
function exports.list(...)
	app.printList(...)
end

-- List all application processes
function exports.ls(...)
	app.printList(...)
end

function exports.open(pathname, ...)
	local filename = pathname
	if (not filename:startsWith('/')) then
		filename = path.join(process.cwd(), pathname)
	end

	local miniz = require('miniz')
	local reader = miniz.createReader(filename)
	local name = 'lua/app.lua'
	local data = reader:readFile(name)
	if (not data) then
		return -3, '"' .. name .. '" not exists!'
	end

	local basename = path.basename(filename, '.zip')
	console.log('basename', basename)

	if (not package.apps) then
		package.apps = {}
	end

	package.apps[basename] = reader

    --console.log(package.path)
	local script, err = load(data, '@$app/' .. basename .. '/' .. name)
	if (err) then
		error(err)
		return -4, err
	end

	console.log(process.argv)
	_G.arg = table.pack(...)
	script(...)
end

-- List all application processes
function exports.ps(...)
	app.printProcesses(...)
end

-- Restart the specified process
function exports.restart(name, ...)
	local ret, err = app.restart(name, ...)
	local result = ret and ret[name]
	err = err or (result and result.error)
	if (err) then
		return console.printr('restart failed: ', err)
	end

	console.printr('restarted: ', name, result)
end

-- Start and daemonize an application
function exports.start(name, ...)
	-- console.log('start', name, ...)

	local ret, err = app.start(name, ...)
	local result = ret and ret[name]
	err = err or (result and result.error)
	if (err) then
		return console.printr('start failed: ', err)
	end

	console.printr('started: ', name, result)
end

-- Stop the specified process
function exports.stop(name, ...)
	local ret, err = app.stop(name, ...)
	local result = ret and ret[name]
	err = err or (result and result.error)
	if (err) then
		return console.printr('stop failed: ', err)
	end

	console.printr('stopped: ', name, result)
end

function exports.watch(...)
	app.start('lpm', 'start', ...)
end

-------------------------------------------------------------------------------
-- package & upgrade

function exports.install(...)
	require('app/update').install(...)
end

-- Retrieve new lists of packages
function exports.update(...)
	require('app/update').update(...)
end

function exports.upgrade(...)
	require('app/update').upgrade(...)
end

-------------------------------------------------------------------------------
-- print

-- Display lpm bin path
function exports.bin()
	console.printr(path.join(exports.rootPath, 'bin'))
end

function exports.colors()
	console.colors()
end


-- Display the help information
function exports.help()
	local fmt = [[

lpm - lnode package manager.

${braces}This is the CLI for Node.lua, Node.lua is a 'universal' platform work across
many different systems, enabling install, configure, running and remove
applications and utilities for Internet of Things.${normal}

${highlight}usage: lpm <command> [args]${normal}

where <command> is one of:

${string}Configuration Commands:${normal}

- config <args>     ${braces}Manager Node.lua configuration options. ${normal}
- get <key>         ${braces}Get value for <key>. ${normal}
- set <key> <value> ${braces}Set the specified config <key> <value>. ${normal}
- unset <key>       ${braces}Clears the specified config <key>. ${normal}

${string}Application Commands:${normal}

- list <name>       ${braces}List all installed applications ${normal}
- ps                ${braces}List running applications ${normal}
- restart <name>    ${braces}Restart an application ${normal}
- start <name>      ${braces}Start and daemonize an application ${normal}
- stop <name>       ${braces}Stop an running application ${normal}

${string}Update Commands:${normal}

- update            ${braces}Retrieve new packages of applications ${normal}
- upgrade system    ${braces}Perform an system upgrade ${normal}

${string}Other Commands:${normal}

- help              ${braces}Get help on lpm ${normal}
- info              ${braces}Prints Node.lua system informations ${normal}
- root              ${braces}Display Node.lua root path ${normal}
- scan <timeout>    ${braces}Scan devices that support SSDP protocol. ${normal}
- version           ${braces}Prints version informations ${normal}

]]

	print(console.colorful(fmt))
	print('lpm@' .. process.version .. ' at ' .. app.rootPath)
end


function exports.info(...)
	local function printInfo(name, value)
		print(console.colorful('${braces}' .. name .. '      ${normal}') .. tostring(value))
	end

	local function printPath(name, value)
		local list = value:split(';')
		print(console.colorful('${string}' .. name .. ':${normal}'))
		for i = 1, #list do
			print(list[i])
		end
	end

	-- path
	print('Node.lua runtime information:\r\n')
	printPath('package.path', package.path)
	printPath('package.cpath', package.cpath)

	print(console.colorful('${string}app:${normal}'))
	printInfo('rootPath', (app.rootPath or '-'))
	printInfo('nodePath', (app.nodePath or '-'))
	printInfo('target  ', (app.getSystemTarget() or '-'))
	print();

	print(console.colorful('${string}os:${normal}'))
	printInfo('arch    ', os.arch())
	printInfo('time    ', os.time())
	printInfo('uptime  ', os.uptime())
	printInfo('clock   ', os.clock())
	printInfo('homedir ', os.homedir())
	printInfo('hostname', os.hostname())
	printInfo('tmpdir  ', os.tmpdir)
	printInfo('platform', os.platform())
	printInfo('Date.now', Date.now())
	print();

	print(console.colorful('${string}process:${normal}'))
	printInfo('cwd     ', process.cwd())
	printInfo('execPath', process.execPath)
	printInfo('now     ', process.now())
	printInfo('hrtime  ', process.hrtime())
	printInfo('rootPath', process.rootPath)
	print();

	print(console.colorful('${string}console:${normal}'))
	printInfo('theme   ', (console.defaultTheme or '-'))
	print();
end

-- Display lpm root path
function exports.root()
	console.printr(exports.rootPath)
end

function exports.usage()
	local appPath = path.join( app.rootPath, 'app')
	local fmt = [[

This is the CLI for Node.lua.

Usage: ${highlight}lpm <command> [args]${normal}
${braces}
where <command> is one of:
	config, get, set, unset
	list, ls, ps, restart, start, stop,
	update, upgrade
	help, info, root, scan, version ${normal}

   or: ${highlight}lpm <name> <command> [args]${normal}
${braces}
where <name> is the name of the application, located in
	']] .. appPath .. [[', the supported values of <command>
	depend on the invoked application.${normal}

Start with 'lpm list' to list all installed applications.
	]]

	print(console.colorful(fmt))
	print('Try `lpm help` for more options.')
	print('lpm - v' .. process.version)
end

-- Display the version information
function exports.version()
	local printVersion = function(name, version)
		print(" - " .. (name or '') .. console.color('braces') ..
			" v" .. (version or ''), console.color('normal'))
	end

	print("Node.lua v" .. tostring(process.version) .. ' with:')
	for k, v in pairs(process.versions) do
		printVersion(k, v)
	end

	local names = {'cjson', 'mbedtls.md', 'sqlite', 'miniz', 'lmedia'}
	for _, name in ipairs(names) do
		local _, info = pcall(require, name)
		if (info and info.VERSION) then
			printVersion(name, info.VERSION)
		end
	end

	local filename = path.join(os.tmpdir, 'update/firmware.json')
	local packageInfo = json.parse(fs.readFileSync(filename))
	if (not packageInfo) then
		return
	end

	--console.log(packageInfo)
	print(string.format([[

Firmware information:
 - target: %s
 - size: %s
 - md5sum: %s
	]], packageInfo.name, packageInfo.size, packageInfo.md5sum))
end

-------------------------------------------------------------------------------
-- misc

function exports.call(command, ...)
	local func = exports[command or 'init']
	if (type(func) == 'function') then
		local status, ret = pcall(func, ...)
		runLoop()

		if (not status) then
			print(ret)
		end

		return ret

	else
		_executeApplication(command, ...)
	end
end

function exports.init()
	exports.usage()
end

-- Scanning for nearby devices
function exports.scan(timeout, serviceType)
	local ssdp = require('ssdp')
	if (ssdp) then
		ssdp.scan(timeout, serviceType)
	end
end

-- 通过 http 下载文件
---@param url string HTTP URL
---@param name string 保存文件名
function exports.wget(url, name)
	if (not url) then
		print('wget: missing URL parameter')

		print('Usage: wget <URL> [name]')
		return
	end

	local request = require('http/request')
	request.download(url, {}, function(err, percent, response)
		if (err) then
			return print(err)
		end

		if (percent <= 100) then
			console.write('\rDownloading: (' .. percent .. '%)...  ')
		end

		if (percent < 100) or (not response) then
			return
		end

		-- write to a temp file
		console.write('\rDownloading: Done        \r\n')
		fs.writeFile(os.tmpdir .. '/' .. (name or 'file'), response.body)
	end)
end

-------------------------------------------------------------------------------
-- call

setmetatable(exports, {
	__call = function(self, arg)
		self.call(table.unpack(arg))
	end
})

return exports
