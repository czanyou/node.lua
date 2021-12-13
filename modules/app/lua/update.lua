local fs        = require('fs')
local json      = require('json')
local path      = require('path')
local util      = require('util')

local request  	= require('http/request')
local app   	= require('app')
local rpc       = require('app/rpc')
local upgrade 	= require('app/upgrade')
local bundle    = require('app/bundle')

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

local updater = {}

-- 发送固件升级事件
---@param status table
local function sendUpdateEvent(status)
    local params = { status }
    rpc.call('wotc', 'firmware', params, function(err, result) end)
end

-------------------------------------------------------------------------------
-- updater

function updater.getUpdateResultString(result)
	local titles = {
		'init', 'successfully', 'notEnoughFlash', 'notEnoughRAM', 'disconnected',
		'validationFailed', 'unsupportedFirmwareType', 'invalidUri', 'failed',
		'unsupportedProtocol'
	}

	result = tonumber(result) or 0
	return titles[result + 1] or tostring(result)
end

function updater.getUpdateStateString(state)
	local states = {
		'init', 'downloading', 'downloaded', 'updating', 'completed', 'error'
	}

	state = tonumber(state) or 0
	return states[state + 1] or tostring(state)
end

function updater.saveUpdateStatus(status)
	if (not status) then
		return

	elseif (type(status) ~= 'table') then
		return
	end

	status = util.clone(status)

	local basePath = path.join(os.tmpdir, 'update')
	local ret, err = fs.mkdirpSync(basePath)
	if (err) then
		print(err)
		return nil, err
	end

	status.updated = Date.now()
	if (status.state) then
		status.state = updater.getUpdateStateString(status.state) or status.state
	end

	if (status.result) then
		status.result = updater.getUpdateResultString(status.result) or status.result
	end

	local filename = path.join(basePath, 'update.json')
	local filedata = fs.readFileSync(filename)
	local output = json.stringify(status)
	if (output and output ~= filedata) then
		fs.writeFileSync(filename, output)
	end

	-- console.log('sendUpdateEvent', status)
	sendUpdateEvent(status)
end

function updater.readUpdateStatus()
	local filename = path.join(os.tmpdir, 'update/update.json')
	local filedata = fs.readFileSync(filename)
	if (filedata) then
		return json.parse(filedata)
	end
end

function updater.printInfo(...)
	print(...)
end

---@return string
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

---@param filename string Firmware filename
---@param packageInfo table
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
			printInfo('Error: ' .. tostring(err))
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

		if (response.statusCode >= 400) then
			callback({
				code = RESULT.UPDATE_DISCONNECTED,
				error = response.statusMessage
			})
			return
		end

		-- write to a temp file
		console.write('\rDownloading: Done        \r\n')

		-- save firmware file
		updater.saveFirmwareFile(filename, response.body, packageInfo, callback)
	end)
end

---@param filename string
---@param filedata string
---@param packageInfo table
---@param callback function
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
---@param version string
---@return integer return number value of the version
function updater.parseVersion(version)
	local function parseVersionNumber(value)
		value = tonumber(value) or 0
		return value % 10000
	end

	version = version and tostring(version)
	if (not version) then
		return 0
	end

	local tokens = version:split('.')
	return (parseVersionNumber(tokens[1]) * 10000 * 10000)
		+ (parseVersionNumber(tokens[2]) * 10000)
		+ (parseVersionNumber(tokens[3]))
end

--
-- Download system 'firmware.json' file
-- @param {object} options
--  - options.type
--  - options.did
--  - options.base
---@param callback fun(err:table)
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
		-- console.log(err, percent, response);

		if (err) then
			callback({ code = RESULT.UPDATE_DISCONNECTED, error = err })
			return

		elseif (percent and (percent < 100)) or (not response) then
			return
		end

		if (response.statusCode >= 400) then
			callback({
				code = RESULT.UPDATE_DISCONNECTED,
				error = response.statusMessage
			})
			return
		end

		-- check firmware info
		local packageInfo = json.parse(response.body)
		if (not packageInfo) then
			callback({
				code = RESULT.UPDATE_VALIDATION_FAILED,
				error = "Firmware information is not valid JSON string." 
			})
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
	if (not packageInfo) or (not packageInfo.version) then
		return
	end

	local printInfo = updater.printInfo

	local version = updater.parseVersion(packageInfo.version)
	local current = updater.parseVersion(process.version)
	printInfo('Current Version: ' .. process.version)

	if (version < current) then
		printInfo('New Version: ' .. tostring(packageInfo.version))
	end

	printInfo('Updated: ' .. tostring(packageInfo.updated))
	printInfo('Size: ' .. tostring(packageInfo.size))
	printInfo('MD5: ' ..  tostring(packageInfo.md5sum))

	if (packageInfo.description and #packageInfo.description > 0) then
		printInfo('Description: ' .. tostring(packageInfo.description))
	end
end


---@param firmwareInfo string
---@param packageInfo table
---@param callback function
function updater.saveFirmwareInfo(firmwareInfo, packageInfo, callback)
	callback = callback or function() end
	if (not firmwareInfo) then
		callback('invalid firmwareInfo')
		return
	end

	local basePath  = path.join(os.tmpdir, 'update')
	local _, error = fs.mkdirpSync(basePath)
	if (error) then
		callback({ code = RESULT.UPDATE_NOT_ENOUGH_FLASH, error = error })
		return
	end

	local filename 	= path.join(basePath, 'firmware.json')
	local filedata  = fs.readFileSync(filename)
	if (filedata == firmwareInfo) then
		callback(nil, packageInfo)
		return
	end

	local tempname 	= path.join(basePath, 'firmware.json.tmp')
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

---@param filename string
---@param callback fun(err:string, packageInfo:table)
function updater.checkFirmwareFile(filename, callback)
	callback = callback or function() end
	-- console.log('checkFirmwareFile', filename, callback)

	if (not filename) then
		return callback('bad filename')
	end

	-- check firmware file format
	local reader = bundle.openBundle(filename)
	if (not reader) then
		return callback('bad file')
	end

	local packageInfo = upgrade.getPackageInfo(reader)
	reader:close()
	reader = nil

	local version = packageInfo and packageInfo.version
	if (not version) then
		console.log('packageInfo', packageInfo)
		return callback({ code = RESULT.UPDATE_VALIDATION_FAILED, error = 'Invalid firmware file format'});
	end

	callback(nil, packageInfo)
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
---@param callback fun(err:string|table, filename:string, packageInfo:table)
function updater.updateFirmwareInfo(callback)
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
		local error = 'Missing the required config parameter `base`'
		printInfo(error);
		return callback(error)

	elseif (not options.did) then
		local error = 'Missing the required config parameter `did`'
		printInfo(error);
		return callback(error)
	end

	if (not options.base:endsWith('/')) then
		options.base = options.base .. '/'
	end

	-- downloading firmware info
	updater.getFirmwareInfo(options, function(err, packageInfo)
		-- console.log('Firmware Info:', packageInfo);
		if (err) then
			return callback(err)

		elseif (not packageInfo) then
			return callback('Invalid firmware info')
		end

		callback(nil, options, packageInfo)
	end)
end

-------------------------------------------------------------------------------
-- install


local function onUpdateError(status, err)
	-- update error
	console.warn('firmware update error: ', err)

	status.error = err and tostring(err)
	status.result = RESULT.UPDATE_FAILED
	status.state = STATE.STATE_COMPLETED

	if (err and err.result) then
		status.result = err.result
	end

	updater.saveUpdateStatus(status)
end

local function onUpdateStarting(status)
	console.warn('firmware update starting')

	status.error = nil
	status.result = nil
	status.state = STATE.STATE_DOWNLOADING

	updater.saveUpdateStatus(status)
end

local function onUpdateDownloading(status, options, packageInfo)
	packageInfo = packageInfo or {}
	console.warn('firmware start downloading', packageInfo.name, packageInfo.size)

	status.base = options.base
	status.md5sum = packageInfo.md5sum
	status.name = packageInfo.name
	status.size = packageInfo.size
	status.state = STATE.STATE_DOWNLOADING

	updater.saveUpdateStatus(status)

	status.base = nil
	status.md5sum = nil
	status.name = nil
	status.size = nil
end

local function onUpdateCompleted(status, packageInfo)
	packageInfo = packageInfo or {}
	console.warn('firmware download completed', packageInfo.name, packageInfo.target, packageInfo.version)

	-- download completed
	status.target = packageInfo.target
	status.name = packageInfo.name
	status.result = nil
	status.version = packageInfo.version
	status.state = STATE.STATE_DOWNLOAD_COMPLETED

	updater.saveUpdateStatus(status)

	status.base = nil
	status.target = nil
	status.name = nil
	status.version = nil
end

local function onInstallStarting(status, packageInfo)
	local version = packageInfo and packageInfo.version
	console.warn('firmware start installing', version)

	status.error = nil
	status.freeSize = upgrade.getFreeFlashSize()
	status.result = nil
	status.state = STATE.STATE_UPDATING
	status.version = version

	updater.saveUpdateStatus(status)

	status.freeSize = nil
end

local function onInstallCompleted(status, message)
	console.warn('firmware installed', message)

	-- update completed
	status.message = message
	status.result = RESULT.UPDATE_SUCCESSFULLY
	status.state = STATE.STATE_COMPLETED

	updater.saveUpdateStatus(status)
end

local function onRebootDevice(delay)
	-- reboot in 10 seconds
	local rebootTimes = delay or 10
	local rebootTimer = nil
	rebootTimer = setInterval(1000, function()
		print("The system will reboot in " .. rebootTimes .. " seconds")
		rebootTimes = rebootTimes - 1
		if (rebootTimes <= 0) then
			clearInterval(rebootTimer)

			os.reboot()
		end
	end)
end

---@param filename string
---@param callback fun(err:string, message:string)
function updater.installFirmwareFile(filename, callback)
	if (type(filename) == 'function') then
		callback = filename
		filename = nil
	end

	if (type(callback) ~= 'function') then
		local status = {}
		onInstallStarting(status)

		callback = function(err, message)
			if (err) then
				onUpdateError(status, err)

			else
				onInstallCompleted(status)
			end
		end
	end

	-- 开始安装
	upgrade.install(filename, callback)
end

-- Download and install the latest firmware
---@param callback function
function updater.upgradeFirmwareFile(callback)
	local status = {}

	util.async(function()

		-- 更新固件信息
		onUpdateStarting(status)

		local filename, message
		local err, options, packageInfo = util.await(updater.updateFirmwareInfo)
		if (err or not packageInfo) then
			onUpdateError(err)
			return
		end

		-- downloading firmware file
		onUpdateDownloading(status, options, packageInfo)

		err, filename = util.await(updater.downloadPackage, options, packageInfo)
		if (err) then
			onUpdateError(err)
			return
		end

		err, packageInfo = util.await(updater.checkFirmwareFile, filename)
		if (err) then
			onUpdateError(err)
			return
		end

		-- installing firmware file
		onInstallStarting(status, packageInfo)

		err, message = util.await(upgrade.install, filename)
		if (err) then
			onUpdateError(status, err)

		else
			onInstallCompleted(status, message)
			onRebootDevice()
		end
	end)
end

exports.updater = updater

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

	-- downloading
	local status = {}

	onUpdateStarting(status)

	updater.updateFirmwareInfo(function (err, options, packageInfo)
		if (err) then
			return onUpdateError(status, err)
		end

		updater.downloadPackage(options, packageInfo, function(err, filename)
			if (err) then
				return onUpdateError(status, err)
			end

			updater.checkFirmwareFile(filename, function(err, packageInfo, ...)
				if (err) then
					return onUpdateError(status, err)
				end

				onUpdateCompleted(status, packageInfo)
			end)
		end)
	end)
end

-- Download and install firmware file
---@param applet string `firmware|system|status|clean`
function exports.upgrade(applet)

	local function printUpgradeStatus()
		local status = updater.readUpdateStatus() or {}
		local state = status.state or 0
		local result = status.result or 0
		print('State: ' .. updater.getUpdateStateString(state))
		print('Result: ' .. updater.getUpdateResultString(result))
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
		updater.upgradeFirmwareFile()

	elseif (applet == 'system') then
		updater.upgradeFirmwareFile()

	elseif (applet == 'status') then
		printUpgradeStatus()

	elseif (applet == 'clean') then
		upgrade.clean(process.version)

	else
		printUpgradeStatus()
	end
end

-- Install firmware files only
---@param filename string
function exports.install(filename)

	if (not filename) then
		-- 如果是要安装 update 下载的文件，检查固件下载状态
		local status = updater.readUpdateStatus()
		if (not status) or (status.state ~= STATE.STATE_DOWNLOAD_COMPLETED) then
			local err = 'Error: Please update firmware first.'
			print(err)
			return err
		end
	end

	return updater.installFirmwareFile(filename)
end

return exports
