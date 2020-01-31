local fs        = require('fs')
local path      = require('path')
local app   	= require('app')
local conf   	= require('app/conf')

-- 指出当前是否处于开发模式
-- @param {string} rootPath
-- @return 返回 true 表示开发模式
local function isDevelopmentPath(rootPath)
	local filename1 = path.join(rootPath, 'lua/lnode')
	local filename2 = path.join(rootPath, 'app/lbuild')
	local filename3 = path.join(rootPath, 'src')
	if (fs.existsSync(filename1) or fs.existsSync(filename2) or fs.existsSync(filename3)) then
		return true
	end

	return false
end

-- 当固件安装完成后，调用这个方法修改链接文件将 Node.lua 切换到新版固件
local function switchFirmwareFile()
	local rootPath = app.rootPath;
	local nodePath = conf.rootPath;

	print('Root path:' .. rootPath)
	print('Node path:' ..  nodePath)

	if (isDevelopmentPath(nodePath)) then
		print('Warning: The "' .. rootPath .. '" is in development mode.')
		return
	end

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

	-- TODO: 执行更多固件升级后的操作
end

switchFirmwareFile()
