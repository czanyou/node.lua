local fs        = require('fs')
local json      = require('json')
local path      = require('path')
local url       = require('url')
local utils     = require('util')

local request  	= require('http/request')
local conf   	= require('app/conf')
local ext   	= require('app/utils')
local upgrade 	= require('./upgrade')

-------------------------------------------------------------------------------

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

local exports = {}

local function getNodePath()
	return conf.rootPath
end

-------------------------------------------------------------------------------
-- download

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

local function saveUpdateStatus(status) 
	local nodePath  = getNodePath()
	local basePath  = path.join(nodePath, 'update')
	local ret, err = fs.mkdirpSync(basePath)
	if (err) then
		print(err)
		return
	end

	local filename = path.join(basePath, 'status.json')
	local filedata = json.stringify(status);
	fs.writeFileSync(filename, filedata);
end

--
-- Download firmware file
-- @param {object} options 
--  - options.type
--  - options.did
--  - options.base
--  - options.packageInfo
-- @param {function} callback
local function downloadFirmwarePackage(options, callback)
	callback = callback or ext.noop
	local printInfo = options.printInfo or function() end

	local nodePath  = getNodePath()
	local basePath  = path.join(nodePath, 'update')
	local ret, err = fs.mkdirpSync(basePath)
	if (err) then
		callback({ code = UPDATE_NOT_ENOUGH_FLASH, error = err })
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
				-- print("The update file is up-to-date!", filename)
				callback(nil, filename)
				return
			end
		end
	end

	local rootURL = options.base
	if (not rootURL) then
		callback({ code = UPDATE_INVALID_URI, error = 'Invalid URI' })
		return
	end

	local target 	= ext.getSystemTarget()
	local version   = process.version or ''

	--console.log(filename)
	local baseURL 	= rootURL .. 'device/firmware/file'
	local url 		= baseURL .. '?type=' .. (options.type or 'sdk')
	url = url .. '&target=' .. target
	url = url .. '&localVersion=' .. version
	url = url .. '&did=' .. options.did

	printInfo('Package url: ' .. url)

	-- 下载最新的 SDK 更新包
	request.download(url, {}, function(err, percent, response)
		if (err) then
			callback({ code = UPDATE_DISCONNECTED, error = err })
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

		local filedata = response.body
		local md5sum = utils.bin2hex(utils.md5(filedata))
		if (md5sum ~= packageInfo.md5sum) then
			callback({ code = UPDATE_VALIDATION_FAILED, error = 'Invalid firmware md5sum' })
			return
		end

		os.remove(filename)
		fs.writeFile(filename, filedata, function(err)
			if (err) then 
				callback({ code = UPDATE_NOT_ENOUGH_FLASH, error = err })
				return
			end

			callback(nil, filename)
		end)
	end)
end

-- 
-- Download system 'update.json' file
-- @param {object} options
--  - options.type
--  - options.did
--  - options.base
-- @param {function} callback
local function downloadFirmwareInfo(options, callback)
	options = options or {}
	local printInfo = options.printInfo or function() end

	-- URL
	local did 		= options.did
	local rootURL 	= options.base
	if (not did) then
		callback({ code = UPDATE_INVALID_URI, error = 'Invalid did' })
		return

	elseif (not rootURL) then
		callback({ code = UPDATE_INVALID_URI, error = 'Invalid base URI' })
		return
	end

	local url 	= rootURL .. 'device/firmware/?did=' .. did
	printInfo('URL: ' .. url)

	request.download(url, {}, function(err, percent, response)
		if (err) then
			callback({ code = UPDATE_DISCONNECTED, error = err })
			return

		elseif (percent < 100) or (not response) then
			return
		end

		--console.log(response.body)
		local packageInfo = json.parse(response.body)
		if (not packageInfo) or (not packageInfo.version) then
			callback({ code = UPDATE_VALIDATION_FAILED, error = "Invalid firmware package information." })
			return
		end

		local version = parseVersion(packageInfo.version)
		local current = parseVersion(process.version)
		if (version < current) then
			print('Note: The firmware package version is less than current version: v' .. tostring(packageInfo.version) .. '<v' .. tostring(process.version))
		end

		local nodePath  = getNodePath()
		local basePath  = path.join(nodePath, 'update')
		local ret, err = fs.mkdirpSync(basePath)
		if (err) then
			callback({ code = UPDATE_NOT_ENOUGH_FLASH, error = err })
			return
		end

		local filename 	= path.join(basePath, 'update.json')
		local filedata  = fs.readFileSync(filename)
		if (filedata == response.body) then
			-- print("The firmware information is up-to-date!")
			callback(nil, packageInfo)
			return
		end

		local tempname 	= path.join(basePath, 'update.json.tmp')
		os.remove(tempname)

		fs.writeFile(tempname, response.body, function(err)
			if (err) then 
				callback(err)
				return
			end

			os.remove(filename)
			local ret, err = os.rename(tempname, filename)
			if (err) then
				callback({ code = UPDATE_NOT_ENOUGH_FLASH, error = err })
				return
			end

			print("Firmware information saved to: " ..  filename)
			callback(nil, packageInfo)
		end)
	end)
end

--
-- Download 'update.json' and firmware files
-- @param {object} options
--  - options.type
--  - options.did
-- @param {function} callback
local function downloadFirmwareFile(options, callback)
	options = options or {}
	local printInfo = options.printInfo or function() end

	-- Update Path
	local nodePath  = getNodePath()
	local basePath  = path.join(nodePath, 'update')
	local ret, err = fs.mkdirpSync(basePath)
	if (err) then
		callback({ code = UPDATE_NOT_ENOUGH_FLASH, error = err })
		return
	end

	-- downloading firmware info
	downloadFirmwareInfo(options, function(err, packageInfo)
		-- console.log('Firmware Info:', packageInfo);
		if (err) or (not packageInfo) then
			callback(err)
			return
		end

		-- downloading firmware file
		local args = {}
		args.did 		 = options.did
		args.printInfo   = options.printInfo
		args.type        = options.type
		args.base        = options.base
		args.packageInfo = packageInfo
		downloadFirmwarePackage(args, function(err, filename)
			if (err) or (not filename) then
				return callback(err)
			end

			-- check firmware file format
			local rootPath = os.tmpdir .. '/update'

			local options = {
				filename = filename,
				rootPath = rootPath
			}
			local updater = upgrade.openUpdater(options)
			updater.reader = upgrade.openBundle(filename)

			local packageInfo = updater:parsePackageInfo()
			local version = packageInfo and packageInfo.version
			if (not version) then
				console.log('packageInfo', packageInfo)
				return callback({ code = UPDATE_VALIDATION_FAILED, error = 'Invalid firmware file format'});
			end

			--local newname = basePath .. '/update-' .. version .. '.zip'
			--os.remove(newname)
			--os.rename(filename, newname)
			callback(nil, filename, packageInfo)
		end)
	end)
end

-------------------------------------------------------------------------------
--

-- Dnowload update files only
function exports.update(callback)
	local options = { type = 'update' }

	local profile = conf('user')
	options.did = profile:get('did')
	options.base = profile:get('base')
	
	if (type(callback) ~= 'function') then
		callback = function(err, filename, packageInfo)
			packageInfo = packageInfo or {}
			local status = { state = 0, result = 0 }

			--console.log(err, filename, packageInfo)
			if (err) then
				console.log('err: ', err)
				status.result = 8
				if (err.result) then
					status.result = err.result
				end

			else
				local version = packageInfo.version
				print('Latest firmware version: ' .. tostring(version))
				status.state = STATE_DOWNLOAD_COMPLETED
				status.version = version
			end

			saveUpdateStatus(status)
		end

		options.printInfo = function(...) print(...) end
	end
	
	downloadFirmwareFile(options, callback)
end

function exports.upgrade()
	exports.update(function(err, filename, packageInfo) 
		local status = { state = 0, result = 0 }

		if (err) then
			console.log('err: ', err)
			status.result = 8
			if (err.result) then
				status.result = err.result
			end

			saveUpdateStatus(status)
			return
		end

		local version = packageInfo.version
		print('Latest firmware version: ' .. tostring(version))
		status.state = STATE_DOWNLOAD_COMPLETED
		status.version = version
		saveUpdateStatus(status)

		upgrade.install()
	end)
end

return exports
