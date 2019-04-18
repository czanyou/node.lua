local core      = require('core')
local fs        = require('fs')
local http      = require('http')
local json      = require('json')
local miniz     = require('miniz')
local path      = require('path')
local thread    = require('thread')
local timer     = require('timer')
local url       = require('url')
local utils     = require('util')
local qstring   = require('querystring')

local request  	= require('http/request')
local conf   	= require('app/conf')
local ext   	= require('app/utils')

local exports = {}

local formatFloat 		= ext.formatFloat
local formatBytes 		= ext.formatBytes
local noop 		  		= ext.noop
local getSystemTarget 	= ext.getSystemTarget

local function getNodePath()
	return conf.rootPath
end

local function getRootPath()
	return '/'
end

local function getRootURL()
	local rootURL = require('app').rootURL
	if (not rootURL) then
		print('Unknown root URL.')
	end

	return rootURL
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

-- Download system 'package.json' file
local function downloadSystemInfo(options, callback)
	options = options or {}
	local printInfo = options.printInfo or function() end

	-- URL
	local arch      = os.arch()
	local target 	= getSystemTarget()
	local rootURL 	= getRootURL()
	if (not rootURL) then
		return
	end

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

-- Download system 'package.json' and patch files
local function downloadUpdateFiles(options, callback)
	options = options or {}
	local printInfo = options.printInfo or function() end

	-- System update URL
	local target 	= getSystemTarget()
	local rootURL 	= getRootURL() or 'http://127.0.0.1'
	if (not rootURL) then
		return
	end

	-- Update Path
	local nodePath  = getNodePath()
	local basePath  = path.join(nodePath, 'update')
	local ret, err = fs.mkdirpSync(basePath)
	if (err) then
		print(err)
		return
	end

	local md5sum      = ''
	local version   = process.version or ''

	-- package.json
	local filename 	= path.join(basePath, 'package.json')
	local filedata  = fs.readFileSync(filename)
	local packageInfo = json.parse(filedata)
	if (packageInfo) then
		md5sum = packageInfo.md5sum or ''
	end

	--console.log(filename)

	local baseURL 	= rootURL .. '/update/'
	local url 		= baseURL .. '&type=' .. (options.type or 'sdk') 
	url 		= url .. '?target=' .. target
	url 		= url .. '&md5sum=' .. md5sum
	url 		= url .. '&version=' .. version

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
end


-- Dnowload update files only
function exports.update(callback)
	local options = { type = 'patch' }
	
	if (type(callback) ~= 'function') then
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
	end

	downloadUpdateFiles(options, callback)
end

return exports
