local miniz     = require('miniz')
local util 		= require('util')
local path  	= require('path')
local fs  		= require('fs')

local cwd		= process.cwd()
local join  	= path.join

local exports = {}

local function getSourcePath()
	local filename = path.join(cwd, 'core/deps/lua')
	if (fs.existsSync(filename)) then
		return cwd
	end

	local sourcePath = util.dirname()
	sourcePath = path.dirname(sourcePath)
	sourcePath = path.dirname(sourcePath)
	sourcePath = path.dirname(sourcePath)
	console.log('Source path:', sourcePath);
	return sourcePath
end

local function byteArrayEncode(filedata)
	local totalBytes = #filedata
	local data = {}
	for index = 1, totalBytes do
		local value = string.byte(filedata, index)
		local item = string.format('0x%02X', value)

		if (index > 1) and (index % 16 == 1) then
			item = '\n' .. item
		end

		table.insert(data, item)
	end

	table.insert(data, '0x00')
	return table.concat(data, ', ')
end

local function buildInitFile(sourcePath, init, core, build)
    local coredata = byteArrayEncode(core)
	local initdata = byteArrayEncode(init)

	local result = [[
/* File generated automatically by the Node.lua compiler. */

#include <inttypes.h>

#define WITH_INIT 1

const char core_build[] = "]] .. build .. [[";

const uint32_t core_size = ]] .. #core .. [[;

const uint8_t core_data[]] .. (#core + 2) .. [[] = {
]] .. coredata .. [[

};

const uint32_t init_size = ]] .. #init .. [[;

const uint8_t init_data[]] .. (#init + 2) .. [[] = {
]] .. initdata .. [[

};
]]
	-- print(filedata)
	local filename = sourcePath .. '/build/packages.c'
	fs.writeFileSync(filename, result)
	print('Built lua packages: ' .. filename)
end

function exports.build()
	local writer = miniz.createWriter()
	local init = nil -- init.lua
	local version = nil -- @version.lua

	local function loadCoreFiles(sourcePath)
		local function loadCoreLuaFiles(basePath, subPath)
			local pathName = join(basePath, subPath)
			local files = fs.readdirSync(pathName) or {}
			for _, name in ipairs(files) do
				if (name:sub(1, 1) == ".") then
					goto continue;
				end

				local stat = fs.statSync(join(pathName, name))
				if (not stat) then
					-- console.log(pathName, name)
					goto continue;
				end

				if (stat.type == 'file') then
					local filedata = fs.readFileSync(pathName .. '/' .. name)
					if (subPath) then
						local package = path.join(subPath, name)
						writer:add(package, filedata, 9)

					else
						writer:add(name, filedata, 9)

						if (name == '@version.lua') then
							version = filedata
						elseif name == 'init.lua' then
							init = filedata
						end
					end

				elseif (stat.type == 'directory') then
					loadCoreLuaFiles(basePath, name)
				end

				::continue::
			end
		end

		local luaPath = path.join(sourcePath, 'core/lua')
		print('Core lua packages path: ' .. luaPath)
		loadCoreLuaFiles(luaPath)
	end

	local function loadModuleFiles(sourcePath)
		local function loadModuleLuaFiles(package, basePath, subPath)
			local pathName = join(basePath, subPath)
			local files = fs.readdirSync(pathName) or {}
			for _, name in ipairs(files) do
				if (name:sub(1, 1) == ".") then
					goto continue;
				end

				local stat = fs.statSync(join(pathName, name))
				if (not stat) then
					-- console.log(pathName, name)
					goto continue;
				end

				if (stat.type == 'file') then
					local filedata = fs.readFileSync(pathName .. '/' .. name)
					if (subPath) then
						local packageName = path.join(package, subPath, name)
						writer:add(packageName, filedata, 9)
					else
						local packageName = path.join(package, name)
						writer:add(packageName, filedata, 9)
					end

				elseif (stat.type == 'directory') then
					loadModuleLuaFiles(package, basePath, name)
				end

				::continue::
			end
		end

		local modulePath = path.join(sourcePath, 'modules')
		print('Lua modules path: ' .. modulePath)

		-- modules
		local files = fs.readdirSync(modulePath) or {}
		for _, name in ipairs(files) do
			-- console.log(name)
			if (name:sub(1, 1) == ".") then
				goto continue;
			end

			local stat = fs.statSync(join(modulePath, name, 'lua'))
			if (not stat) then
				goto continue;
			end

			if (stat.type == 'directory') then
				local basePath = path.join(modulePath, name, 'lua')
				loadModuleLuaFiles(name, basePath)
			end

			::continue::
		end
	end

	-- lua
	local sourcePath = getSourcePath()
	loadCoreFiles(sourcePath)
	loadModuleFiles(sourcePath)

	-- build zip
	local luaData = writer:finalize()
	writer:close()
	fs.writeFileSync(sourcePath .. '/build/packages.zip', luaData)

	-- build
	local script = load(version)
	version = script()
	local build = version.build

	buildInitFile(sourcePath, init, luaData, build)
end

function exports.test()
	local sourcePath = getSourcePath()
	local filename = path.join(sourcePath, '/build/packages.zip')
	local reader = miniz.createReader(filename)
	local total = reader:getFileCount()
	console.log(total)

	for i = 1, total do
		local filename = reader:getFilename(i)
		console.log(i, filename)
	end
end

return exports
