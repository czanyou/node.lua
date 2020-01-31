local fs        = require('fs')
local json      = require('json')
local path      = require('path')
local util      = require('util')

local request  	= require('http/request')
local app   	= require('app')
local rpc       = require('app/rpc')

local upgrade 	= require('./upgrade')

-------------------------------------------------------------------------------
-- 更新和下载最新的固件文件

local exports = {}

-------------------------------------------------------------------------------
--[[

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

-- Update states
local STATE = {
	STATE_INIT = 0,
	STATE_DOWNLOADING = 1,
	STATE_DOWNLOAD_COMPLETED = 2,
	STATE_UPDATING = 3,
	STATE_COMPLETED = 4,
	STATE_ERROR = 5
}

-- Update result code
local RESULT = {
	UPDATE_INIT = 0,
	UPDATE_SUCCESSFULLY = 1,
	UPDATE_NOT_ENOUGH_FLASH = 2,
	UPDATE_NOT_ENOUGH_RAM = 3,
	UPDATE_DISCONNECTED = 4,
	UPDATE_VALIDATION_FAILED = 5,
	UPDATE_UNSUPPORTED_FIRMWARE_TYPE = 6,
	UPDATE_INVALID_URI = 7,
	UPDATE_FAILED = 8,
	UPDATE_UNSUPPORTED_PROTOCOL = 9
}

-------------------------------------------------------------------------------
-- updater

local function getUpdateResultString(result)
	local titles = {
		'init', 'successfully', 'not enough flash', 'not enough ram', 'disconnected',
		'validation failed', 'unsupported firmware type', 'invalid uri', 'failed',
		'unsupported protocol'
	}

	return titles[result + 1] or result
end

local function getUpdateStateString(state)
	local states = {
		'init', 'downloading', 'download completed', 'updating', 'updated completed', 'updated error'
	}

	return states[state + 1] or state
end

local function sendUpdateEvent(status)
    local params = { status }
    rpc.call('wotc', 'firmware', params, function(err, result)
        -- print('firmware', err, result)
    end)
end

local function saveUpdateStatus(status)
	if (not status) then
		return
	end

	local basePath = path.join(os.tmpdir, 'update')
	local ret, err = fs.mkdirpSync(basePath)
	if (err) then
		print(err)
		return
	end

	status.updated = Date.now()

	local filename = path.join(basePath, 'status.json')
	local filedata = fs.readFileSync(filename)
	local output = json.stringify(status)
	if (output and output ~= filedata) then
		fs.writeFileSync(filename, output)
	end

	sendUpdateEvent(status)
end

local function readUpdateStatus()
	local filename = path.join(os.tmpdir, 'update/status.json')
	local filedata = fs.readFileSync(filename)
	if (filedata) then
		return json.parse(filedata)
	end
end

-------------------------------------------------------------------------------
-- updater

local updater = {}

function updater.printInfo(...)
	print(...)
end

function updater.getFirmwareFilename(callback)
	local basePath  = path.join(os.tmpdir, 'update')
	local ret, err = fs.mkdirpSync(basePath)
	if (err) then
		if (callback) then
			callback({ code = RESULT.UPDATE_NOT_ENOUGH_RAM, error = err })
		end

		return
	end

	local filename = path.join(basePath, '/' .. 'update' .. '.zip')
	return filename
end

function updater.isFileChanged(filename, packageInfo)
	if (not packageInfo) then
		return true

	elseif (not packageInfo.size) then
		return true
	end

	local filedata = fs.readFileSync(filename)
	if (not filedata) or (#filedata ~= packageInfo.size) then
		return true
	end

	local md5sum = util.md5string(filedata)
	if (md5sum ~= packageInfo.md5sum) then
		return true
	end

	return false
end

--
-- Download firmware file
-- @param {object} options
--  - options.type
--  - options.did
--  - options.base
--  - options.packageInfo
-- @param {function} callback
function updater.downloadPackage(options, packageInfo, callback)
	callback = callback or function() end
	local printInfo = updater.printInfo

	if (not packageInfo) then
		return callback({ code = RESULT.UPDATE_VALIDATION_FAILED, error = 'Invalid packageInfo' })
	end

	-- local cache path
	local filename = updater.getFirmwareFilename(callback)
	if (not filename) then
		return
	end

	printInfo('Cache filename: ' .. filename)

	-- 检查 SDK 更新包是否已下载
	if (not updater.isFileChanged(filename, packageInfo)) then
		printInfo("The firmware file is up-to-date!")
		return callback(nil, filename)
	end

	-- url
	local rootURL = options.base
	if (not rootURL) then
		return callback({ code = RESULT.UPDATE_INVALID_URI, error = 'Invalid URI' })
	end

	local target 	= app.getSystemTarget()
	local version   = process.version or ''
	local baseURL 	= rootURL .. 'device/firmware/file'
	local url 		= baseURL .. '?did=' .. options.did .. '&target=' .. target .. '&currentVersion=' .. version
	printInfo('Package URL: ' .. url)

	-- 下载最新的 SDK 更新包
	request.download(url, {}, function(err, percent, response)
		if (err) then
			callback({ code = RESULT.UPDATE_DISCONNECTED, error = err })
			return
		end

		if (percent == 0 and response) then
			local contentLength = tonumber(response.headers['Content-Length']) or 0

			printInfo('Package Size: (' .. util.formatBytes(contentLength) .. ').')
		end

		if (percent <= 100) then
			console.write('\rDownloading: (' .. percent .. '%)...  ')
		end

		if (percent < 100) or (not response) then
			return
		end

		-- write to a temp file
		console.write('\rDownloading: Done        \r\n')

		-- save firmware file
		updater.saveFirmwareFile(filename, response.body, packageInfo, callback)
	end)
end

function updater.saveFirmwareFile(filename, filedata, packageInfo, callback)
	local printInfo = updater.printInfo

	local md5sum = util.md5string(filedata)
	if (md5sum ~= packageInfo.md5sum) then
		return callback({ code = RESULT.UPDATE_VALIDATION_FAILED, error = 'Invalid firmware md5sum' })
	end

	os.remove(filename)
	fs.writeFile(filename, filedata, function(err)
		if (err) then
			return callback({ code = RESULT.UPDATE_NOT_ENOUGH_RAM, error = err })
		end

		printInfo('Updated to version: ' .. tostring(packageInfo.version))
		callback(nil, filename)
	end)
end

-- Parse version string
-- @param {string} version
-- @return {number} return number value of the version
function updater.parseVersion(version)
	local function parseVersionNumber(value)
		value = tonumber(value) or 0
		return value % 10000
	end

	if (type(version) ~= 'string') then
		return 0
	end

	local tokens = version:split('.')
	return (parseVersionNumber(tokens[1]) * 10000 * 10000)
		+ (parseVersionNumber(tokens[2]) * 10000)
		+ (parseVersionNumber(tokens[3]))
end

--
-- Download system 'update.json' file
-- @param {object} options
--  - options.type
--  - options.did
--  - options.base
-- @param {function} callback
function updater.getFirmwareInfo(options, callback)
	options = options or {}
	local did 		= options.did
	local rootURL 	= options.base
	local printInfo = updater.printInfo

	-- firmware url
	if (not did) then
		callback({ code = RESULT.UPDATE_INVALID_URI, error = 'Invalid did' })
		return

	elseif (not rootURL) then
		callback({ code = RESULT.UPDATE_INVALID_URI, error = 'Invalid base URI' })
		return
	end

	local url 	= rootURL .. 'device/firmware/?did=' .. did
	printInfo('DID: ' .. did)
	printInfo('URL: ' .. url)

	-- download
	request.download(url, {}, function(err, percent, response)
		if (err) then
			callback({ code = RESULT.UPDATE_DISCONNECTED, error = err })
			return

		elseif (percent and (percent < 100)) or (not response) then
			return
		end

		-- check firmware info
		local packageInfo = json.parse(response.body)
		if (not packageInfo) then
			callback({ code = RESULT.UPDATE_VALIDATION_FAILED, error = "Firmware information is not valid JSON string." })
			return

		elseif (not packageInfo.version) then
			callback({
				code = RESULT.UPDATE_VALIDATION_FAILED,
				error = packageInfo.error or "Invalid firmware package information."
			})
			return
		end

		-- print firmware info
		updater.printFirmwareInfo(packageInfo)

		-- save firmware info
		updater.saveFirmwareInfo(response.body, packageInfo, callback)
	end)
end

function updater.printFirmwareInfo(packageInfo)
	local printInfo = updater.printInfo

	local version = updater.parseVersion(packageInfo.version)
	local current = updater.parseVersion(process.version)
	printInfo('Current Version: ' .. process.version)

	if (version < current) then
		printInfo('New Version: ' .. packageInfo.version)
	end

	printInfo('Updated: ' .. tostring(packageInfo.updated))
	printInfo('Size: ' .. tostring(packageInfo.size))
	printInfo('MD5: ' ..  tostring(packageInfo.md5sum))

	if (packageInfo.description and #packageInfo.description > 0) then
		printInfo('Description: ' .. tostring(packageInfo.description))
	end
end

function updater.saveFirmwareInfo(firmwareInfo, packageInfo, callback)
	local basePath  = path.join(os.tmpdir, 'update')
	local _, error = fs.mkdirpSync(basePath)
	if (error) then
		callback({ code = RESULT.UPDATE_NOT_ENOUGH_FLASH, error = error })
		return
	end

	local filename 	= path.join(basePath, 'update.json')
	local filedata  = fs.readFileSync(filename)
	if (filedata == firmwareInfo) then
		callback(nil, packageInfo)
		return
	end

	local tempname 	= path.join(basePath, 'update.json.tmp')
	os.remove(tempname)

	fs.writeFile(tempname, firmwareInfo, function(err)
		if (err) then
			callback(err)
			return
		end

		os.remove(filename)
		local ret, err = os.rename(tempname, filename)
		if (err) then
			callback({ code = RESULT.UPDATE_NOT_ENOUGH_FLASH, error = err })
			return
		end

		print("Firmware Path: " ..  filename)
		callback(nil, packageInfo)
	end)
end

function updater.checkFirmwareFile(err, filename, callback)
	if (err) or (not filename) then
		return callback(err)
	end

	-- check firmware file format
	local rootPath = os.tmpdir .. '/update'
	local options = { filename = filename, rootPath = rootPath }

	local bundleUpdater = upgrade.openUpdater(options)
	bundleUpdater.reader = upgrade.openBundle(filename)

	local packageInfo = bundleUpdater:parsePackageInfo()
	local version = packageInfo and packageInfo.version
	if (not version) then
		console.log('packageInfo', packageInfo)
		return callback({ code = RESULT.UPDATE_VALIDATION_FAILED, error = 'Invalid firmware file format'});
	end

	callback(nil, filename, packageInfo)
end

function updater.printUpdateResult(err, packageInfo)
	packageInfo = packageInfo or {}

	local printInfo = updater.printInfo
	if (err) then
		-- error
		printInfo('Error: ', console.dump(err))

	else
		-- version
		local version = packageInfo.version
		printInfo('Updated Version: ' .. tostring(version))
	end
end

-- Update information of available firmware
-- @param {function} callback
function updater.update(callback)
	-- callback
	if (type(callback) ~= 'function') then
		callback = function(err, filename, packageInfo)
			console.log(err, filename, packageInfo)
		end
	end

	if (not app.lock('update')) then
		return callback('try update lock failed')
	end

	local printInfo = updater.printInfo

	-- options
	local options = { type = 'update' }
	options.did = app.get('did')
	options.base = app.get('base')

	if (not options.base) then
		printInfo('Missing the required config parameter `base`');
		return callback('Missing required parameter')

	elseif (not options.did) then
		printInfo('Missing the required config parameter `did`');
		return callback('Missing required parameter')
	end

	if (not options.base:endsWith('/')) then
		options.base = options.base .. '/'
	end

	-- downloading firmware info
	updater.getFirmwareInfo(options, function(err, packageInfo)
		-- console.log('Firmware Info:', packageInfo);
		if (err) or (not packageInfo) then
			return callback(err)
		end

		-- downloading firmware file
		updater.downloadPackage(options, packageInfo, function(err, filename)
			updater.checkFirmwareFile(err, filename, callback)
		end)
	end)
end

-------------------------------------------------------------------------------
-- install

local function installFirmwareFile(filename, callback)
	if (type(filename) == 'function') then
		callback = filename
		filename = nil
	end

	if (type(callback) ~= 'function') then
		local status = {}
		status.result = RESULT.UPDATE_INIT
		status.state = STATE.STATE_UPDATING
		saveUpdateStatus(status)

		callback = function(err, message)
			if (err or message) then
				print(err or message)
			end

			if (err) then
				status.error = tostring(err)
				status.result = RESULT.UPDATE_FAILED
				status.state = STATE.STATE_ERROR

			else
				status.result = RESULT.UPDATE_SUCCESSFULLY
				status.state = STATE.STATE_COMPLETED
			end

			saveUpdateStatus(status)
		end
	end

	-- 开始安装
	upgrade.install(filename, callback)
end

-- Download and install the latest firmware
-- @param callback
local function upgradeFirmwareFile(callback)

	local status = {}
	status.error = nil
	status.result = RESULT.UPDATE_INIT
	status.state = STATE.STATE_DOWNLOADING
	saveUpdateStatus(status)

	local function onUpdateError(err)
		console.printr('Error: ', err)

		status.error = tostring(err)
		status.result = RESULT.UPDATE_FAILED
		status.state = STATE.STATE_COMPLETED

		if (err.result) then
			status.result = err.result
		end

		saveUpdateStatus(status)
	end

	local function onUpdateSuccess(packageInfo)
		local version = packageInfo.version

		status.error = nil
		status.result = 0
		status.state = STATE.STATE_UPDATING
		status.version = version
		saveUpdateStatus(status)
		print('Latest Version: ' .. tostring(version))
	end

	local function onInstallError(err)
		print('Error: ' .. tostring(err))
		status.error = tostring(err)
		status.result = RESULT.UPDATE_FAILED
		status.state = STATE.STATE_COMPLETED
		if (err.result) then
			status.result = err.result
		end
		saveUpdateStatus(status)
	end

	local function onInstallSuccess(message)
		if (message) then
			print(message)
		end

		status.message = message
		status.result = RESULT.UPDATE_SUCCESSFULLY
		status.state = STATE.STATE_COMPLETED
		saveUpdateStatus(status)

		setTimeout(5000, function()
			os.reboot()
		end)
	end

	-- 开始下载并安装固件
	updater.update(function(err, filename, packageInfo)
		if (err) then
			onUpdateError(err)
			return
		end

		onUpdateSuccess(packageInfo)

		upgrade.install(filename, function(err, message)
			if (err) then
				onInstallError(err)

			else
				onInstallSuccess(message)
			end
		end)
	end)
end

-------------------------------------------------------------------------------
-- exports

-- Download firmware files only
function exports.update(callback)
	-- callback
	if (type(callback) ~= 'function') then
		callback = function(err, filename, packageInfo)
			updater.printUpdateResult(err, packageInfo)
		end
	end

	local status = {}
	status.result = RESULT.UPDATE_INIT
	status.state = STATE.STATE_DOWNLOADING
	saveUpdateStatus(status)

	updater.update(function (err, filename, packageInfo)
		if (err) then
			status.error = tostring(error)
			status.result = RESULT.UPDATE_FAILED
			status.state = STATE.STATE_ERROR

		else
			status.result = RESULT.UPDATE_INIT
			status.state = STATE.STATE_DOWNLOAD_COMPLETED
		end

		saveUpdateStatus(status)
	end)
end

-- Download and install firmware file
function exports.upgrade(applet)

	local function printUpgradeStatus()
		local status = readUpdateStatus() or {}
		local state = status.state or 0
		local result = status.result or 0
		print('State: ' .. getUpdateStateString(state))
		print('Result: ' .. getUpdateResultString(result))
		if (status.version) then
			print('Version: ' .. (status.version))
		end

		if (status.error) then
			print('Error: ' .. (status.error))
		end

		local now = Date.now()
		local span = math.floor(now - (status.updated or 0))
		print('Updated: ' .. span .. 's ago')
	end

	if (applet == 'firmware') then
		upgradeFirmwareFile()

	elseif (applet == 'system') then
		upgradeFirmwareFile()

	elseif (applet == 'status') then
		printUpgradeStatus()

	elseif (applet == 'clean') then
		upgrade.clean(process.version)

	else
		printUpgradeStatus()
	end
end

-- Install firmware files only
function exports.install(filename)

	if (not filename) then
		-- 如果是要安装 update 下载的文件，检查固件下载状态
		local status = readUpdateStatus()
		if (not status) or (status.state ~= STATE.STATE_DOWNLOAD_COMPLETED) then
			local err = 'Error: Please update firmware first.'
			print(err)
			return err
		end
	end

	return installFirmwareFile(filename)
end

return exports
