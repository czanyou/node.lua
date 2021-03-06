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

local fs		= require('fs')
local json		= require('json')
local path		= require('path')
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
  lpm config setjson <key> <json> - Sets the specified config <key> <json>.
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
	console.printr(profile.settings)
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

function config.setjson(key, value)
	if (not key) or (not value) then
		print("\nError: missing required argument `key` and `value`.")
		print('\nUsage: lpm set <key> <value>')
		return
	end

	value = json.parse(value)
	if (value == nil) then
		print('Invalid JSON text')
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
	if (profile:set(name, nil)) then
		profile:commit()

		print('unset `' .. tostring(name) .. '`')
	end
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

-- Display lpm bin path
function exports.bin()
	console.printr(path.join(exports.rootPath, 'bin'))
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

-- List all application processes
function exports.ps(...)
	app.printProcesses(...)
end

-- Restart the specified process
function exports.restart(...)
	local ret, err = app.restart(...)
	console.printr(err or ret or '')
end

-- Display lpm root path
function exports.root()
	console.printr(exports.rootPath)
end

-- Start and daemonize an application
function exports.start(...)
	console.log('start', ...)

	local ret, err = app.start(...)
	console.printr(err or ret or '')
end

-- Stop the specified process
function exports.stop(...)
	local ret, err = app.stop(...)
	console.printr(err or ret or '')
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
	require('lpm/update').install(...)
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
	local err, ssdp = pcall(require, 'ssdp')
	if (not ssdp) then
		return
	end

	local list = {}
	print("Start scaning...")

	local ssdpClient = ssdp.client({}, function(response, rinfo)
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
		print(rinfo.ip, item.usn, model)
	end)

	-- search for a service type
	-- urn:schemas-webofthings-org:device
	serviceType = serviceType or 'urn:schemas-upnp-org:service:cmpp-iot'
	ssdpClient:search(serviceType)

	local scanCount = 0
	local scanTimer = nil
	local scanMaxCount = tonumber(timeout) or 10

	scanTimer = setInterval(500, function()
		ssdpClient:search(serviceType)
		console.write("\r " .. string.rep('.', scanCount))

		scanCount = scanCount + 1
		if (scanCount >= scanMaxCount) then
			clearInterval(scanTimer)
			scanTimer = nil

			ssdpClient:stop()

			console.write('\r') -- clear current line
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
	print();

	print(console.colorful('${string}os.arch:      ${normal}') .. os.arch())
	print(console.colorful('${string}os.time:      ${normal}') .. os.time())
	print(console.colorful('${string}os.uptime:    ${normal}') .. os.uptime())
	print(console.colorful('${string}os.clock:     ${normal}') .. os.clock())
	print(console.colorful('${string}os.homedir:   ${normal}') .. os.homedir())
	print(console.colorful('${string}os.hostname:  ${normal}') .. os.hostname())
	print(console.colorful('${string}os.tmpdir:    ${normal}') .. os.tmpdir)
	print(console.colorful('${string}os.platform:  ${normal}') .. os.platform())
	print(console.colorful('${string}Date.now:     ${normal}') .. Date.now())
	print();

	print(console.colorful('${string}process.cwd:      ${normal}') .. process.cwd())
	print(console.colorful('${string}process.execPath: ${normal}') .. process.execPath)
	print(console.colorful('${string}process.now:      ${normal}') .. process.now())
	print(console.colorful('${string}process.hrtime:   ${normal}') .. process.hrtime())
	print(console.colorful('${string}process.rootPath: ${normal}') .. process.rootPath)
	print();

	print(console.colorful('${string}console.stderr:  ${normal}'), console.stderr)
	print(console.colorful('${string}console.stdin:   ${normal}'), console.stdin)
	print(console.colorful('${string}console.stdout:  ${normal}'), console.stdout)
	print(console.colorful('${string}console.theme:   ${normal}'), console.defaultTheme)
	print();
end

function exports.wget(url, name)
	if (not url) then
		print('empty url string')
		return
	end

	local request = require('http/request')
	request.download(url, {}, function(err, percent, response)
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

function exports.test()
	local stdout = process.stdout;
	console.log(stdout)

	stdout = process.stdout;
	console.log(stdout)

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

	local filename = path.join(os.tmpdir, 'update/update.json')
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

function exports.init()
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

Start with 'lpm list' to see installed applications.
	]]

	print(console.colorful(fmt))
	print('lpm - v' .. process.version)
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

- update            ${braces}Retrieve new packages of applications${normal}
- upgrade system    ${braces}Perform an system upgrade${normal}

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

setmetatable(exports, {
	__call = function(self, arg)
		self.call(table.unpack(arg))
	end
})

return exports
