local app 		= require('app')
local util 		= require('util')
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

local function get_source_path()
	local filename = path.join(cwd, 'core/deps/lua')
	if (fs.existsSync(filename)) then
		return cwd
	end

	local sourcePath = util.dirname()
	sourcePath = path.dirname(sourcePath)
	sourcePath = path.dirname(sourcePath)
	sourcePath = path.dirname(sourcePath)
	console.log('sourcePath', sourcePath);
	return sourcePath
end

function sdk.build_common_sdk(target, packageInfo)
	local sourcePath = get_source_path()
	console.log('sourcePath', sourcePath)

	local sdkPath  = sdk.get_sdk_build_path(target, packageInfo.type)
	local nodePath = join(sdkPath, "usr/local/lnode")

	local mkdir = fs.mkdirpSync
	mkdir(join(nodePath, "lib"))

	local board = get_make_board()

	-- copy lib files
	local buildPath  = join(sourcePath, "build", board)

	local libs = packageInfo.libs or {}
	for _, file in ipairs(libs) do
		local destFile = join(nodePath, 'lib', file)
		copy(join(buildPath,  file), destFile)
	end

	-- copy modules lua files
	local visionPath = join(sourcePath, "modules")
	--xcopy(visionPath, join(nodePath, "lib"))

	local files = fs.readdirSync(visionPath)
	if (files) then
		for i = 1, #files do
			local name = files[i]
			local luaPath = join(visionPath, name, "lua")
			--console.log(luaPath)

			if (fs.existsSync(luaPath)) then
				xcopy(luaPath, join(nodePath, "lib", name))
			end
		end
	end

	if (packageInfo.type ~= 'patch') then
		mkdir(join(nodePath, "bin"))
		mkdir(join(nodePath, "lua"))

		copy(buildPath .. "/lnode", join(nodePath, "bin/lnode"))

		-- copy node lua files
		local nodeluaPath = join(sourcePath, "core")
		copy (nodeluaPath .. "/bin/lpm",       nodePath .. "/bin/lpm")
		xcopy(nodeluaPath .. "/lua", 	       nodePath .. "/lua")
		--console.log(nodeluaPath .. "/lua", 	       nodePath .. "/lua")

		-- copy target files
		local dirname = util.dirname()
		local targetPath = join(dirname, "targets/linux/local")
		xcopy(join(targetPath, "usr"),  join(sdkPath , "usr"))

		--console.log(targetPath)
		copy(join(targetPath, 'install.sh'), join(sdkPath, 'install.sh'))
		fs.chmodSync(join(sdkPath, 'install.sh'), 511)
	end

	::exit::

	-- Applications
	local applications = packageInfo.applications
	--console.log('applications', applications)
	if (applications) then
		for i = 1, #applications do
			local name = applications[i]
			local appPath = join(sourcePath, 'app', name)
			--console.log(appPath)

			if (fs.existsSync(appPath)) then
				xcopy(appPath, join(nodePath, "app", name))
			else
				console.log('APP', name, 'does not exists!');
			end
		end
	end

	-- update package.json
	packageInfo.files = nil
	local packageText = json.stringify(packageInfo)
	fs.writeFileSync(join(nodePath, "package.json"), packageText)
	fs.writeFileSync(join(sdkPath,  "package.json"), packageText)
end

-------------------------------------------------------------------------------
-- win

function sdk.build_win_sdk(target, packageInfo)
	local nodePath 		= join(cwd, "core")
	local binPath 		= join(cwd, "bin")
	local releasePath 	= join(cwd, "build/win32/Release")
	local sdkPath 		= sdk.get_sdk_build_path(target)

	local mkdir = fs.mkdirpSync
	mkdir(join(sdkPath, "lnode/app"))
	mkdir(join(sdkPath, "lnode/bin"))
	mkdir(join(sdkPath, "lnode/conf"))
	mkdir(join(sdkPath, "lnode/lua"))

	-- copy node lua files
	copy(nodePath .. "/install.lua", 	sdkPath .. "/lnode/install.lua")
	copy(nodePath .. "/install.bat", 	sdkPath .. "/lnode/install.bat")
	copy(binPath .. "/lmbedtls.dll", 	sdkPath .. "/lnode/bin/lmbedtls.dll")
	copy(binPath .. "/lmodbus.dll", 	sdkPath .. "/lnode/bin/lmodbus.dll")
	copy(binPath .. "/lnode.exe", 		sdkPath .. "/lnode/bin/lnode.exe")
	copy(binPath .. "/lpm.bat", 		sdkPath .. "/lnode/bin/lpm.bat")
	copy(binPath .. "/lsqlite.dll",		sdkPath .. "/lnode/bin/lsqlite.dll")
	copy(binPath .. "/lua53.dll", 		sdkPath .. "/lnode/bin/lua53.dll")
	xcopy(nodePath .. "/lua", 			sdkPath .. "/lnode/lua")

	-- copy vision lua files
	local visionPath = join(cwd, "modules/lua")
	xcopy(visionPath, join(sdkPath, "lnode/lib"))
	local modulePath = join(nodePath, "../modules")

	xcopy(join(modulePath, 'app/lua'), 			join(sdkPath, "lnode/lib/app"))
	xcopy(join(modulePath, 'bluetooth/lua'), 	join(sdkPath, "lnode/lib/bluetooth"))
	xcopy(join(modulePath, 'express/lua'), 		join(sdkPath, "lnode/lib/express"))
	xcopy(join(modulePath, 'mqtt/lua'), 		join(sdkPath, "lnode/lib/mqtt"))
	xcopy(join(modulePath, 'rtmp/lua'), 		join(sdkPath, "lnode/lib/rtmp"))
	xcopy(join(modulePath, 'rtsp/lua'), 		join(sdkPath, "lnode/lib/rtsp"))
	xcopy(join(modulePath, 'sdl/lua'), 			join(sdkPath, "lnode/lib/sdl"))
	xcopy(join(modulePath, 'sqlite3/lua'), 		join(sdkPath, "lnode/lib/sqlite3"))
	xcopy(join(modulePath, 'ssdp/lua'), 		join(sdkPath, "lnode/lib/ssdp"))
	xcopy(join(modulePath, 'wot/lua'), 			join(sdkPath, "lnode/lib/wot"))

	-- copy app files
	local applications = {"lpm", "gateway"}
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

	--console.log(util.dirname())
	local dirname = util.dirname()

	-- build sdk filesystem
	local filename = path.join(cwd, 'package.json')
	if (not fs.existsSync(filename)) then
		filename = path.join(dirname, '..', 'targets', platform, board, 'package.json')
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

	--console.log(target)

	-- build zip file
	local pathname  = path.join(cwd, "/build/", (type or "sdk"), target)
    local builder = zlib.ZipBuilder:new()
    builder:build(pathname)

	-- build package info
    print('Builded: "build/sdk/' .. target .. '.zip".')
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
	local dirname = util.dirname()
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
	local fileHash = util.bin2hex(util.md5(fileData))

	local package = packageInfo or {}
	local version = get_make_version()

	local registry = package.registry
	if (type(registry) ~= 'table') then
		registry = { url = app.rootURL }
	end

	local username = registry.username or 'cz'
	local password = registry.password or '888888'
	local passhash = util.bin2hex(util.md5(username .. ":" .. password))
	registry.username 	= username

	local value = username .. ":" .. passhash .. ":" .. fileHash
	registry.sign 		= util.bin2hex(util.md5(value))

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
	return join(process.cwd(), "build", (type or 'sdk') .. "/" .. target)
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
	local upload = require('./upload')
	upload.upload_sdk_package(...)
end

function exports.help()
	print([[

Node.lua SDK and application build tools

usage: lbuild <command> [args]

- help    Display help information
- sdk	  Build Node.lua SDK package (Must `make <target>` firist)
- upload  Upload Node.lua SDK package (Must `make sdk` firist)

please execute this APP by the Makefile.

]])

	print("Current make target is: " .. get_make_target())
	print("")
end

app(exports)
