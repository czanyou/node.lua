local fs        = require('fs')
local path      = require('path')
local app   	= require('app')
local conf   	= require('app/conf')

local function switchFirmwareFile()
	local rootPath = app.rootPath;
	local nodePath = conf.rootPath;

	print('Root path:' .. rootPath)
	print('Node path:' ..  nodePath)

	if (rootPath == nodePath) then
		print('Error: The same path')
		return
	end

	if (not fs.existsSync(rootPath .. '/bin')) then
		print('Error: Root path not exists ')
		return
	end

	-- Check that the link has been established
	local realPath = fs.readlinkSync(nodePath .. '/bin')
	if (realPath) then
		print('Real path:' .. realPath)
		if (rootPath .. '/bin' == realPath) then
			print('Skip: The same path')
			return
		end
	end

	-- create a new link
	local cmdline = 'rm -rf ' .. nodePath .. '/bin'
	print("Remove: " .. cmdline);
	os.execute(cmdline);

	cmdline = 'ln -s ' .. rootPath .. '/bin ' .. nodePath .. '/bin'
	print("Link: " .. cmdline);
	os.execute(cmdline);
end

switchFirmwareFile()
