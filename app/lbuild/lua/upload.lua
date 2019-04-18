local util 		= require('util')
local path  	= require('path')
local fs  		= require('fs')
local json  	= require('json')
local request   = require('http/request')

local platform = os.platform()
local arch = os.arch()

local function get_make_board()
    -- 只有 linux 下支持交叉编译
	local target = fs.readFileSync('build/target') or 'local'
	return target:trim()
end

local function get_make_target()
	local board = get_make_board()
	if (board ~= "local") then
		return board .. "-linux"
	end

	return arch .. "-" .. platform
end

local function get_make_version()
	local version = process.version
	version = version:trim()
	return version
end

-------------------------------------------------------------------------------
-- upload

--[[
上传指定的文件到服务器
@param name {String} 要上传的文件名
@param alias {String} 上传后在服务器上的名称，如果没有指定则和 name 一样
@param callback {Function} 回调方法
--]]
local function upload_file(base_url, name, dist, alias, callback)
	if (type(alias) == 'function') then
		callback = alias
		alias = nil

	elseif (type(callback) ~= 'function') then
		callback = function() end
	end

	local filename = path.join(cwd, 'build', name)
	local fileData = fs.readFileSync(filename)
	if (not fileData) then
		print('File not found: ' .. tostring(filename))
		callback('File not found: ')
		return
	end

	local urlString = base_url .. '/upload.php?v=1&format=json'
	if (dist) then
		urlString = urlString .. "&dist=" .. dist
	end

	local files = {file = { name = (alias or name), data = fileData } }
	local options = { files = files }

	request.upload(urlString, options, function(err, percent, response, body)
		--console.log(err, percent, body)
		if (err) then
			callback(err)
			return

		elseif (percent < 100) then
			console.write('\rUpload (' .. percent .. '%)...')
			return

		elseif (not response) then
			return

		elseif (response.statusCode ~= 200) then
			callback(response.statusCode .. ': ' .. tostring(response.statusMessage))
			return
		end

		local ret = json.parse(body) or {}
		print('\nURL: ' .. base_url .. '/' .. dist .. '/' .. (ret.name or '') .. '')
	    print('Done!\n')

	    callback()
	end)
end


-- wget http://node.sae-sz.com/download/dist/linux/nodelua-linux-sdk-dev.sh -q -O - | sh

--[[
上传已打包的 SDK 包文件以及其描述文件。

--]]
local function upload_sdk_package(mode)
	print('\nPublishing SDK package...\n======\n')

	local target = get_make_target()
	if (not target) then
		print('Missing package target parameter, ex: "win32","linux","pi"...')
		return
	end

	local type = "sdk"
	if (mode ~= 'latest') then
		type = "patch"
	end

	-- package file
	local name = "nodelua-" .. target .. "-" .. type
	local filename  = path.join(cwd, 'build', name .. ".zip")
	local statInfo, err  = fs.statSync(filename)
	if (not statInfo) then
		print(err)
		return
	end

	-- package info
	local filename = path.join(cwd, 'build', name .. ".json")
	local fileData = fs.readFileSync(filename)
	if (not fileData) then
		print('File not found: ' .. tostring(filename))
		return
	end

	-- registry uri
	local base_url = app.rootURL .. '/download'
	local packageInfo = json.parse(fileData) or {}
	local registry = packageInfo.registry or {}
	if (registry.url) then
		base_url = registry.url .. '/download'
	end

	print('Upload URL: ' .. base_url)
	print('')

	-- version
	local version = get_make_version()
	local dist = "dist/" .. target

	-- upload
	local bytes = app.formatBytes(statInfo.size)
	print('Uploading: "' .. name .. '.zip" (' .. bytes .. ')...')

	local upload_name = name .. '.' .. version .. '.zip'
	upload_file(base_url, name .. '.zip', dist, upload_name, function(err)
		if (err) then
			print("Error: ", err or 'Upload failed!')
			return
		end

		--local fileurl = base_url .. '/' .. dist .. '/' .. upload_name

		local upload_name = name .. '.json'

		-- Update the package JSON file
		print('Uploading: "' .. name .. '.json"...')
		upload_file(base_url, name .. '.json', dist, upload_name, function(err)
			if (err) then
				print("Error: ", err or 'Upload failed!')
				return
			end

			print(console.colorize("success", "Finished!"))
		end)
	end)
end

local exports = {}

exports.upload_sdk_package = upload_sdk_package

return exports
