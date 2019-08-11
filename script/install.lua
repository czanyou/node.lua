--
-- 用于在 Windows 系统下安装 Node.lua 运行环境，包括可执行文件及相关的 Lua 模块
-- Install the Node.lua runtime environment.
-- Include executables and related Lua module.
--

local luv    = require('luv')
local lutils = require('lutils')

local function updatePackagePath()
	local cwd = luv.cwd()

	local path = package.path
	path = path .. ';' .. cwd .. '\\core\\lua\\?.lua;' .. cwd .. '\\core\\lua\\?\\init.lua'
	package.path = path

	-- print(path)
end

local function printPathList(title, pathList)
	local tokens = pathList:split(';')

	print(title)
	for k, v in pairs(tokens) do
		print(k, v)
	end
	print('------ end list ------\n')
end

-- Update current user 'Path' environment variable (Windows Only)
local function updatePathEnvironment()
	local init  = require('init')
	local path  = require('path')
	local fs    = require('fs')

	local cwd    = luv.cwd()

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

		io.close(file)
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
	local _, offset, key, mode, oldPath = line:find("[ ]+([^ ]+)[ ]+([^ ]+)[ ]+([^\n]+)")

	local items = {}
	if (oldPath) then
		items = oldPath:split(';') or {}
	end

	-- tokens
	local paths = {}
	for index, token in pairs(items) do
		token = token:trim()

		if (#token > 0) then
			local filename = path.join(token, "lnode.exe")
			if (not fs.existsSync(filename)) then
				table.insert(paths, token)
			end
		end
	end
	table.insert(paths, pathname)

	-- update PATH
	local newPath = table.concat(paths, ";")
	if (oldPath ~= newPath) then
		os.execute('SETX PATH "' .. newPath .. '"')
		printPathList("SETX PATH=", newPath)
	end
end

-------------------------------------------------------------------------------

local osType = lutils.os_platform()
local osArch = lutils.os_arch()
local cwd    = luv.cwd()

print('')
print('------ Install Node.lua Runtime -------')
print('OS:     [' .. osType .. ']')
print('Arch:   [' .. osArch .. ']')
print('Work:   [' .. cwd .. ']')
print('------\n')

if (osType ~= 'win32') then
	print('Error: Current system is not Windows.')

else
	-- Add the bin directory under the current directory to the system Path environment variable
	updatePackagePath()
	updatePathEnvironment()
	print('Install Complete!\n')
end

luv.run()
luv.loop_close()
