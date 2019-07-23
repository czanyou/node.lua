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

local core      = require('core')
local fs        = require('fs')
local json      = require('json')
local miniz     = require('miniz')
local path      = require('path')
local url       = require('url')
local app       = require('app')

local conf   	= require('app/conf')
local ext   	= require('app/utils')

--[[
Node.lua 系统更新程序
======

这个脚本用于自动在线更新 Node.lua SDK, 包含可执行主程序, 核心库, 以及核心应用等等

0：初始状态
1：固件更新成功
2：没有足够的 Flash 空间
3：没有足够的内存空间
4：下载过程中连接断开
5：固件验证失败
6：不支持的固件类型
7：无效的 URI
8：固件更新失败
9：不支持的通信协议

--]]

-------------------------------------------------------------------------------

local exports = {}

-- Update states
local STATE_INIT = 0
local STATE_DOWNLOADING = 1
local STATE_DOWNLOAD_COMPLETED = 2
local STATE_UPDATING = 3

-- Update result code
local UPDATE_INIT = 0
local UPDATE_SUCCESSFULLY = 1
local UPDATE_NOT_ENOUGH_FLASH = 2
local UPDATE_NOT_ENOUGH_RAM = 3
local UPDATE_DISCONNECTED = 4
local UPDATE_VALIDATION_FAILED = 5
local UPDATE_UNSUPPORTED_FIRMWARE_TYPE = 6
local UPDATE_INVALID_URI = 7
local UPDATE_FAILED = 8
local UPDATE_UNSUPPORTED_PROTOCOL = 9

-------------------------------------------------------------------------------

local function getNodePath()
	return conf.rootPath
end

local function isDevelopmentPath(rootPath)
	local filename1 = path.join(rootPath, 'lua/lnode')
	local filename2 = path.join(rootPath, 'app/lbuild')
	local filename3 = path.join(rootPath, 'src')
	if (fs.existsSync(filename1) or fs.existsSync(filename2) or fs.existsSync(filename3)) then
		print('Warning: The "' .. rootPath .. '" is in development mode.')
		return true
	end

	return false
end

-- 检查是否有另一个进程正在更新系统
local function upgradeLock()
	local tmpdir = os.tmpdir or '/tmp'

	print("Upgrade: Start")

	local lockname = path.join(tmpdir, '/update.lock')
	local lockfd = fs.openSync(lockname, 'w+')
	local ret = fs.fileLock(lockfd, 'w')
	if (ret == -1) then
		print('Error: The update already locked!')
		return nil
	end

	return lockfd
end

local function upgradeUnlock(lockfd)
	fs.fileLock(lockfd, 'u')
end

-------------------------------------------------------------------------------
-- BundleReader

local BundleReader = core.Emitter:extend()
exports.BundleReader = BundleReader

function BundleReader:initialize(basePath, files)
	self.basePath = basePath
	self.files    = files or {}
end

function BundleReader:locate_file(filename)
	for i = 1, #self.files do
		if (filename == self.files[i]) then
			return i
		end
	end
end

function BundleReader:extract(index)
	if (not self.files[index]) then
		return
	end

	local filename = path.join(self.basePath, self.files[index])

	--console.log(filename)
	return fs.readFileSync(filename)
end

function BundleReader:get_num_files()
	return #self.files
end

function BundleReader:get_filename(index)
	return self.files[index]
end

function BundleReader:stat(index)
	if (not self.files[index]) then
		return
	end

	local filename = path.join(self.basePath, self.files[index])
	local statInfo = fs.statSync(filename)
	statInfo.uncomp_size = statInfo.size
	return statInfo
end

function BundleReader:is_directory(index)
	local filename = self.files[index]
	if (not filename) then
		return
	end

	return filename:endsWith('/')
end

local function createBundleReader(filename)

	local listFiles 

	listFiles = function(list, basePath, filename)
		--print(filename)

		local info = fs.statSync(path.join(basePath, filename))
		if (info.type == 'directory') then
			list[#list + 1] = filename .. "/"

			local files = fs.readdirSync(path.join(basePath, filename))
			if (not files) then
				return
			end

			for _, file in ipairs(files) do
				listFiles(list, basePath, path.join(filename, file))
			end

		else

			list[#list + 1] = filename
		end
	end


	local info = fs.statSync(filename)
	if (not info) then
		return
	end

	if (info.type == 'directory') then
		local filedata = fs.readFileSync(path.join(filename, "package.json"))
		local packageInfo = json.parse(filedata)
		if (not packageInfo) then
			return
		end

		local files = fs.readdirSync(filename)
		if (not files) then
			return
		end

		local list = {}

		for _, file in ipairs(files) do
			listFiles(list, filename, file)
		end

		--console.log(list)
		return BundleReader:new(filename, list)

	else
		return miniz.new_reader(filename)
	end
end

-------------------------------------------------------------------------------
-- BundleUpdater

local function cleanFirmwareFile(newVersion)
	function getVersions(nodePath, currentPath, newPath)
		local result = {}
		for name,type in fs.scandirSync(nodePath) do
			if (name == currentPath) or (name == newPath) then
			elseif (type == 'directory' and name:startsWith('v')) then
				result[#result + 1] = name
			end
		  end
		  
		  return result
	end

	-- Current installed version
	local nodePath = conf.rootPath
	local rootPath = fs.readlinkSync(nodePath .. '/bin')
	if (rootPath) then
		rootPath = path.dirname(rootPath)
	else 
		rootPath = app.rootPath
	end
	
	local currentPath = path.basename(rootPath)

	-- The new version to be installed
	local newPath = 'v' .. newVersion

	print("rootPath: " .. rootPath)
	print("nodePath: " .. nodePath)
	print("newPath: " .. newPath)
	print("currentPath: " .. currentPath)

	local versions = getVersions(nodePath, currentPath, newPath)
	-- console.log(nodePath, currentPath, versions)

	for index, name in ipairs(versions) do
		local cmdline = 'rm -rf ' .. nodePath .. '/' .. name;
		print("Remove: " .. cmdline)
		os.execute(cmdline);
	end

	return versions
end

local BundleUpdater = core.Emitter:extend()
exports.BundleUpdater = BundleUpdater

-- 
-- @param options
--  filename
--  rootPath
function BundleUpdater:initialize(options)
	self.filename = options.filename
	self.rootPath = options.rootPath
	self.nodePath = options.nodePath or options.rootPath

	self:reset()
end

-- Check whether the specified file need to updated
-- @param checkInfo 需要的信息如下:
--  - rootPath 目标路径
--  - reader 
--  - index 源文件索引
-- @return 0: not need update; other: need updated
-- 
function BundleUpdater:checkFile(index)
	local join   	= path.join
	local rootPath  = self.rootPath
	local nodePath  = self.nodePath

	local reader   	= self.reader
	local filename  = reader:get_filename(index)
	local dirname   = path.dirname(filename)

	--console.log('dirname', filename, dirname)
	if (not dirname) or (dirname == '.') or (dirname == 'CONTROL') then
		return 0
	end

	local destname 	= join(rootPath, filename)
	local srcInfo   = reader:stat(index)

	--console.log('destname', destname)
	if (reader:is_directory(index)) then
		fs.mkdirpSync(destname)
		-- console.log('mkdirpSync', destname)
		self.folders      = (self.folders or 0) + 1
		return 0
	end
	--console.log(srcInfo)

	self.totalBytes = (self.totalBytes or 0) + srcInfo.uncomp_size
	self.total      = (self.total or 0) + 1

	-- check file size
	local destInfo 	= fs.statSync(destname)
	if (destInfo == nil) then
		return 1, filename

	elseif (srcInfo.uncomp_size ~= destInfo.size) then 
		return 2, filename
	end

	-- check file hash
	local srcData  = reader:extract(index)
	local destData = fs.readFileSync(destname)
	if (srcData ~= destData) then
		return 3, filename
	end

	return 0
end

-- Check for files that need to be updated
-- @param checkInfo
--  - reader 
--  - rootPath 目标路径
-- @return 
-- checkInfo 会被更新的值:
--  - list 需要更新的文件列表
--  - updated 需要更新的文件数
--  - total 总共检查的文件数
--  - totalBytes 总共占用的空间大小
function BundleUpdater:checkAllFiles()
	local count = self.reader:get_num_files()
	for index = 1, count do
		self.index = index
		self:emit('check', index)

		local ret, filename = self:checkFile(index)
		if (ret == 0) then
			self.confirms = (self.confirms or 0) + 1
			self.skips = (self.skips or 0) + 1

		elseif ret and (ret > 0) then
			self.updated = (self.updated or 0) + 1
			table.insert(self.list, index)
			table.insert(self.files, filename)
		else
			self.skips = (self.skips or 0) + 1
		end
	end

	self:emit('check')
end

-- Update the specified file
-- @param rootPath 目标目录
-- @param reader 文件源
-- @param index 文件索引
-- 
function BundleUpdater:updateFile(rootPath, reader, index)
	local join 	 	= path.join

	if (not rootPath) or (not rootPath) then
		return -6, 'invalid parameters' 
	end

	local filename = reader:get_filename(index)
	if (not filename) then
		return -5, 'invalid source file name: ' .. index 
	end	

	-- read source file data
	local fileData 	= reader:extract(index)
	if (not fileData) then
		return -3, 'invalid source file data: ', filename 
	end

	-- write to a temporary file and check it
	local tempname = join(rootPath, filename .. ".tmp")
	local dirname = path.dirname(tempname)
	fs.mkdirpSync(dirname)

	local ret, err = fs.writeFileSync(tempname, fileData)
	if (not ret) then
		return -4, err, filename 
	end

	local destInfo = fs.statSync(tempname)
	if (destInfo == nil) then
		return -1, 'not found: ', filename 

	elseif (destInfo.size ~= #fileData) then
		return -2, 'invalid file size: ', filename 
	end

	-- rename to dest file
	local destname = join(rootPath, filename)
	os.remove(destname)
	local destInfo = fs.statSync(destname)
	if (destInfo ~= nil) then
		return -1, 'failed to remove old file: ' .. filename 
	end

	os.rename(tempname, destname)
	return 0, nil, filename
end

-- Update all Node.lua system files
-- 安装系统更新包
-- @param checkInfo 更新包
--  - reader 
--  - rootPath
-- @param files 要更新的文件列表, 保存的是文件在 reader 中的索引.
-- @param callback 更新完成后调用这个方法
-- @return 
-- checkInfo 会更新的属性:
--  - faileds 更新失败的文件数
function BundleUpdater:updateAllFiles(callback)
	callback = callback or ext.noop

	local rootPath = self.rootPath
	local files = self.list or {}

	if (#files > 0) then
		print('Updating: "' .. rootPath .. '" (total ' 
			.. #files .. ' files need to update).')
	end

	--console.log(self)

	local count = 1
	for _, index in ipairs(files) do

		local ret, err, filename = self:updateFile(rootPath, self.reader, index)
		if (ret == 0) then
			self.confirms = (self.confirms or 0) + 1
		else
			--print('ERROR.' .. index, err)
            self.faileds = (self.faileds or 0) + 1
		end

		self:emit('update', count, filename, ret, err)
		count = count + 1
	end

	self:emit('update')

	callback(nil, self)
end

function BundleUpdater:parsePackageInfo(callback)
	callback = callback or ext.noop

	local reader = self.reader
	if (not reader) then
		callback('The reader is empty!', filename)
		return nil
	end

   	local filename = path.join('package.json')
	local index, err = reader:locate_file(filename)
    if (not index) then
		callback('The `package.json` not found!', filename)
        return
    end

    local filedata = reader:extract(index)
    if (not filedata) then
    	callback('The `package.json` not found!', filename)
    	return
    end

    local packageInfo = json.parse(filedata)
    if (not packageInfo) then
    	callback('The `package.json` is invalid JSON format', filedata)
    	return
    end

    return packageInfo
end

-- 安装系统更新包
-- @param checkInfo 更新包
--  - filename 
--  - rootPath
-- @param callback 更新完成后调用这个方法
-- @return
-- checkInfo 会更新的属性:
--  - list
--  - total
--  - updated
--  - totalBytes
--  - faileds
-- 
function BundleUpdater:upgradeSystemPackage(callback)
	callback = callback or ext.noop

	local filename 	= self.filename
	if (not filename) or (filename == '') then
		callback("Invalid update filename")
		return
	end

	--print('update file: ' .. tostring(filename))
	print('Installing: (' .. filename .. ')')

	local reader = createBundleReader(filename)
	if (reader == nil) then
		callback("Bad update package format", filename)
		return
	end

	self.reader	= reader

 	local packageInfo = self:parsePackageInfo(callback)

    -- 验证安装目标平台是否一致
    if (packageInfo.target) then
		local target = ext.getSystemTarget()
		if (target ~= packageInfo.target) then
			callback('Mismatched target: local is `' .. target .. 
				'`, but the update file is `' .. tostring(packageInfo.target) .. '`')
	    	return
		end

	else
		callback("Upgrade error: bad package information file", filename)
		return
	end

	self:reset()

    self.version    = packageInfo.version
	self.target     = packageInfo.target

	if (not self.version) then
		print('Invalid version');
		return
	end

	self.rootPath = self.rootPath .. '/v' .. self.version
	
	print('Version: ' .. self.version)
	print('Path: ' .. self.rootPath)

	cleanFirmwareFile(self.version)

	self:checkAllFiles() -- 检查需要更新的文件
	self:updateAllFiles(callback) -- 写入修改的文件

	os.execute('chmod -R 755 ' .. self.rootPath .. '/bin/*')
end

function BundleUpdater:reset()
	self.list 		= {}
	self.total 	 	= 0
	self.updated 	= 0
	self.skips      = 0
	self.totalBytes = 0
    self.faileds 	= 0
	self.files      = {}
	self.folders    = 0
	self.index      = 0
	self.confirms   = 0
end

function BundleUpdater:getUpgradeResult()
	if (self.faileds and self.faileds > 0) then
		return string.format('Total (%d) error has occurred!', self.faileds)

	elseif (self.updated and self.updated > 0) then
		return nil, string.format('Total (%d) files has been updated!', self.updated)

	else
		return nil, 'Finished'
	end
end

local function installFirmwareFile(callback)
	if (type(callback) ~= 'function') then
		callback = function(err, message)
			if (err) then
				print('Failed:', err)
				return
			end

			print('Done: ' .. (message or ''))
		end
	end

	local lockfd = upgradeLock()
	if (not lockfd) then
		callback('Error: Upgrade lock failed')
		return
	end

	local nodePath = getNodePath()

	if (isDevelopmentPath(nodePath)) then
		
	end

	if (not filename) then
		filename = path.join(nodePath, 'update/update.zip')
	end

	local options = {}
	options.filename 	= filename
	options.rootPath 	= nodePath

	local updater = BundleUpdater:new(options)

	updater:on('update', function(index, filename, ret, err)
		local total = updater.updated or 0
		if (index) then
			console.write('\rUpdating: (' .. index .. '/' .. total .. ')...  ')
			if (ret == 0) then
				print(filename or '')
			end
		else
			print('')
		end
	end)

	updater:upgradeSystemPackage(function(err)
		upgradeUnlock(lockfd)

		if (err) then
			print("Error: ", err)
			return
		end

		if (callback) then 
			callback(updater:getUpgradeResult())
		end

		print('Files: ' .. updater.total)
		print('Updated: ' .. updater.updated)
		print('Faileds: ' .. updater.faileds)
		print('Total Bytes: ' .. updater.totalBytes)
		print('Folders: ' .. updater.folders)
		print('Skips: ' .. updater.skips)
		print('Index: ' .. updater.index)
		print('Confirms: ' .. updater.confirms)
		print('Path: ' .. updater.rootPath)

		if (updater.faileds > 0) then
			return
		end

		local rootPath = updater.rootPath
		setTimeout(1000, function()
			-- 
			local cmdline = rootPath .. '/bin/lnode -d -l lpm/switch > /tmp/switch.log'
			console.log(cmdline)
			os.execute(cmdline)
		end)
	end)

	return true
end

-------------------------------------------------------------------------------
-- exports

exports.nodePath = getNodePath()

function exports.isDevelopmentPath(pathname)
	return isDevelopmentPath(pathname or getNodePath())
end

function exports.openBundle(filename)
	return createBundleReader(filename)
end

function exports.openUpdater(options)
	return BundleUpdater:new(options)
end

function exports.clean(version)
	cleanFirmwareFile(version)
end

function exports.install(filename, callback)
	installFirmwareFile(filename, callback)
end

return exports
