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

local core   	= require('core')
local fs     	= require('fs')
local json   	= require('json')
local path   	= require('path')
local utils  	= require('utils')
local conf    	= require('ext/conf')
local app 		= require('app')

-------------------------------------------------------------------------------
-- meta

local meta = { }
meta.name        = "ldb"
meta.version     = "1.0.1"
meta.description = "Lua debug tool (Node.lua debug command-line tool)."
meta.tags        = { "ldb", "package", "command-line" }

-------------------------------------------------------------------------------
-- exports

local exports = { meta = meta }

exports.rootPath = app.rootPath
exports.rootURL  = app.rootURL

-------------------------------------------------------------------------------
-- application

local _executeApplication = function (name, action, ...)
	--print(name, action, ...)
	if (not name) then
		print("Error: the '<name>' argument was not provided.")
		print("")
		return
	end

	local ret, err = app.execute(name, action, ...)	
	if (not ret) or (ret < 0) then
		print("Error: unknown command or application: '" .. tostring(name) .. "', see 'ldb help'")
		print("")
	end
end

function exports.connect(...)
	local debug 	= require('ext/debug')
	debug.connect(...)
end

function exports.deploy(...)
	local debug 	= require('ext/debug')
	debug.deploy(...)
end

function exports.disconnect(...)
	local debug 	= require('ext/debug')
	debug.disconnect(...)
end

function exports.info(...)
	local debug 	= require('ext/debug')
	debug.info(...)
end

-- Install new packages
function exports.install(...)
	local debug 	= require('ext/debug')
	debug.install(...)
end

-- Remove packages
function exports.remove(...)
	local debug 	= require('ext/debug')
	debug.remove(...)
end

-- Scanning for nearby devices
function exports.scan(...)
	_executeApplication('ssdp', 'scan', ...)
end

function exports.sh(...)
	local debug 	= require('ext/debug')
	debug.sh(...)
end

function exports.usage()
	local fmt = [[

This is the debug CLI for Node.lua.


Usage: ${highlight}ldb <command> [args]${normal}
${braces}
where <command> is one of:
    connect, deploy, disconnect, help, info, install, remove
    restart, scan, sh, start, stop${normal}

   or: ${highlight}ldb help - ${braces}involved overview${normal}

	]]

	print(console.colorful(fmt))
	print('ldb - v' .. process.version, '\r\n')

end
-- Display the help information
function exports.help()
	local fmt = [[

ldb - lnode debug tool.

${braces}This is the debug CLI for Node.lua.${normal}

${highlight}usage: ldb <command> [args]${normal}

where <command> is one of:

- connect <host>    ${braces}Connect to a device that support SSDP.${normal}
- deploy <host>     ${braces}Deploy the latest SDK to the device.${normal}
- install <name>    ${braces}Install a new application to the device.${normal}
- remove <name>     ${braces}Remove a application from the device.${normal}
- scan <timeout>    ${braces}Scan all devices that support SSDP.${normal}

]]

	print(console.colorful(fmt))
	print('ldb@' .. process.version .. ' at ' .. app.rootPath)
end

-------------------------------------------------------------------------------
-- call

function exports.call(args)
	local command = args[1]
	table.remove(args, 1)

	local func = exports[command or 'usage']
	if (type(func) == 'function') then
		local status, ret = pcall(func, table.unpack(args))
		run_loop()

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

