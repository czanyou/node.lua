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
local http      = require('http')
local json      = require('json')
local miniz     = require('miniz')
local path      = require('path')
local thread    = require('thread')
local timer     = require('timer')
local url       = require('url')
local utils     = require('utils')
local qstring   = require('querystring')

local request  	= require('http/request')
local conf   	= require('ext/conf')
local ext   	= require('ext/utils')


--[[
Node.lua 系统更新程序
======

这个脚本用于自动在线更新 Node.lua SDK, 包含可执行主程序, 核心库, 以及核心应用等等

--]]

local exports = {}

local formatFloat 		= ext.formatFloat
local formatBytes 		= ext.formatBytes
local noop 		  		= ext.noop
local getSystemTarget 	= ext.getSystemTarget

local SSDP_WEB_PORT 	= 9100

local function getNodePath()
	return conf.rootPath
end

local function getRootPath()
	return '/'
end

local function getRootURL()
	return require('app').rootURL
end

local function isDevelopmentPath(rootPath)
	local filename1 = path.join(rootPath, 'lua/lnode')
	local filename2 = path.join(rootPath, 'app/build')
	local filename3 = path.join(rootPath, 'src')
	if (fs.existsSync(filename1) or fs.existsSync(filename2) or fs.existsSync(filename3)) then
		print('The "' .. rootPath .. '" is a development path.')
		print('You can not update the system in development mode.\n')
		return true
	end

	return false
end

-- 检查是否有另一个进程正在更新系统
local function upgradeLock()
	local tmpdir = os.tmpdir or '/tmp'

	print("Try to lock upgrade...")

	local lockname = path.join(tmpdir, '/update.lock')
	local lockfd = fs.openSync(lockname, 'w+')
	local ret = fs.fileLock(lockfd, 'w')
	if (ret == -1) then
		print('The system update is already locked!')
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

local BundleUpdater = core.Emitter:extend()
exports.BundleUpdater = BundleUpdater

function BundleUpdater:initialize(options)
	self.filename = options.filename
	self.rootPath = options.rootPath
	self.nodePath = options.nodePath or options.rootPath
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
	local dirname = path.dirname(filename)
	if (not dirname) or (dirname == '.') or (dirname == 'CONTROL') then
		return 0
	end

	local destname 	= join(rootPath, filename)
	local srcInfo   = reader:stat(index)

	if (reader:is_directory(index)) then
		fs.mkdirpSync(destname)
		return 0
	end
	--console.log(srcInfo)

	self.totalBytes = (self.totalBytes or 0) + srcInfo.uncomp_size
	self.total      = (self.total or 0) + 1

	--thread.sleep(10) -- test only

	-- check file size
	local destInfo 	= fs.statSync(destname)
	if (destInfo == nil) then
		return 1

	elseif (srcInfo.uncomp_size ~= destInfo.size) then 
		return 2
	end

	-- check file hash
	local srcData  = reader:extract(index)
	local destData = fs.readFileSync(destname)
	if (srcData ~= destData) then
		return 3
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

		local ret = self:checkFile(index)
		if (ret > 0) then
			self.updated = (self.updated or 0) + 1
			table.insert(self.list, index)
		end
	end

	self:emit('check')
end

-- 检查系统存储空间
-- 主要是为了检查是否有足够的剩余空间用来更新固件
function BundleUpdater:checkStorage()
	-- check storage size
	local lutils = require('lutils')
	local statInfo = lutils.os_statfs(self.rootPath)
	if (not statInfo) then
		return
	end

	local totalSize = statInfo.blocks * statInfo.bsize
	local freeSize  = statInfo.bfree  * statInfo.bsize
	if (totalSize > 0) then
		local percent = math.floor(freeSize * 100 / totalSize)
		print(string.format('storage: %s/%s percent: %d%%', 
			formatBytes(freeSize), 
			formatBytes(totalSize), percent))
	end
end

-- Update the specified file
-- @param rootPath 目标目录
-- @param reader 文件源
-- @param index 文件索引
-- 
function BundleUpdater:updateFile(rootPath, reader, index)
	local join 	 	= path.join

	--thread.sleep(10) -- test only

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
	callback = callback or noop

	local rootPath = self.rootPath
	local files = self.list or {}
	print('Upgrading system "' .. rootPath .. '" (total ' 
		.. #files .. ' files need to update).')

	--console.log(self)

	local count = 1
	for _, index in ipairs(files) do

		local ret, err, filename = self:updateFile(rootPath, self.reader, index)
		if (ret ~= 0) then
			--print('ERROR.' .. index, err)
            self.faileds = (self.faileds or 0) + 1
		end

		self:emit('update', count, filename, ret, err)
		count = count + 1
	end

	self:emit('update')

	fs.chmodSync(rootPath .. '/usr/local/lnode/bin/lnode', 511)
	fs.chmodSync(rootPath .. '/usr/local/lnode/bin/lpm', 511)

	callback(nil, self)
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
	callback = callback or noop

	local filename 	= self.filename
	if (not filename) or (filename == '') then
		callback("Invalid update filename")
		return
	end

	--print('update file: ' .. tostring(filename))
	print('\nInstalling package (' .. filename .. ')')

	local reader = createBundleReader(filename)
	if (reader == nil) then
		callback("Bad update package format", filename)
		return
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

    -- 验证安装目标平台是否一致
    if (packageInfo.target) then
		local target = getSystemTarget()
		if (target ~= packageInfo.target) then
			callback('Mismatched target: local is `' .. target .. 
				'`, but the update file is `' .. tostring(packageInfo.target) .. '`')
	    	return
		end

	elseif (packageInfo.name) then
		-- Signal Application update file
		self.name     = packageInfo.name
		self.rootPath = path.join(self.rootPath, 'app', self.name)

	else
		callback("Upgrade error: bad package information file", filename)
		return
	end

	self.list 		= {}
	self.total 	 	= 0
    self.updated 	= 0
	self.totalBytes = 0
    self.faileds 	= 0
    self.version    = packageInfo.version
    self.target     = packageInfo.target
	self.reader	 	= reader

	self:checkAllFiles()
	self:updateAllFiles(callback)
end

function BundleUpdater:showUpgradeResult()
	if (self.faileds and self.faileds > 0) then
		print(string.format('Total (%d) error has occurred!', self.faileds))

	elseif (self.updated and self.updated > 0) then
		print(string.format('Total (%d) files has been updated!', self.updated))

	else
		print('\nFinished\n')
	end
end

-------------------------------------------------------------------------------
-- download

-- Download system patch file
local function downloadSystemPackage(options, callback)
	callback = callback or noop

	local nodePath  = getNodePath()
	local basePath  = path.join(nodePath, 'update')
	local ret, err = fs.mkdirpSync(basePath)
	if (err) then
		print(err)
		return
	end

	--console.log(options)
	local filename = path.join(basePath, '/' .. (options.type or 'update') .. '.zip')

	-- 检查 SDK 更新包是否已下载
	local packageInfo = options.packageInfo
	--print(packageInfo.size, packageInfo.md5sum)
	if (packageInfo and packageInfo.size) then
		local filedata = fs.readFileSync(filename)
		if (filedata and #filedata == packageInfo.size) then
			local md5sum = utils.bin2hex(utils.md5(filedata))
			--print('md5sum', md5sum)

			if (md5sum == packageInfo.md5sum) then
				print("The update file is up-to-date!", filename)
				callback(nil, filename)
				return
			end
		end
	end

	-- 下载最新的 SDK 更新包
	request.download(options.url, {}, function(err, percent, response)
		if (err) then 
			print(err)
			callback(err)
			return 
		end

		if (percent == 0 and response) then
			local contentLength = tonumber(response.headers['Content-Length']) or 0

			print('Downloading package (' .. ext.formatBytes(contentLength) .. ').')
		end

		if (percent <= 100) then
			console.write('\rDownloading package (' .. percent .. '%)...  ')
		end

		if (percent < 100) or (not response) then
			return
		end

		-- write to a temp file
		print('Done!')

		os.remove(filename)
		fs.writeFile(filename, response.body, function(err)
			if (err) then 
				callback(err)
				return
			end

			callback(nil, filename)
		end)
	end)
end

local function parseVersionNumber(value)
	value = tonumber(value) or 0
	return value % 10000
end

local function parseVersion(version)
	if (type(version) ~= 'string') then
		return 0
	end

	local tokens = version:split('.')
	return (parseVersionNumber(tokens[1]) * 10000 * 10000) 
		 + (parseVersionNumber(tokens[2]) * 10000) 
		 + (parseVersionNumber(tokens[3]))
end

-- Download system 'package.json' file
local function downloadSystemInfo(options, callback)
	options = options or {}
	local printInfo = options.printInfo or function() end

	-- URL
	local arch      = os.arch()
	local target 	= getSystemTarget()
	local rootURL 	= getRootURL()
	local baseURL 	= rootURL .. '/download/dist/' .. target
	local url 		= baseURL .. '/nodelua-' .. target .. '-' .. (options.type or 'sdk') .. '.json'

	printInfo("System target: " .. target)
	printInfo("Upgrade server: " .. rootURL)	
	printInfo('URL: ' .. url)

	request.download(url, {}, function(err, percent, response)
		if (err) then
			callback(err)
			return

		elseif (percent < 100) or (not response) then
			return
		end

		--console.log(response.body)
		local packageInfo = json.parse(response.body)
		if (not packageInfo) or (not packageInfo.version) then
			callback("Invalid system package information.")
			return
		end

		local version = parseVersion(packageInfo.version)
		local current = parseVersion(process.version)
		if (version < current) then
			print('The update package version is less than current version: v' .. tostring(packageInfo.version))
			return
		end

		local nodePath  = getNodePath()
		local basePath  = path.join(nodePath, 'update')
		local ret, err = fs.mkdirpSync(basePath)
		if (err) then
			print(err)
			return
		end

		local filename 	= path.join(basePath, 'package.json')
		local filedata  = fs.readFileSync(filename)
		if (filedata == response.body) then
			print("The system information is up-to-date!")
			callback(nil, packageInfo)
			return
		end

		local tempname 	= path.join(basePath, 'package.json.tmp')
		os.remove(tempname)

		fs.writeFile(tempname, response.body, function(err)
			if (err) then 
				callback(err)
				return
			end

			os.remove(filename)
			local ret, err = os.rename(tempname, filename)
			if (err) then
				print(err)
				return
			end

			print("System information saved to: " ..  filename)
			callback(nil, packageInfo)
		end)
	end)
end

-- download system 'package.json' and patch files
local function downloadUpdateFiles(options, callback)
	options = options or {}
	local printInfo = options.printInfo or function() end

	downloadSystemInfo(options, function(err, packageInfo)
		if (err) then 
			callback(err)
			return
		end

		-- System update filename
		if (not packageInfo) or (not packageInfo.filename) then
			callback("Bad package information format!")
			return
		end

		printInfo("Done.")

		-- System update URL
		local target 	= getSystemTarget()
		local rootURL 	= getRootURL()
		local baseURL 	= rootURL .. '/download/dist/' .. target
		local url 		= baseURL .. '/' .. packageInfo.filename
		printInfo('Package url: ' .. url)

		-- downloading
		local args = {}
		args.url 		 = url
		args.type        = options.type
		args.packageInfo = packageInfo
		downloadSystemPackage(args, function(err, filename)
			printInfo("Done.")
			callback(err, filename, packageInfo)
		end)

	end)
end

-- Update system update file
local function updateUpdateFile(filename)
	local nodePath  = getNodePath()
	local basePath  = path.join(nodePath, 'update')
	local destFile  = path.join(basePath, 'update.zip')

	if (filename == destFile) then
		return filename
	end

	local statInfo1  = fs.statSync(filename) or {}
	if (statInfo1.type == 'directory') then
		return filename
	end

	local sourceSize = statInfo1.size or 0

	local statInfo2  = fs.statSync(destFile) or {}
	local destSize   = statInfo2.size or 0

	if (sourceSize == destSize) then
		print("The update file is up-to-date!")
		return destFile
	end

	local ret, err = fs.mkdirpSync(basePath)
	if (err) then
		print('error', err)
		return filename
	end

	local fileData = fs.readFileSync(filename)
	if (not fileData) then
		print('error', 'read source file failed')
		return filename
	end

	local ret, err = fs.writeFileSync(destFile, fileData)
	if (err) then
		print('error', err)
		return filename
	end

	print("Copy update.zip to " .. destFile)
	return destFile
end

-------------------------------------------------------------------------------
-- exports

function exports.check()
	local target = getSystemTarget()
	local options = {
		printInfo = function(...)
			print(...)
		end
	}

	downloadSystemInfo(options, function(err, packageInfo)
		if (err) then 
			print(err)
			return
		end

		if (not packageInfo) or (not packageInfo.filename) then
			print("Bad package information format!")
			return
		end

		print('')
		local grid = ext.table({20, 50})
		grid.line()
		grid.title('System information')
		grid.line('=')
		grid.cell('target      ', tostring(packageInfo.target))
		grid.cell('arch        ', tostring(packageInfo.arch))
		grid.cell('description ', tostring(packageInfo.description))
		grid.cell('version     ', tostring(packageInfo.version))
		grid.cell('mtime       ', tostring(packageInfo.mtime))
		grid.cell('size        ', tostring(packageInfo.size))
		grid.cell('md5sum      ', tostring(packageInfo.md5sum))
		grid.cell('applications', json.stringify(packageInfo.applications))
		grid.cell('Update file ', packageInfo.filename)
		grid.line()

		print('')
		print("Done.")
	end)
end


function exports.help()
	print(console.colorful[[

${braces}Node.lua packages upgrade tools${normal}

Usage:
  ldb connect [hostname] [password] ${braces}Connect a device with password${normal}
  ldb deploy [hostname] [password]  ${braces}Update all packages on the device${normal}
  ldb disconnect                    ${braces}Disconnect the current device${normal}
  ldb install [name]                ${braces}Install a application to the device${normal}
  ldb remove [name]                 ${braces}Remove a application on the device${normal}
  lpm scan [timeout]                ${braces}Scan devices${normal}
  lpm upgrade [name] [rootPath]     ${braces}Update all packages${normal}

upgrade: 
  ${braces}This command will update all the packages listed to the latest version
  If the package <name> is "all", all packages in the specified location
  (global or local) will be updated.${normal}

deploy:
  ${braces}Update all packages on the device to the latest version.${normal}

]])

end

function exports.remove(name)
	if (not name) or (name == '') then
		print([[
Usage: ldb remove [options] <name>

options:
  -g remove from global path
]])		
		return
	end

	local appPath = path.join(path.dirname(os.tmpname()), 'app')
	local filename = path.join(appPath, name) or ''
	if (fs.existsSync(filename)) then
		os.execute("rm -rf " .. filename)
		print("removed: '" .. filename  .. "'")
	else
		print("not exists: '" .. filename  .. "'")
	end
end

function exports.install(filename, callback)
	if (type(callback) ~= 'function') then
		callback = nil
	end

	local lockfd = upgradeLock()
	if (not lockfd) then
		return
	end

	local nodePath = getNodePath()
	local rootPath = getRootPath()
	if (isDevelopmentPath(nodePath)) then
		rootPath = '/tmp' -- only for test
	end

	--console.log(source, rootPath)
	print("Upgrade path: " .. nodePath)

	local options = {}
	options.filename 	= filename
	options.rootPath 	= rootPath

	local updater = BundleUpdater:new(options)
	if (not callback) then 
		updater:on('check', function(index)
			if (index) then
				console.write('\rChecking (' .. index .. ')...  ')
			else 
				print('')
			end
		end)

		updater:on('update', function(index, filename, ret, err)
			local total = updater.updated or 0
			if (index) then
				console.write('\rUpdating (' .. index .. '/' .. total .. ')...  ')
				if (ret == 0) then
					print(filename or '')
				end
			else
				print('')
			end
		end)
	end

	updater:upgradeSystemPackage(function(err)
		upgradeUnlock(lockfd)

		if (callback) then 
			callback(err, updater)
			return 
		end

		if (err) then print(err) end
		updater:showUpgradeResult()
	end)

	return true
end

function exports.handleInstallPost(data, query, callback)
    print('Upload complete.')

    local filename = '/tmp/install.zip'
    if (not data) then
        callback({ ret = -1, error = 'Bad request' })
        return
    end

    print('file', filename, #data)

    query = query or {}
    local dest = query.dest

    os.remove(filename)
    fs.writeFileSync(filename, data)

    local options = {}
	options.filename   = filename or '/tmp/install.zip'
	options.rootPath   = getNodePath()

	local updater = BundleUpdater:new(options)
	updater:upgradeSystemPackage(function(err)
        local result = { ret = 0, error = err }

        if (updater.faileds and updater.faileds > 0) then
            result.ret = -1
            result.error = string.format('(%d) error has occurred in the upgrade!', updater.faileds)
        end

        local data = {}
        data.total      = updater.total
        data.totalBytes = updater.totalBytes
        data.updated    = updater.updated
        data.faileds    = updater.faileds
        data.rootPath   = updater.rootPath
        data.name       = updater.name
        result.data = data

        callback(result)
    end)
end

function exports.handleUpgradePost(data, query, callback)
    if (not data) then
        callback({ ret = -1, error = 'Bad request' })
        return
    end

    query = query or {}

    local filename = '/tmp/update.zip'
    print('file', filename, #data)

    os.remove(filename)
    fs.writeFileSync(filename, data)

    exports.install(filename, function(err, updater)
        local result = { ret = 0, error = err }
        updater = updater or {}

        if (updater.faileds and updater.faileds > 0) then
            result.ret = -1
            result.error = string.format('(%d) error has occurred in the upgrade!', checkInfo.faileds)
        end

        local data = {}
        data.total      = updater.total
        data.totalBytes = updater.totalBytes
        data.updated    = updater.updated
        data.faileds    = updater.faileds
        data.rootPath   = updater.rootPath
        data.name       = updater.name
        result.data = data

        callback(result)
    end)
end

function exports.recovery()
	local destpath   = '/usr/local/lnode'
	local updatefile = path.join(destpath, 'update/update.zip')
	exports.install(updatefile, destpath)
end

function exports.update(source, callback)
	if (type(source) == 'function') then
		callback = source
		source = nil
	end

	if (source == 'system') then
		source = 'sdk'
	else
		source = 'patch'
	end

	local options = { type = source }
	if (type(callback) == 'function') then
		downloadUpdateFiles(options, callback)
		return
	end

	callback = function(err, filename, packageInfo)
		packageInfo = packageInfo or {}

		--console.log(err, filename, packageInfo)
		if (err) then
			print('err: ', err)

		else
			print('latest version: ' .. tostring(packageInfo.version))
		end
	end

	options.printInfo = function(...) print(...) end

	downloadUpdateFiles(options, callback)
end

--[[
更新系统

--]]
function exports.upgrade(source, callback)
	if (type(callback) ~= 'function') then
		callback = nil
	end

	source = source or 'patch'

	if source:startsWith("/") then
		-- 从本地文件升级
		-- function(filename)
		exports.install(source, callback)
		return
	end
	
	if (source == 'system') then
		source = 'sdk'
	else
		source = 'patch'
	end

	-- Upgrade form network
	downloadUpdateFiles({type = source}, function(err, filename)
		if (err) then
			console.log('upgrade', err)
			return
		end

		exports.install(filename, callback)
	end)
end

return exports
