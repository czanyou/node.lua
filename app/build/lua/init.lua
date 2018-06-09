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

local core   = require('core')
local fs     = require('fs')
local http   = require('http')
local init   = require('init')
local json   = require('json')
local miniz  = require('miniz')
local path   = require('path')
local thread = require('thread')
local timer  = require('timer')
local url    = require('url')
local utils  = require('util')
local uv     = require('uv')
local app    = require('app')

local zlib	 = require('zlib')
local conf   = require('app/conf')

local exports = {}

local function getRootPath()
	return app.rootPath
end

local function getRootURL()
	return require('app').rootURL
end

-------------------------------------------------------------------------------
-- options

local options = {}
options.BOARD 			= "test"
options.CACHE_PATH 		= "/tmp/cache"
options.EXT_NAME 		= ".so"
options.PACKAGE_JSON 	= "package.json"
options.PACKAGES_JSON 	= "packages.json"
options.ROOT_PATH 		= getRootPath()
options.SOURCE_URL		= getRootURL() .. "/download/packages.json"
exports.options 		= options

function lpm_load_settings()
	options.CACHE_PATH = path.join(options.ROOT_PATH, 'cache')

	local profile, err = conf("user")
	if type(profile) ~= 'table' then
		return
	end

	options.conffile 	= profile.filename
	options.BOARD 		= profile:get("lpm.board")  or options.BOARD
	options.SOURCE_URL 	= profile:get("lpm.source") or options.SOURCE_URL

	--console.log(options)
end

lpm_load_settings()
--console.log(exports)

local function request(url, callback)
	callback = callback or function() end

	local request = http.get(url, function(response)
		local data = {}

		response:on('data', function(chunk)
			table.insert(data, chunk)
		end)

		response:on('end', function()
			if (response.statusCode ~= 200) then
				callback('ERROR: server returned ' .. response.statusCode)
				return
			end

			local content = table.concat(data)
			callback(nil, response, content)
		end)
	end)

	request:on('error', function(error) 
		callback(error)
	end)
end


local function readBundleFile(filename, path)
    if (type(path) ~= 'string') then
        return nil, "bad path"

    elseif (type(filename) ~= 'string') then
        return nil, "bad filename"
    end

    local reader = miniz.new_reader(filename)
    if (reader == nil) then
        return nil, "bad bundle file"
    end

    local index, err = reader:locate_file(path)
    if (not index) then
        return nil, 'not found'
    end

    if (reader:is_directory(index)) then
        return nil, "is directory"
    end

    local data = reader:extract(index)
    if (not data) then
        return nil, "extract failed"
    end

    return data
end

local function checkDevelopmentMode()
	local rootPath = rootPath or getRootPath()
	local filename1 = path.join(rootPath, 'lua/lnode')
	local filename2 = path.join(rootPath, 'src')
	if (fs.existsSync(filename1) or fs.existsSync(filename2)) then
		print('\nThe "' .. rootPath .. '" is a development path.')
		print('You can not update the system in development mode.\n')
		return true
	end

	return false
end

local function getAppPath()
	local rootPath = getRootPath()
	local appPath = path.join(rootPath, "app")
	if (not fs.existsSync(appPath)) then
		appPath = path.join(path.dirname(rootPath), "app")
		options.dev = true
	end

	return appPath
end

local function getCurrentAppInfo()
	local cwd = process.cwd()
	local filename = path.join(cwd, 'package.json')
	local filedata = fs.readFileSync(filename)
	return json.parse(filedata)
end

local function getVersionCode(version)
	if (not version) then
		return 0
	end

	local tokens = version:split('.');
	if (#tokens < 3) then
		return 0
	end

	local value = (tokens[1] or 0) * 1000 * 10000 + (tokens[2]) * 10000 + (tokens[3])
	return math.floor(value)
end

-- 显示错误信息
local function printError(errorInfo, ...)
	print('ERROR:', console.colorize("err", errorInfo), ...)
end


-- 打包指定名称的 APP
local function buildPackage(name)
	if (not name) then
		print("need package name")
		return
	end

	local appPath  = getAppPath()
	local basePath = path.join(appPath, name)
	local filename = path.join(basePath, "package.json")
	if (not fs.existsSync(filename)) then
		printError(filename .. ' not exists!')
		return
	end

	local fileData = fs.readFileSync(filename)
	local packageInfo = fileData and json.parse(fileData)
	if (type(packageInfo) ~= 'table') then
		printError(filename .. ' invalid format!')
		return false
	end

	local version = packageInfo.version or '0.0.0'

	local tmpdir = path.dirname(os.tmpname())
	local buildPath = path.join(tmpdir, 'packages')
	fs.mkdirpSync(buildPath)
    print('build path: ' .. console.colorize("quotes", buildPath))

	local filename = path.join(buildPath, "" .. name .. ".zip")
    local builder = zlib.BundleBuilder:new(basePath, filename)

    builder:addFile("") -- add all files
	builder:build()

	print('output: ' .. console.colorize("quotes", filename))

	return filename, version
end

-------------------------------------------------------------------------------
-- upload

local UPLOAD_URL = app.rootURL .. '/download'

--[[
上传指定的文件到服务器
@param name {String} 要上传的文件名
@param alias {String} 上传后在服务器上的名称，如果没有指定则和 name 一样
@param callback {Function} 回调方法
--]]
local function upload_file(filename, dist, alias, callback)
	if (type(alias) == 'function') then
		callback = alias
		alias = nil

	elseif (type(callback) ~= 'function') then
		callback = function() end
	end

	local fileData = fs.readFileSync(filename)
	if (not fileData) then
		print('File not found: ' .. tostring(filename))
		callback('File not found: ')
		return
	end

	local request = require('vision/http/request')

	local urlString = UPLOAD_URL .. '/upload.php?v=1'
	if (dist) then
		urlString = urlString .. "&dist=" .. dist
	end

	local files = {file = { name = (alias or filename), data = fileData } }
	local options = { files = files }
	request.post(urlString, options, function(err, response, body)
		if (err) then
			callback(err)
			return

		elseif (response.statusCode ~= 200) then
			callback(response.statusCode .. ': ' .. tostring(response.statusMessage))
			return
		end

		local ret = json.parse(body) or {}
		print('URL: ' .. UPLOAD_URL .. '/' .. dist .. '/' .. (ret.name or '') .. '')
	    print('Done!\n')

	    callback()
	end)
end


local function publishPackage(name, ...)
	local filename, version = buildPackage(name)
	if (not filename) then
		return
	end

	local dist = 'app/' .. name
	local alias = name .. '.zip'

	upload_file(filename, dist, alias, function()
		print("finish!")
	end)
end

-- 
local function publishPackages(...)
	local appPath = getAppPath()
	local buildPath = path.join(path.dirname(appPath), 'build/packages')

	if (not fs.existsSync(buildPath)) then
		printError(buildPath .. ' not exists!')
		return
	end

	local files = fs.readdirSync(buildPath)
	if (not files) then
		printError(buildPath .. ' readdir failed!')
		return
	end

	local list = {}
	local packages = {}
	list["board"] = options.BOARD
	list["packages"] = packages

	print("Start Build... ")

	for i = 1, #files do
		local file = files[i]

		if not file:endsWith(".zip") then
			--print('skip ', file)
			goto continue
		end

		local filename 	= path.join(buildPath, file)
		local data 		= readBundleFile(filename, "package.json")
		local package 	= data and json.parse(data)
		if (not package) then
			print(filename, data)
			printError('bad package.json file.', file)
			goto continue
		end

		if (not package.name) then
			printError('bad package.json format.')
			goto continue
		end	

		local statInfo = fs.statSync(filename)
		if (not statInfo) then
			printError('bad package file.')
			goto continue
		end	

		local fileData = fs.readFileSync(filename)
		local md5sum = utils.md5(fileData)

		package['size'] 	= statInfo.size
		package['filename'] = package.name .. ".zip"
		package['md5sum']   = utils.bin2hex((md5sum))

		print("build", console.colorize("highlight", filename), package.size)
		table.insert(packages, package)

		::continue::
	end

	if (#packages <= 0) then
		print("Done. ")	
		return
	end

	local list_data = json.stringify(list)
	local filename = path.join(buildPath, 'packages.json')
	fs.writeFileSync(filename, list_data)

	print('output: ' .. console.colorize("quotes", filename))
	print("Done. ")	
end

local function removePackage(name)
	if (not name) then
		print("missing package name!")
		return
	end

	if (checkDevelopmentMode()) then
		return
	end

	local appPath = getAppPath()
	local filename = path.join(appPath, name)
	if (not fs.existsSync(filename)) then
		print('application not exists: ' .. filename)
		return
	end

	print('remove application: ' .. filename)
end


-------------------------------------------------------------------------------
-- Lua Package Manager, 一个简单的包管理工具，用来实现 OTA 自动热更新

local PackageManager = core.Emitter:extend()
exports.PackageManager = PackageManager

-- 初始化方法/构造函数
function PackageManager:initialize()
	local options 		= exports.options
    self.board			= options.BOARD
    self.cachePath		= options.CACHE_PATH
    self.rootPath   	= options.ROOT_PATH
    self.packages   	= {}
    self.sourceUrl     	= options.SOURCE_URL

	if (fs.existsSync(path.join(self.rootPath, "lua/lnode"))) then
		options.dev = true
	end

    -- test only
	if (options.dev) then

	end	
end

-- 检查所有包
function PackageManager:check()

	print("-----------------------------")
	print('npm conf:  ' .. tostring(options.conffile))
	print('npm board: ' .. self.board)
	print('npm root:  ' .. self.rootPath)
	print('npm cache: ' .. self.cachePath)
	print('Start checking...')

	if (not self:loadPackageList()) then
		print("Done.")
		return 
	end

	for _, packageInfo in ipairs(self.packages) do
		self:checkUpdate(packageInfo)
	end

	print("Done.")
end

function PackageManager:checkCachePackageInfo(packageInfo)
	if (type(packageInfo) ~= 'table') then
		return true
	end

	local filename = path.join(self.cachePath, packageInfo.name .. ".zip")
	local fileInfo = fs.statSync(filename)
	if (not fileInfo) then
		return false
	end

	local data = readBundleFile(filename, "package.json")
	if (not data) then
		return false
	end

	local package = data and json.parse(data)
	if (type(package) ~= 'table') then
		return false
	end

	if (fileInfo.size ~= packageInfo.size) then
		print('  Package Size: ' .. fileInfo.size .. "/" .. packageInfo.size)
		return false

	elseif (package.version ~= packageInfo.version) then
		print('  Package Version: ' .. package.version .. "/" .. packageInfo.version)
		return false
	end	

	return true
end

-- 检查源列表信息
function PackageManager:checkList(list)
	if (self.board ~= list.board) then
		self:onError('checkList: invalid board type: ' .. (list.board or ""))
		return false

	elseif (#list.packages < 1) then
		self:onError('checkList: empty packages list')
		return false
	end

	return true
end

-- 检查指定的包
function PackageManager:checkPackage(packageInfo, filename)
	local statInfo = fs.statSync(filename)
	if (not statInfo) then
		return true
	end

	-- pprint(statInfo.size)

	return true
end

-- 检查是否可以更新
function PackageManager:checkUpdate(packageInfo)
	local name = packageInfo.name
	--pprint(packageInfo)	

	--print('- Check ' .. name .. ".")
	local oldInfo = self:loadPackageInfo(name)
	if (not oldInfo) then
		return false
	end
	--pprint(oldInfo)

	local oldVersion = getVersionCode(oldInfo.version)
	local newVersion = getVersionCode(packageInfo.version)
	local oldname = name .. '@' .. (oldInfo.version or "0.0.0")
	if (oldVersion ~= newVersion) then
		local newname = "@" .. (packageInfo.version or '0.0.0')
		local data = console.colorize("quotes", newname);
		print("  Package '" .. oldname .. "' available update: " .. data)
		return true

	else
		print("  Package '" .. oldname .. "' no updates available.")
	end

	return false
end

-- 清除缓存数据等
function PackageManager:clean()
	if (not fs.existsSync(self.cachePath)) then
		self:onError(self.cachePath .. ' not exists!')
		return
	end

	local files = fs.readdirSync(self.cachePath)
	if (not files) then
		self:onError(self.cachePath .. ' list failed!')
		return
	end

	print("Start clearing... ")
	for i = 1, #files do
		local file = files[i]
		if (not file:endsWith("packages.json")) then
			local filename = path.join(self.cachePath, file)
			os.remove(filename)

			print("  Remove: ", filename)
		end
	end

	print("Done. ")
end

-- 下载指定的包
function PackageManager:downloadPackage(packageInfo)
	if (self:checkCachePackageInfo(packageInfo)) then
		self:installPackage(packageInfo)
		return true
	end

	local filename = packageInfo.filename
	local packageUrl = url.resolve(self.sourceUrl, filename)
	print('  Package URL: ' .. packageUrl)

	local request = http.get(packageUrl, function(response)
		
		local contentLength = tonumber(response.headers['Content-Length'])
		print('  Start download: ', contentLength)

		local percent = 0
		local downloadLength = 0
		local data = {}
		local lastTime = timer.now()

		response:on('data', function(chunk)
			if (not chunk) then
				return
			end

			--pprint("ondata", {chunk=chunk})
			table.insert(data, chunk)
			downloadLength = downloadLength + #chunk

			-- thread.sleep(100)

			if (contentLength > 0) then
				percent = math.floor(downloadLength * 100 / contentLength)

				local now = timer.now()
				if ((now - lastTime) >= 500) or (contentLength == downloadLength) then
					lastTime = now
					print("  Downloading (" .. percent .. "%)  " .. downloadLength .. "/" .. contentLength .. ".")
				end
			end
		end)

		response:on('end', function()
			local content = table.concat(data)
			print("  Download done: ", response.statusCode, #content)
			--pprint("end", response.statusCode)

			self:savePackage(packageInfo, content)
			self:installPackage(packageInfo)
		end)

		response:on('error', function(err)
			self:onError('  Download package failed: ' .. (err or ''))
		end)
	end)

	request:on('error', function(err) 
		self:onError('  Download package failed: ' .. (err or ''))
	end)
end

function PackageManager:install(name)
	if (not name) then
		print('missing package name!')
		return
	end

	if (checkDevelopmentMode()) then
		return
	end

	if (not self:loadPackageList()) then
		print("Done.")
		return 
	end

	local installInfo = nil
	for _, packageInfo in ipairs(self.packages) do
		if (packageInfo.name == name) then
			installInfo = packageInfo
			break
		end
	end

	if (not installInfo) then
		print("application not exists: " ..  name)
		return
	end

	self:installPackage(installInfo)
end

-- 安装指定路径和名称的包
-- @param name String 
function PackageManager:installPackage(packageInfo)
	if (not packageInfo) or (not packageInfo.name) then
		self:onError('Bad package info!')
		return
	end

	local appPath = getAppPath()

	-- install path
	print("- Install '" .. packageInfo.name .. "'.")
	if (not fs.existsSync(appPath)) then
		print(fs.mkdirpSync(appPath))
	end

	-- check source package
	local filename = path.join(self.cachePath, packageInfo.filename)
	if (not fs.existsSync(filename)) then
		self:onError('  Package file not exists: ' .. filename)
		return

	elseif (not self:checkPackage(packageInfo, filename)) then
		self:onError('  Bad package file format: ' .. filename)
		return
	end

	-- copy package file
	local target = path.join(appPath, packageInfo.name)
	local tmpfile = target .. ".tmp"

	fs.copyfileSync(filename, tmpfile)
	if (not fs.existsSync(tmpfile)) then
		self:onError('  Copy package file failed: ' .. filename)
		return
	end

	-- check package md5sum
	local fileData = fs.readFileSync(tmpfile)
	local md5sum = utils.bin2hex(utils.md5(fileData))
	if (md5sum ~= packageInfo.md5sum) then
		self:onError('  MD5 sum check failed: ' .. md5sum)
		return
	end

	-- rename package file
	os.remove(target)
	os.rename(tmpfile, target)

	print("  Install '" .. packageInfo.name .. "' to " .. target)

	return 0
end

function PackageManager:loadPackageInfo(name)
	local appPath = getAppPath()

	local filename = path.join(appPath, name)
	local data = fs.readFileSync(path.join(filename, "package.json"))
	if (not data) then
		return nil
	end

	local package = data and json.parse(data)
	if (not package) then
		return nil
	end	

	return package
end

-- 读取本地的源列表文件
function PackageManager:loadPackageList()
	local parseList = function(content)
		local jsonData = json.parse(content)
		if (not jsonData) then
			self:onError('loadPackageList: invalid json format.')
			return false
		end

		if (not self:checkList(jsonData)) then
			self:onError('loadPackageList: invalid packages format.')
			return false
		end

		self.packages = jsonData.packages
		return true
	end

	local filename = path.join(self.cachePath, 'packages.json')
	local content = fs.readFileSync(filename)
	if (content) then
		return parseList(content)
	end

	self:updatePackageList(nil, function()
		local content = fs.readFileSync(filename)
		if (content) then
			return parseList(content)
		end
	end)
end

-- 显示错误信息
function PackageManager:onError(errorInfo, ...)
	print('ERROR:', console.colorize("err", errorInfo), ...)

end


-- 保存指定的包到缓存目录
function PackageManager:savePackage(packageInfo, content)
	local name = packageInfo.name

	if (not fs.existsSync(self.cachePath)) then
		fs.mkdirpSync(self.cachePath)
	end

	local filename = path.join(self.cachePath, name .. ".zip")
	os.remove(filename)
	fs.writeFileSync(filename, content)
end

-- 保存指定的源数据到缓存目录
function PackageManager:savePackageList(listData)
	if (not listData) then
		return nil, 'invalid packages list data'
	end

	local jsonData = json.parse(listData)
	if (not jsonData) or (not jsonData.packages) then
		return nil, 'invalid packages json format'
	end	

	if (not self:checkList(jsonData)) then
		return nil, 'invalid packages json list data'
	end

	self.packages = jsonData.packages

	if (not fs.existsSync(self.cachePath)) then
		fs.mkdirpSync(self.cachePath)
	end

	-- save to file
	local filename = path.join(self.cachePath, 'packages.json')
	fs.writeFileSync(filename, listData)
	print("Save 'packages.json' to " .. console.colorize("quotes", filename))

	return jsonData
end

-- 更新源，从源服务器下载最新的包列表文件
function PackageManager:updatePackageList(url, callback)
	callback = callback or function() end
	local sourceUrl = url or self.sourceUrl;
	if (not sourceUrl) then
		self:onError("Invalid source URL.")
		callback(nil, "Invalid source URL.")
		return
	end

	print('Start updating...')
	print('Source "' .. sourceUrl .. '"...')
	request(sourceUrl, function(error, response, body)
		if (error) then
			callback(nil, error)
			return 
		end

		local data, err = self:savePackageList(body)
		callback(data, err)
	end)
end

function PackageManager:update(host)
	if (checkDevelopmentMode()) then
		return
	end

	local sourceUrl = self.sourceUrl;
	if (not sourceUrl) then
		self:onError("Invalid source URL.")
		return
	end

	if (host) then
		sourceUrl = 'http://' .. host .. '/download/packages.json'
	end

	self:updatePackageList(sourceUrl, function(data, err)
		if (err) then
			self:onError(err)
			return
		end

		self:loadPackageList()
	end)
end

function PackageManager:upgrade(mode)

	if (mode == 'yes') then
		self:loadPackageList()

		if (not self.packages) then
			return
		end

		print('Start upgrading (' .. #self.packages .. ")...")

		for _, packageInfo in ipairs(self.packages) do
			if (self:checkUpdate(packageInfo)) then
				self:downloadPackage(packageInfo)
			end
		end

	else
		self:loadPackageList()

		if (not self.packages) then
			return
		end

		for _, packageInfo in ipairs(self.packages) do
			self:checkUpdate(packageInfo)
		end

	end
end

function exports.clean(...)
	PackageManager:new():clean(...)
end

function exports.install(name, ...)
	if (not name) then
		local package  = getCurrentAppInfo() or {}
		name = package.name
	end

	PackageManager:new():install(name, ...)
end

function exports.pack(name, ...)
	if (not name) then
		local filename = process.cwd()
		name = path.basename(filename)
		if (not name) or (name == '') then
			print('missing package name!')
			return
		end

		buildPackage(name, ...)

	elseif (name == "@all") then
		local appPath = getAppPath()
		local files = fs.readdirSync(appPath)
		if (not files) then
			self:onError(appPath .. ' readdir failed!')
			return
		end

		for _, name in ipairs(files) do
			buildPackage(name)
		end

	else

		buildPackage(name, ...)
	end
end

-- 该命令将当前的软件发包发布到 软件包仓库中。
function exports.publish(name, ...)
	if (not name) then
		local filename = process.cwd()
		name = path.basename(filename)
		if (not name) or (name == '') then
			print('missing package name!')
			return
		end

		publishPackage(name, ...)
		return
	end

	publishPackages(name, ...)
end

function exports.remove(name, ...)
	removePackage(name, ...)
end

function exports.update(...)
	PackageManager:new():update(...)
end

return exports
