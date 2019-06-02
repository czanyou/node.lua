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
	local nodePath = getNodePath()
	local basePath = path.join(nodePath, 'update')
	local ret, err = fs.mkdirpSync(basePath)
	if (err) then
		print(err)
		return
	end

	local filename = path.join(basePath, 'status.json')
	local filedata = fs.readFileSync(filename)
	local output = json.stringify(status)
	if (output and output ~= filedata) then
		fs.writeFileSync(filename, output)
	end
end

local function readUpdateStatus()
	local nodePath = getNodePath()
	local basePath = path.join(nodePath, 'update')
	local filename = path.join(basePath, 'status.json')
	local filedata = fs.readFileSync(filename)
	if (filedata) then
		return json.parse(filedata)
	end
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
	local url 		= baseURL .. '?did=' .. options.did

	printInfo('Package URL: ' .. url)

	-- 下载最新的 SDK 更新包
	request.download(url, {}, function(err, percent, response)
		if (err) then
			callback({ code = UPDATE_DISCONNECTED, error = err })
			return 
		end

		if (percent == 0 and response) then
			local contentLength = tonumber(response.headers['Content-Length']) or 0

			printInfo('Package Size: (' .. ext.formatBytes(contentLength) .. ').')
		end

		if (percent <= 100) then
			console.write('\rDownloading: (' .. percent .. '%)...  ')
		end

		if (percent < 100) or (not response) then
			return
		end

		-- write to a temp file
		console.write('\rDownloading: Done        \r\n')

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

			printInfo('Updated to version: ' .. tostring(packageInfo.version))

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
	local nodePath  = getNodePath()
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
	printInfo('Path: ' .. nodePath)
	printInfo('DID: ' .. did)
	printInfo('URL: ' .. url)

	request.download(url, {}, function(err, percent, response)
		if (err) then
			callback({ code = UPDATE_DISCONNECTED, error = err })
			return

		elseif (percent and (percent < 100)) or (not response) then
			return
		end

		--console.log(response.body)
		local packageInfo = json.parse(response.body)
		if (not packageInfo) then
			callback({ code = UPDATE_VALIDATION_FAILED, error = "Firmware information is not valid JSON string." })
			return

		elseif (not packageInfo.version) then
			callback({ 
				code = UPDATE_VALIDATION_FAILED,
				error = packageInfo.error or "Invalid firmware package information."
			})
			return
		end

		local version = parseVersion(packageInfo.version)
		local current = parseVersion(process.version)
		printInfo('Current Version: ' .. process.version)

		if (version < current) then
			printInfo('New Version: ' .. packageInfo.version)
		end

		local basePath  = path.join(nodePath, 'update')
		local ret, err = fs.mkdirpSync(basePath)
		if (err) then
			callback({ code = UPDATE_NOT_ENOUGH_FLASH, error = err })
			return
		end

		printInfo('Updated: ' .. tostring(packageInfo.updated))
		printInfo('Size: ' .. tostring(packageInfo.size))
		printInfo('MD5: ' ..  tostring(packageInfo.md5sum))

		local filename 	= path.join(basePath, 'update.json')
		local filedata  = fs.readFileSync(filename)
		if (filedata == response.body) then
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

			print("Firmware Path: " ..  filename)
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

			callback(nil, filename, packageInfo)
		end)
	end)
end

-------------------------------------------------------------------------------
--

-- Dnowload update files only
function exports.update(callback)
	-- options
	local profile = conf('user')
	local options = { type = 'update' }
	options.did = profile:get('did')
	options.base = profile:get('base')
	
	-- callback
	if (type(callback) ~= 'function') then
		callback = function(err, filename, packageInfo)
			packageInfo = packageInfo or {}

			local status = { state = 0, result = 0 }
			if (err) then
				-- error
				if (err.code) then
					print("Code: " .. tostring(err.code))
				end
	
				if (err.error) then
					print("Error: " .. tostring(err.error))
				else
					console.log('Error: ', err)
				end
			
				status.result = err.result or 8

			else
				-- version
				local version = packageInfo.version
				print('At Version: ' .. tostring(version))
				status.state = STATE_DOWNLOAD_COMPLETED
				status.version = version
			end

			saveUpdateStatus(status)
		end
	end

	options.printInfo = function(...) print(...) end
	
	downloadFirmwareFile(options, callback)
end

function exports.upgrade()
	exports.update(function(err, filename, packageInfo) 
		local status = { state = 0, result = 0 }

		if (err) then
			if (err.code) then
				print("Code: " .. tostring(err.code))
			end

			if (err.error) then
				print("Message: " .. tostring(err.error))
			else
				console.log('Error: ', err)
			end

			status.result = 8
			if (err.result) then
				status.result = err.result
			end

			saveUpdateStatus(status)
			return
		end

		local version = packageInfo.version
		status.state = STATE_DOWNLOAD_COMPLETED
		status.version = version
		saveUpdateStatus(status)
		print('Latest Version: ' .. tostring(version))

		exports.install(function(err, message)
			if (err) then
				print('Error: ' .. tostring(err))

			elseif (message) then
				print(message)
			end
		end)
	end)
end

function exports.install(callback)
	if (type(callback) ~= 'function') then
		callback = function(err)
			print(err)
		end
	end

	local status = readUpdateStatus()
	if (not status) or (status.state ~= STATE_DOWNLOAD_COMPLETED) then
		callback('Error: Please update firmware first.')
		return
	end

	-- console.log(source, rootPath)
	-- console.log("Upgrade path: " .. nodePath, rootPath)
	status = { state = 0, result = 0 }
	status.state = STATE_UPDATING -- 3：正在更新
	saveUpdateStatus(status)

	upgrade.install(nil, function(err, message)
		if (err) then
			status.result = UPDATE_FAILED -- 8：固件更新失败
		else
			status.result = UPDATE_SUCCESSFULLY -- 1：固件更新成功
		end

		status.state = 0
		saveUpdateStatus(status)

		if (callback) then 
			callback(err, message)
		end
	end)

	return true
end

function exports.status()
	local status = readUpdateStatus()
	if (status) then
		console.printr(status)
	end
end

return exports
