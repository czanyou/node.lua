--[[

Copyright 2016 The Node.lua Authors. All Rights Reserved.

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

local core		= require('core')
local fs		= require('fs')
local json		= require('json')
local path		= require('path')
local util		= require('util')
local conf		= require('app/conf')
local app		= require('app')

-------------------------------------------------------------------------------
-- meta

local meta = { }
meta.name        = "lpm"
meta.version     = "3.0.2"
meta.description = "Lua package manager (Node.lua command-line tool)."
meta.tags        = { "lpm", "package", "command-line" }

-------------------------------------------------------------------------------
-- exports

local exports = { meta = meta }

exports.rootPath = app.rootPath

-------------------------------------------------------------------------------
-- config

local config = {}

local function getProfile(key)
	local pos = key:find(':')
	local module = nil
	if (pos) then
		module = key:sub(1, pos - 1)
		key = key:sub(pos + 1)
	end

	return conf(module or 'user'), key
end

-- 打印指定名称的配置参数项的值
function config.get(key)
	if (not key) then
		print("\nError: missing required argument `key`.")
		print('\nUsage: lpm get <key>')
		return
	end

	local profile, name = getProfile(key)
	if (name == '*') then
		console.printr(profile.settings)

	else
		console.printr(profile:get(name))
	end
end

function config.help()
	local text = [[

Manage the lpm configuration files

Usage: 
  lpm config get <key>         - Get value for <key>.
  lpm config list              - List all config files
  lpm config set <key> <value> - Sets the specified config <key> <value>.
  lpm config unset <key>       - Clears the specified config <key>.
  lpm get <key>                - Get value for <key>.
  lpm set <key> <value>        - Sets the specified config <key> <value>.

Aliases: c, conf

]]

	print(console.colorful(text))
end

function config.list(name)
	if (not name) then
		name = 'user'
	end

	local profile = conf(name)

	print(profile.filename .. ': ')
	console.log(profile.settings)
end

-- 设置指定名称的配置参数项的值
function config.set(key, value)
	if (not key) or (not value) then
		print("\nError: missing required argument `key` and `value`.")
		print('\nUsage: lpm set <key> <value>')
		return
	end

	local profile, name = getProfile(key)
	local oldValue = profile:get(name)
	if (not oldValue) or (value ~= oldValue) then
		profile:set(name, value)
		profile:commit()
	end

	print('set `' .. tostring(name) .. '` = `' .. tostring(value) .. '`')
end

-- 删除指定名称的配置参数项的值
function config.unset(key)
	if (not key) then
		print("\nError: missing required argument `key`.")
		print('\nUsage: lpm config unset <key>')
		return
	end

	local profile, name = getProfile(key)
	if (profile:get(name) ~= nil) then
		profile:set(name, nil)
		profile:commit()
	end

	print('clears `' .. tostring(key) .. '`')
end

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

-- Display lpm bin path
function exports.bin()
	print(path.join(exports.rootPath, 'bin'))
end

-- Stop and delete the specified process
function exports.delete(...)
	app.delete(...)
end

-- Kill the specified application process
function exports.kill(...)
	app.kill(...)
end

-- List all installed applications
function exports.list(...)
	app.printList(...)
end

-- List all application processes
function exports.ls(...)
	app.printList(...)
end

-- List all application processes
function exports.ps(...)
	app.printProcesses(...)
end

-- Restart the specified process
function exports.restart(...)
	app.restart(...)
end

-- Display lpm root path
function exports.root()
	print(exports.rootPath)
end

-- Start and daemonize an application
function exports.start(...)
	app.start(...)
end

-- Stop the specified process
function exports.stop(...)
	app.stop(...)
end

function exports.watch(...)
	app.start('lpm', 'start', ...)
end

-------------------------------------------------------------------------------
-- package & upgrade

function exports.colors()
	console.colors()
end

function exports.install(...)
	require('lpm/upgrade').install(...)
end

-- Retrieve new lists of packages
function exports.update(...)
	require('lpm/update').update(...)
end

function exports.upgrade(...)
	require('lpm/update').upgrade(...)
end

-------------------------------------------------------------------------------
-- misc

-- Scanning for nearby devices
function exports.scan(timeout, serviceType)
	local err, client = pcall(require, 'ssdp/client')
	if (not client) then
		return
	end

	local list = {}

	local grid = app.table({20, 24, 24})

	print("Start scaning...")

	grid.line()
	grid.cell("IP", "UID", "Model")
	grid.line('=')

	local ssdpClient = client({}, function(response, rinfo)
		if (list[rinfo.ip]) then
			return
		end

		local headers   = response.headers
		local item      = {}
		item.remote     = rinfo
		item.usn        = headers["usn"] or ''

		list[rinfo.ip] = item

		--console.log(headers)

		local model = headers['X-DeviceModel']
		local name = rinfo.ip .. ' ' .. item.usn
		if (model) then
			name = name .. ' ' .. model
		end

		console.write('\r')  -- clear current line
		grid.cell(rinfo.ip, item.usn, model)
	end)

	-- search for a service type 
	serviceType = serviceType or 'urn:schemas-upnp-org:service:cmpp-iot'
	ssdpClient:search(serviceType)

	local scanCount = 0
	local scanTimer = nil
	local scanMaxCount = timeout or 10

	scanTimer = setInterval(500, function()
		ssdpClient:search(serviceType)
		console.write("\r " .. string.rep('.', scanCount))

		scanCount = scanCount + 1
		if (scanCount >= scanMaxCount) then
			clearInterval(scanTimer)
			scanTimer = nil

			ssdpClient:stop()

			console.write('\r') -- clear current line
			grid.line()
			print("End scaning...")
		end
	end)
end

function exports.info(...)
	local path = package.path
	local list = path:split(';')
	print(console.colorful('${string}package.path:${normal}'))
	for i = 1, #list do
		print(list[i])
	end

	print(console.colorful('${string}package.cpath:${normal}'))
	local path = package.cpath
	local list = path:split(';')
	for i = 1, #list do
		print(list[i])
	end	

	print(console.colorful('${string}app.rootPath: ${normal}') .. (app.rootPath or '-'))
	print(console.colorful('${string}app.nodePath: ${normal}') .. (app.nodePath or '-'))	
	print(console.colorful('${string}app.target:   ${normal}') .. (app.getSystemTarget() or '-'))
	print(console.colorful('${string}os.arch:      ${normal}') .. os.arch())
	print(console.colorful('${string}os.time:      ${normal}') .. os.time())
	print(console.colorful('${string}os.uptime:    ${normal}') .. os.uptime())
	print(console.colorful('${string}os.clock:     ${normal}') .. os.clock())

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

	local info = require('cjson')
	if (info and info.VERSION) then
		printVersion("cjson", info.VERSION)
	end

	local ret = nil

	ret, info = pcall(require, 'lmbedtls.md')
	if (info and info._VERSION) then	
		printVersion("mbedtls", info.VERSION)
	end

	ret, info = pcall(require, 'lsqlite')
	if (info and info.VERSION) then	
		printVersion("sqlite", info.VERSION)
	end

	ret, info = pcall(require, 'miniz')
	if (info and info.VERSION) then	
		printVersion("miniz", info.VERSION)
	end

	ret, info = pcall(require, 'lmedia')
	if (info and info.version) then	
		printVersion("lmedia", info.version())
	end

	local filename = path.join(exports.rootPath, 'package.json')
	local packageInfo = json.parse(fs.readFileSync(filename))
	if (not packageInfo) then
		return
	end

	--console.log(packageInfo)
	print(string.format([[

System information:
- target: %s
- version: %s
	]], packageInfo.target, packageInfo.version))
end

function exports.usage()
	local appPath = path.join( app.rootPath, 'app')
	local fmt = [[

This is the CLI for Node.lua.


Usage: ${highlight}lpm <command> [args]${normal}
${braces}
where <command> is one of:
	c, config, get, set, unset
	l, list, ps, restart, start, stop, 
	update, upgrade
	help, info, root, scan, version ${normal}


   or: ${highlight}lpm <name> <command> [args]${normal}
${braces}
where <name> is the name of the application, located in 
	']] .. appPath .. [[', the supported values of <command>
	depend on the invoked application.${normal}


   or: ${highlight}lpm help - ${braces}involved overview${normal}


Start with 'lpm list' to see installed applications.
	]]

	print(console.colorful(fmt))
	print('lpm - v' .. process.version, '\r\n')

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

- config <args>     ${braces}Manager Node.lua configuration options.${normal}
- get <key>         ${braces}Get value for <key>.${normal}
- set <key> <value> ${braces}Set the specified config <key> <value>.${normal}
- unset <key>       ${braces}Clears the specified config <key>.${normal}

${string}Application Commands:${normal}

- list <name>       ${braces}List all installed applications${normal}
- ps                ${braces}List all application processes${normal}
- restart <name>    ${braces}Restart an application process${normal}
- start <name>      ${braces}Start and daemonize an application${normal}
- stop <name>       ${braces}Stop an application process${normal}

${string}Update Commands:${normal}

- update            ${braces}Retrieve new lists and packages of applications${normal}
- upgrade           ${braces}Perform an system upgrade${normal}


${string}Other Commands:${normal}

- help              ${braces}Get help on lpm${normal}
- info              ${braces}Prints system informations${normal}
- root              ${braces}Display Node.lua root path${normal}
- scan <timeout>    ${braces}Scan all devices that support SSDP.${normal}
- version           ${braces}Prints version informations${normal}

]]

	print(console.colorful(fmt))
	print('lpm@' .. process.version .. ' at ' .. app.rootPath)
end

-------------------------------------------------------------------------------
-- call

function exports.call(args)
	local command = args[1]
	table.remove(args, 1)

	local func = exports[command or 'usage']
	if (type(func) == 'function') then
		local status, ret = pcall(func, table.unpack(args))
		runLoop()

		if (not status) then
			print(ret)
		end

		return ret

	else
		_executeApplication(command, table.unpack(args))
	end
end

setmetatable(exports, {
	__call = function(self, ...)
		self.call(...)
	end
})

return exports
