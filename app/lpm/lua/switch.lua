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
	local filename = '/tmp/log/switch.log'
	fs.unlinkSync(filename)

	local printInfo = function(message)
		fs.appendFile(filename, message .. '\r\n')
		print(message)
	end

	local rootPath = app.rootPath;
	local nodePath = conf.rootPath;
	local nodeBinPath = nodePath .. '/bin'
	local rootBinPath = rootPath .. '/bin'
	printInfo('Switch to root path: ' .. rootPath)
	printInfo('Date: ' .. os.date())

	if (rootPath == nodePath) then
		printInfo('Switch error: The same root and node path')
		return
	end

	printInfo('Node path: ' ..  nodePath)

	if (not fs.existsSync(rootBinPath)) then
		printInfo('Switch error: Root bin path not exists')
		return
	end

	-- Check that the link has been established
	local realPath = fs.readlinkSync(nodeBinPath)
	if (realPath) then
		printInfo('Real node path: ' .. realPath)
		if (rootBinPath == realPath) then
			printInfo('Skip switch: The same read and root path')
			return
		end
	end

	if (isDevelopmentPath(nodePath)) then
		printInfo('Warning: The "' .. rootPath .. '" is in development mode.')

	else
		-- create a new link
		local cmdline = 'rm -rf ' .. nodeBinPath
		printInfo("Remove: " .. cmdline);
		os.execute(cmdline);

		cmdline = 'ln -s ' .. rootBinPath .. ' ' .. nodeBinPath
		printInfo("Link: " .. cmdline);
		os.execute(cmdline);
	end

	realPath = fs.readlinkSync(nodeBinPath)
	if (realPath == rootBinPath) then
		printInfo("Switch: successful")
		console.warn('switch successful: ' .. realPath)
	else
		printInfo("Switch failed: " .. realPath)
	end

	-- TODO: 执行更多固件升级后的操作
end

switchFirmwareFile()
