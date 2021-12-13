--[[

Copyright 2016-2020 The Node.lua Authors. All Rights Reserved.

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
local path      = require('path')
local app       = require('app')
local conf   	= require('app/conf')
local bundle    = require('app/bundle')

--[[
Node.lua 系统更新程序
======

这个脚本用于自动在线更新 Node.lua SDK, 包含可执行主程序, 核心库, 以及核心应用等等

--]]

-------------------------------------------------------------------------------

local exports = {}

-------------------------------------------------------------------------------

local function noop()

end

local function getNodePath()
	return conf.rootPath
end

local function cleanFirmwareFile(newVersion)
	local function getVersions(nodePath, currentPath, newPath)
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

	print("Root Path: " .. rootPath)
	print("Node Path: " .. nodePath)
	print("New Path: " .. newPath)
	print("Current Path: " .. currentPath)

	local versions = getVersions(nodePath, currentPath, newPath)
	-- console.log("versions: ", versions)
	-- console.log(nodePath, currentPath, versions)
	if (versions and #versions > 0) then
		for index, name in ipairs(versions) do
			local cmdline = 'rm -rf ' .. nodePath .. '/' .. name;
			print("Remove: " .. nodePath .. '/' .. name)
			os.execute(cmdline);
		end
	end

	local stat = fs.statfs(nodePath)
	if (stat) then
		local freeSize = stat.bsize * stat.bfree
		print("Free Size: " .. math.floor(freeSize / (1024 * 1024)) .. "MB")
	end

	return versions
end

-------------------------------------------------------------------------------
-- BundleUpdater

---@class BundleUpdater
local BundleUpdater = core.Emitter:extend()
exports.BundleUpdater = BundleUpdater

--
---@param options BundleUpdaterOptions
function BundleUpdater:initialize(options)
	---@class BundleUpdaterOptions
	---@field public filename string
	---@field public rootPath string
	---@field public nodePath string
	options = options or {}
	self.filename = options.filename
	self.rootPath = options.rootPath
	self.nodePath = options.nodePath or options.rootPath

	if (not self.filename) then
		print('missed updater options: filename')
	end

	if (not self.rootPath) then
		print('missed updater options: rootPath')
	end

	self.index = nil
	self.confirms = nil
	self.skips = nil
	self.updated = nil

	self.version = nil
	self.target = nil

	self:reset()
end

-- 检查是否有另一个进程正在更新系统
function BundleUpdater:upgradeLock()
	local tmpdir = os.tmpdir or '/tmp'

	print("Upgrade: Start")

	local lockname = path.join(tmpdir, '/lock/update.lock')
	local lockfd = fs.openSync(lockname, 'w+')
	local ret = fs.fileLock(lockfd, 'w')
	if (ret == -1) then
		print('Error: The update already locked!')
		return nil
	end

	return lockfd
end

-- Check whether the specified file need to updated
---@param index integer 源文件索引
-- @return 0: not need update; other: need updated
function BundleUpdater:checkFile(index)
	local join = path.join

	local rootPath  = self.rootPath

	local reader = self.reader
	if (not reader) then
		return 0
	end

	local filename  = reader:getFilename(index)
	local dirname   = path.dirname(filename)

	--console.log('dirname', filename, dirname)
	if (not dirname) or (dirname == '.') or (dirname == 'CONTROL') then
		return 0
	end

	local destname 	= join(rootPath, filename)
	local srcInfo   = reader:stat(index)

	--console.log('destname', destname)
	if (reader:isDirectory(index)) then
		fs.mkdirpSync(destname)
		-- console.log('mkdirpSync', destname)
		self.folders      = (self.folders or 0) + 1
		return 0
	end
	--console.log(srcInfo)

	self.totalBytes = (self.totalBytes or 0) + srcInfo.uncomp_size
	self.total      = (self.total or 0) + 1

	-- console.log('filename', filename)

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
-- @return
-- checkInfo 会被更新的值:
--  - list 需要更新的文件列表
--  - updated 需要更新的文件数
--  - total 总共检查的文件数
--  - totalBytes 总共占用的空间大小
function BundleUpdater:checkAllFiles()
	local reader = self.reader
	if (not reader) then
		return 0
	end

	local count = reader:getFileCount()
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
---@param index integer 文件索引
---@return
function BundleUpdater:updateFile(index)
	local reader = self.reader
	if (not reader) then
		return 0
	end

	local join = path.join

	local rootPath = self.rootPath
	if (not rootPath) or (not rootPath) then
		return -6, 'invalid parameters'
	end

	local filename = reader:getFilename(index)
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
	destInfo = fs.statSync(destname)
	if (destInfo ~= nil) then
		return -1, 'failed to remove old file: ' .. filename
	end

	if (filename:startsWith('bin/')) then
		local flags = tonumber('0777', 8)
		fs.chmodSync(tempname, flags);
	end

	os.rename(tempname, destname)
	return 0, nil, filename
end

-- Update all Node.lua system files
-- 安装系统更新包
---@param callback fun 更新完成后调用这个方法
-- checkInfo 会更新的属性:
--  - faileds 更新失败的文件数
function BundleUpdater:updateAllFiles(callback)
	callback = callback or noop

	local rootPath = self.rootPath
	local files = self.list or {}

	if (#files > 0) then
		print('Updating: "' .. rootPath .. '" (total '
			.. #files .. ' files need to update).')
	end

	--console.log(self)

	local count = 1
	for _, index in ipairs(files) do

		local ret, err, filename = self:updateFile(index)
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

function BundleUpdater:parsePackageInfo()
	return exports.getPackageInfo(self.reader)
end

---@return BundleReader
---@return string - error
function BundleUpdater:openBundle()
	local filename 	= self.filename
	if (not filename) or (filename == '') then
		return nil, "Invalid update filename"
	end

	--print('update file: ' .. tostring(filename))
	print('Installing: (' .. filename .. ')')

	local reader = bundle.openBundle(filename)
	if (reader == nil) then
		return nil, "Bad package bundle format"
	end

	return reader
end

---@return any - packageInfo
---@return string - error
function BundleUpdater:checkBundle()
	local packageInfo, err = self:parsePackageInfo()
	if (not packageInfo) then
		return nil, err
	end

    -- 验证安装目标平台是否一致
	if (not packageInfo.target) then
		return nil, "Upgrade error: bad package information file"
	end

	local target = app.getSystemTarget()
	if (target ~= packageInfo.target) then
		local message = 'Mismatched target: local is `' .. target ..
			'`, but the update file is `' .. tostring(packageInfo.target) .. '`'
		return nil, message
	end

	if (not packageInfo.version) then
		return nil, 'Invalid bundle version';
	end

    self.version = packageInfo.version
	self.target  = packageInfo.target
	self.rootPath = self.rootPath .. '/v' .. self.version

	return packageInfo
end

-- 安装系统更新包
---@param callback fun 更新完成后调用这个方法
function BundleUpdater:upgradeSystemPackage(callback)
	callback = callback or noop

	-- openBundle
	self:reset()
	local reader, err = self:openBundle()
	if (reader == nil) then
		callback(err)
		return
	end

	self.reader	= reader

	-- checkBundle
	local packageInfo
	packageInfo, err = self:checkBundle()
	if (packageInfo == nil) then
		callback(err)
		return
	end

	print('Version: ' .. self.version)
	print('Path: ' .. self.rootPath)

	-- clean
	cleanFirmwareFile(self.version)

	-- update
	self:checkAllFiles() -- 检查需要更新的文件
	self:updateAllFiles(callback) -- 写入修改的文件
end

function BundleUpdater:reset()
	self.confirms   = 0
	self.faileds 	= 0
	self.files      = {}
	self.folders    = 0
	self.index      = 0
	self.list 		= {}
	self.skips      = 0
	self.total 	 	= 0
	self.totalBytes = 0
	self.updated 	= 0
end

---@return string error
---@return string message
---@return integer count
function BundleUpdater:getUpgradeResult()
	if (self.faileds and self.faileds > 0) then
		return string.format('Total (%d) error has occurred!', self.faileds)

	elseif (self.updated and self.updated > 0) then
		return nil, string.format('Total (%d) files has been updated!', self.updated)

	else
		return nil, 'Finished'
	end
end

function BundleUpdater:printUpdateResult()
	print('Root Path: ' .. tostring(self.rootPath))
	print('Total files: ' .. tostring(self.total))

	if (self.folders > 0) then
		print('Total folders: ' .. tostring(self.folders))
	end

	print('Total bytes: ' .. tostring(self.totalBytes))

	if (self.updated > 0) then
		print('Updated files: ' .. tostring(self.updated))
	end

	if (self.faileds > 0) then
		print('Failed files: ' .. tostring(self.faileds))
	end

	if (self.skips > 0) then
		print('Skiped files: ' .. tostring(self.skips))
	end

	-- print('Index: ' .. tostring(self.index))
	print('Confirm files: ' .. tostring(self.confirms))
end

-------------------------------------------------------------------------------
-- exports

exports.nodePath = getNodePath()

-- 清除所有旧的，不会再使用的固件版本
---@param version string
function exports.clean(version)
	cleanFirmwareFile(version)
end

---@return integer
function exports.getFreeFlashSize()
	local nodePath = conf.rootPath
	local stat = fs.statfs(nodePath)
	if (stat) then
		return stat.bsize * stat.bfree
	end
end

---@param reader BundleReader
function exports.getPackageInfo(reader)
	if (not reader) then
		return nil, 'The reader is empty!'
	end

    local filedata = reader:readFile('package.json')
    if (not filedata) then
    	return nil, 'The `package.json` not found!'
    end

    local packageInfo = json.parse(filedata)
    if (not packageInfo) then
    	return nil, 'The `package.json` is invalid JSON format', filedata
    end

    return packageInfo
end

-- 安装指定的固件文件
---@param filename string
---@param callback fun(err:string, result:any)
function exports.install(filename, callback)
	if (type(filename) == 'function') then
		callback = filename
		filename = nil
	end

	if (type(callback) ~= 'function') then
		callback = function(err, message)
			if (err) then
				print('Failed:', err)
				return
			end

			print('Done: ' .. (message or ''))
		end
	end

	if (not app.lock('install')) then
		callback('Error: install lock failed')
		return
	end

	if (not filename) then
		filename = path.join(os.tmpdir, 'update/update.zip')
	end

	local nodePath = getNodePath()
	local options = { filename = filename, rootPath = nodePath }
	local updater = BundleUpdater:new(options)

	local function printUpdateProgress(index, filename, ret, err)
		local total = updater.updated or 0
		if (index) then
			console.write('\rUpdating: (' .. index .. '/' .. total .. ')...  ')
			if (ret == 0) then
				print(filename or '')
			end
		else
			print('')
		end
	end

	local function switchVersion(rootPath)
		setTimeout(400, function()
			print('Switch to new version...')

			local cmdline = rootPath .. '/bin/lnode -d -l lpm/switch > /tmp/log/switch.log'
			-- console.log('cmdline', cmdline)
			os.execute(cmdline)
		end)
	end

	updater:on('update', printUpdateProgress)
	updater:upgradeSystemPackage(function(err)
		if (err) then
			callback(err)
			return
		end

		-- check result
		updater:printUpdateResult()

		if (updater.faileds) and (updater.faileds > 0) then
			print('Update failed!: ')
			callback('faileds: ' .. updater.faileds)

		else
			-- switch to new version
			local rootPath = updater.rootPath
			os.execute('rm -rf /tmp/.lnode/')
			switchVersion(rootPath)

			callback(nil, updater:getUpgradeResult())
		end
	end)

	return true
end

---@param pathname string
---@return boolean
function exports.isDevelopmentPath(pathname)
	local rootPath = pathname or getNodePath()
	local filename1 = path.join(rootPath, 'lua/lnode')
	local filename2 = path.join(rootPath, 'app/lbuild')
	local filename3 = path.join(rootPath, 'src')
	if (fs.existsSync(filename1) or fs.existsSync(filename2) or fs.existsSync(filename3)) then
		print('Warning: The "' .. rootPath .. '" is in development mode.')
		return true
	end

	return false
end

---@param options BundleUpdaterOptions
---@return BundleUpdater
function exports.openUpdater(options)
	if (not options) then
		return
	end

	return BundleUpdater:new(options)
end

return exports
