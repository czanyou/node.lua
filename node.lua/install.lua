#!/usr/bin/env lnode

-- 
-- 安装 Node.lua 运行环境，包括可执行文件及相关的 Lua 模块
-- Install the Node.lua runtime environment.
-- Include executables and related Lua module.
-- 

local uv     = require('uv')
local lutils = require('lutils')

local cwd    = uv.cwd()

local function printPathList(title, pathList)
	local tokens = pathList:split(';')

	print(title)
	for k, v in pairs(tokens) do
		print(k, v)
	end
	print('------ end list ------\n')
end

-- Update current user 'Path' environment variable (Windows Only)
local function updatePathEnvironment(isAdd)
	local init  = require('init')
	local utils = require('utils')
	local path  = require('path')
	local fs    = require('fs')

	local pathname = path.join(cwd, 'bin')
	if (not fs.existsSync(pathname)) then
		return
	end

	-- Query the value of 'HKEY_CURRENT_USER\\Environment\\Path'
	local tokens = nil
	local file = io.popen('REG QUERY HKEY_CURRENT_USER\\Environment /v Path')
	if (file) then
		local result = file:read("*all")
		if (result) then
	 		tokens = result:split('\n') or {}
		end
	end

	if (not tokens) then
		return
	end

	local pos = 3
	for index, token in pairs(tokens) do
		if (token:startsWith('HKEY_CURRENT_USER')) then
			pos = index + 1
			break
		end
	end

	-- KEY TYPE VALUE
	local line = tokens[pos] or ""
	_, offset, key, mode, value = line:find("[ ]+([^ ]+)[ ]+([^ ]+)[ ]+([^\n]+)")

	local items = {}
	if (value) then
		items = value:split(';') or {}
	end

	local skip = false
	local paths = {}
	for index, token in pairs(items) do
		token = token:trim()
		if (token == pathname) then
			skip = true;
		end

		if (#token > 0) then
			table.insert(paths, token)
		end
	end

	if (not skip) then
		table.insert(paths, pathname)
		local BIN_PATH = table.concat(paths, ";")
		os.execute('SETX PATH "' .. BIN_PATH .. '"')
		printPathList("SET BIN_PATH=", BIN_PATH)
		
	else 
		local BIN_PATH = table.concat(paths, ";")
		printPathList("SET BIN_PATH=", BIN_PATH)
	end
end

-------------------------------------------------------------------------------

local osType = lutils.os_platform()
local osArch = lutils.os_arch()

print('')
print('------ Install Node.lua Runtime -------')
print('OS:     [' .. osType .. ']')
print('Arch:   [' .. osArch .. ']')
print('Work:   [' .. cwd .. ']')
print('------\n')

if (osType == 'win32') then
	-- Add the bin directory under the current directory to the system Path environment variable
	updatePathEnvironment(true)
end

print('Install Complete!\n')

uv.run()
uv.loop_close()
