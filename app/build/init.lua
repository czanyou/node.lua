local app 		= require('app')
local utils 	= require('util')
local path  	= require('path')
local fs  		= require('fs')
local zlib  	= require('zlib')
local json  	= require('json')

local exec      = require('child_process').exec

local copy  	= fs.copyfileSync
local cwd		= process.cwd()
local join  	= path.join

-------------------------------------------------------------------------------
-- copy

local platform = os.platform()
local arch = os.arch()

-------------------------------------------------------------------------------
-- 

local exports = {}

local copy_files

--[[
复制文件或目录，相当于 `cp -rf`
@param source {String} 源文件
@param target {String} 目标文件
--]]
function copy_files(source, target)
	if (not source) or (not target) then
		return
	end

	local join  = path.join
	fs.mkdirpSync(target)

	local files = fs.readdirSync(source)
    if (not files) then 
    	return 
    end

    for i = 1, #files do
        local name = files[i]
        if (name:sub(1, 1) ~= ".") then
            local stat = fs.statSync(join(source, name))
            if (not stat) then
            	console.log(source, name)
            end

            if (stat.type == 'file') then
            	copy(join(source, name), join(target, name))

            elseif (stat.type == 'directory') then
            	copy_files(join(source, name), join(target, name))
            end
        end
    end
end 

local xcopy = copy_files

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

local sdk = {}

function sdk.build_common_sdk(target, packageInfo)
	local sdkPath  = sdk.get_sdk_build_path(target, packageInfo.type)
	local nodePath = join(sdkPath, "usr/local/lnode")

	local mkdir = fs.mkdirpSync
	mkdir(join(nodePath, "lib"))

	local board = get_make_board()

	-- copy lib files
	local buildPath  = join(cwd, "build", board)

	local libs = packageInfo.libs or {}
	for _, file in ipairs(libs) do
		local destFile = join(nodePath, 'lib', file)
		copy(join(buildPath,  file), destFile)
	end

	-- copy modules lua files
	local visionPath = join(cwd, "modules")
	--xcopy(visionPath, join(nodePath, "lib"))

	local files = fs.readdirSync(visionPath)
	if (files) then
		for i = 1, #files do
			local name = files[i]
			local luaPath = join(visionPath, name, "lua")
			console.log(luaPath)

			if (fs.existsSync(luaPath)) then
				xcopy(luaPath, join(nodePath, "lib", name))
			end
		end
	end

	-- copy app files
	mkdir(join(nodePath, "app"))
	local applications = packageInfo.applications or {}
	for _, key in ipairs(applications) do
		local file =  key
		xcopy(join(cwd, "app", file),  join(nodePath , "app", file))
	end

	if (packageInfo.type ~= 'patch') then
		mkdir(join(nodePath, "bin"))
		mkdir(join(nodePath, "conf"))
		mkdir(join(nodePath, "lua"))

		copy(buildPath .. "/lnode", join(nodePath, "bin/lnode"))

		-- copy node lua files
		local nodeluaPath = join(cwd, "node.lua")
		copy (nodeluaPath .. "/bin/lpm",       nodePath .. "/bin/lpm")
		xcopy(nodeluaPath .. "/lua", 	       nodePath .. "/lua")

		-- copy target files
		local dirname = utils.dirname()
		local targetPath = join(dirname, "targets/linux/local")
		xcopy(join(targetPath, "usr"),  join(sdkPath , "usr"))

		console.log(targetPath)
		copy(join(targetPath, 'install.sh'), join(sdkPath, 'install.sh'))
		fs.chmodSync(join(sdkPath, 'install.sh'), 511)
	end

	::exit::

	-- update package.json
	packageInfo.files = nil
	local packageText = json.stringify(packageInfo)
	fs.writeFileSync(join(nodePath, "package.json"), packageText)
	fs.writeFileSync(join(sdkPath,  "package.json"), packageText)
end

-------------------------------------------------------------------------------
-- win

function sdk.build_win_sdk(target, packageInfo)
	local nodePath 		= join(cwd, "node.lua")
	local releasePath 	= join(cwd, "build/win32/Release")
	local sdkPath 		= sdk.get_sdk_build_path(target)

	local mkdir = fs.mkdirpSync
	mkdir(join(sdkPath, "lnode/app"))
	mkdir(join(sdkPath, "lnode/bin"))
	mkdir(join(sdkPath, "lnode/conf"))
	mkdir(join(sdkPath, "lnode/lua"))	

	-- copy node lua files
	copy(nodePath .. "/install.lua", 		sdkPath .. "/lnode/install.lua")
	copy(nodePath .. "/install.bat", 		sdkPath .. "/lnode/install.bat")
	copy(nodePath .. "/bin/lpm.bat", 		sdkPath .. "/lnode/bin/lpm.bat")
	copy(nodePath .. "/bin/lts.dll", 		sdkPath .. "/lnode/bin/lts.dll")
	copy(nodePath .. "/bin/lsqlite.dll",	sdkPath .. "/lnode/bin/lsqlite.dll")
	copy(nodePath .. "/bin/lnode.exe", 		sdkPath .. "/lnode/bin/lnode.exe")
	copy(nodePath .. "/bin/lua53.dll", 		sdkPath .. "/lnode/bin/lua53.dll")
	xcopy(nodePath .. "/lua", 				sdkPath .. "/lnode/lua")

	-- copy vision lua files
	local visionPath = join(cwd, "modules/lua")
	xcopy(visionPath, join(sdkPath, "lnode/lib"))
	local modulePath = join(nodePath, "../modules")

	xcopy(join(modulePath, 'bluetooth/lua'), 	join(sdkPath, "lnode/lib/bluetooth"))
	xcopy(join(modulePath, 'express/lua'), 		join(sdkPath, "lnode/lib/express"))
	xcopy(join(modulePath, 'mqtt/lua'), 		join(sdkPath, "lnode/lib/mqtt"))
	xcopy(join(modulePath, 'sdl/lua'), 			join(sdkPath, "lnode/lib/sdl"))
	xcopy(join(modulePath, 'sqlite3/lua'), 		join(sdkPath, "lnode/lib/sqlite3"))
	xcopy(join(modulePath, 'ssdp/lua'), 		join(sdkPath, "lnode/lib/ssdp"))

	-- copy app files
	local applications = {"httpd", "ssdp", "mqtt", "sdcp", "lhost"}
	for _, key in ipairs(applications) do
		local file =  key
		xcopy(join(cwd, "app", file),  join(sdkPath , "lnode/app", file))
	end

	-- package.json
	packageInfo.files = nil
	fs.writeFileSync(sdkPath .. "/lnode/package.json", json.stringify(packageInfo))
	fs.writeFileSync(sdkPath .. "/package.json", json.stringify(packageInfo))
end

-------------------------------------------------------------------------------
-- build

function sdk.build_sdk(target, type)
	local board = get_make_board()

	--console.log(utils.dirname())
	local dirname = utils.dirname()

	-- build sdk filesystem
	local filename = path.join(cwd, 'package.json')
	if (not fs.existsSync(filename)) then
		filename = path.join(dirname, 'targets', platform, board, 'package.json')
	end

	print('package.json: ' .. filename)

	local filedata = fs.readFileSync(filename)
	local packageInfo = json.parse(filedata)
	if (not packageInfo) then
		print('`package.json` not found or invalid.', filename)
		return false
	end

	packageInfo.version = get_make_version()
	packageInfo.target  = target
	packageInfo.type    = type

	if (platform == 'win32') then
		sdk.build_win_sdk(target, packageInfo)
	else
		sdk.build_common_sdk(target, packageInfo)
	end


	return packageInfo
end

--[[
生成 SDK 包文件，相当于 ZIP 打包。

@param target {String} 构建目标，如 win,linux,pi 等等.
--]]
function sdk.build_sdk_package(type)
	local target = get_make_target()
	local packageInfo = sdk.build_sdk(target, type)

	console.log(target)

	-- build zip file
	local name = "nodelua-" .. target .. "-" .. (type or "sdk")
	local pathname  = path.join(cwd, "/build/", name)
    local builder = zlib.ZipBuilder:new()
    builder:build(pathname)

	-- build package info
    print('Builded: "build/' .. name .. '.zip".')
    sdk.build_sdk_package_info(target, packageInfo)
end

function sdk.build_tar_package()
	local target = get_make_target()
	local packageInfo = sdk.build_sdk(target)

	-- build tar.gz file
	local name = "nodelua-" .. target .. "-sdk"
    local cmd = "cd build/" .. name .. "; tar -zcvf ../" .. name .. ".tar.gz *"
    os.execute(cmd)

    print('Builded: "build/' .. name .. '.tar.gz".')
end

function sdk.build_deb_package()
	local target = get_make_target()
	local packageInfo = sdk.build_sdk(target)

	local sdk_name = "nodelua-" .. target .. "-sdk"
	local deb_name = "nodelua-" .. target
	local sdk_path  = path.join(cwd, "/build/", sdk_name)
	local deb_path  = path.join(cwd, "/build/", deb_name .. "-deb")

	-- deb files
	fs.mkdirpSync(deb_path .. '/usr/local/lnode/')
	os.execute('rm -rf ' .. deb_path .. '/usr/local/lnode/*')
	os.execute('cp -rf ' .. sdk_path .. '/usr/local/lnode/* ' .. deb_path .. '/usr/local/lnode/')

	-- deb meta files
	local dirname = utils.dirname()
	local src = path.join(dirname, 'targets/linux/deb')
	os.execute('cp -rf ' .. src .. '/* ' .. deb_path .. '/')
	os.execute('chmod -R 755 ' .. deb_path .. '/DEBIAN')

	-- build deb package
	local deb_file = path.join(cwd, "/build/", deb_name .. ".deb")
    local cmd = 'dpkg -b ' .. deb_path .. ' ' .. deb_file
    local options = { timeout = 30 * 1000, env = process.env }
    exec(cmd, options, function(err, stdout, stderr) 
        print(stderr or (err and err.message) or stdout)
    end)
end

--[[
生成 SDK 包文件描述文件, 包含SDK 包长度，版本，创建日期等信息。

将生成和 SDK 包同名，但扩展名为 json 的文本文件。

@param target {String} 构建目标，如 win,linux,pi 等等.
--]]
function sdk.build_sdk_package_info(target, packageInfo)
	local utils 	= require('util')
	local json 		= require('json')

	local name 		= "nodelua-" .. target .. "-" .. (packageInfo.type or "sdk")

	local buildPath = path.join(cwd, "/build/")
	local filename  = path.join(buildPath, name .. ".zip")
	local statInfo  = fs.statSync(filename)
	if (not statInfo) then
		return
	end

	local fileData = fs.readFileSync(filename)
	if (not fileData) then
		return
	end

	local fileSize = fileData and #fileData
	local fileHash = utils.bin2hex(utils.md5(fileData))

	local package = packageInfo or {}
	local version = get_make_version()

	local registry = package.registry
	if (type(registry) ~= 'table') then
		registry = { url = app.rootURL }
	end

	local username = registry.username or 'cz'
	local password = registry.password or '888888'
	local passhash = utils.bin2hex(utils.md5(username .. ":" .. password))
	registry.username 	= username

	local value = username .. ":" .. passhash .. ":" .. fileHash
	registry.sign 		= utils.bin2hex(utils.md5(value))

	package['target'] 	= target
	package['arch'] 	= os.arch()
	package['size'] 	= fileSize
	package['filename'] = name .. "." .. version .. ".zip"
	package['md5sum']   = fileHash
	package['version']  = version
	package['mtime']    = statInfo.mtime.sec
	package['files']    = nil
	package['registry'] = registry

	filename = path.join(buildPath, name .. ".json")
	fs.writeFileSync(filename, json.stringify(package))

    print('Builded SDK info: "build/' .. name .. '.json".')
end

--[[
生成 SDK 目录框架 (如 /bin/nodelua-xxx-sdk/*)

@param target {String} 构建目标，如 win,linux,pi 等等.
--]]
function sdk.get_sdk_build_path(target, type)
	return join(process.cwd(), "build", "nodelua-" .. target .. "-" .. (type or 'sdk'))
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

	local request = require('http/request')
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

local function build_install_sh(name, url)
	local list = {}
	list[#list + 1] = '#!/bin/sh'
	list[#list + 1] = 'wget ' .. url .. ' -q -O /tmp/update.zip'
	list[#list + 1] = 'mkdir -p /tmp/lnode'
	list[#list + 1] = 'rm -rf /tmp/lnode/*; unzip /tmp/update.zip -d /tmp/lnode'
	list[#list + 1] = 'cd /tmp/lnode/; chmod 777 install.sh; ./install.sh;'
	list[#list + 1] = 'rm -rf /tmp/lnode/*'
	local data = table.concat(list, '\n')
	local filename = path.join(cwd, 'build', name .. ".sh")
	fs.writeFileSync(filename, data)
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
		callback('File not found: ')
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

-------------------------------------------------------------------------------
-- exports

function exports.sdk(...)
	sdk.build_sdk_package("sdk", ...)
	print(console.colorize("success", 'Finished!'))
end

function exports.patch(...)
	sdk.build_sdk_package("patch", ...)
	print(console.colorize("success", 'Finished!'))
end

function exports.deb(...)
	sdk.build_deb_package(...)
	print(console.colorize("success", 'Finished!'))
end

function exports.tar(...)
	sdk.build_tar_package(...)
	print(console.colorize("success", 'Finished!'))
end

function exports.upload(...)
	upload_sdk_package(...)
end

function exports.help()
	print([[

Node.lua SDK and application build tools

usage: lpm build <command> [args]

- help    Display help information
- sdk	  Build Node.lua SDK package (Must `make <target>` firist)
- upload  Upload Node.lua SDK package (Must `make sdk` firist)

please execute this APP by the Makefile.

]])

	print("Current make target is: " .. get_make_target())
	print("")
end

app(exports)
