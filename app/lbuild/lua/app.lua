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
			
			-- console.log(source, name)

            if (stat.type == 'file') then
            	copy(join(source, name), join(target, name))

            elseif (stat.type == 'directory') then
            	copy_files(join(source, name), join(target, name))
            end
        end
    end
end 

local xcopy = copy_files

local function getMakeBoard()
    -- 只有 linux 下支持交叉编译
	local target = fs.readFileSync('build/target') or 'local'
	target = target:trim()
	return target
end

local function getMakeTarget()
	local board = getMakeBoard()
	if (board == "local") then
		board = arch
	end

	return board .. "-" .. platform
end

local function getMakeVersion()
	local version = process.version
	version = version:trim()
	return version
end

local sdk = {}

--[[
生成 SDK 目录框架 (如 /bin/nodelua-xxx-sdk/*)

@param target {String} 构建目标，如 win,linux,pi 等等.
--]]
function sdk.getSDKBuildPath(target, type)
	return join(process.cwd(), "build", "sdk", target)
end

function sdk.buildCommonSDK(target, packageInfo)

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
	
	local sourcePath = get_source_path()
	console.log('sourcePath', sourcePath)

	local sdkPath  = sdk.getSDKBuildPath(target, packageInfo.type)
	local nodePath = join(sdkPath, "")

	local mkdir = fs.mkdirpSync
	mkdir(join(nodePath, "lib"))

	local board = getMakeBoard()

	-- copy lib files
	local buildPath  = join(sourcePath, "build", board)

	local libs = packageInfo.libs or {}
	-- console.log(libs)
	for _, file in ipairs(libs) do
		local destFile = join(nodePath, 'lib', file)
		console.log(destFile)
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
		copy(sourcePath .. "/app/lpm/bin/lpm", nodePath .. "/bin/lpm")

		-- copy node lua files
		local nodeluaPath = join(sourcePath, "core")
		xcopy(nodeluaPath .. "/lua", 	 nodePath .. "/lua")
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

function sdk.buildWindowSDK(target, packageInfo)
	local nodePath 		= join(cwd, "core")
	local binPath 		= join(cwd, "bin")
	local sdkPath 		= sdk.getSDKBuildPath(target)

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
	copy(binPath .. "/lua.exe", 		sdkPath .. "/lnode/bin/lua.exe")
	copy(binPath .. "/lpm.bat", 		sdkPath .. "/lnode/bin/lpm.bat")
	copy(binPath .. "/lsqlite.dll",		sdkPath .. "/lnode/bin/lsqlite.dll")
	copy(binPath .. "/lua53.dll", 		sdkPath .. "/lnode/bin/lua53.dll")
	copy(binPath .. "/nodelua.dll", 	sdkPath .. "/lnode/bin/nodelua.dll")
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
	xcopy(join(modulePath, 'devices/lua'), 		join(sdkPath, "lnode/lib/devices"))
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

function sdk.buildSDK(target, type)
	local board = getMakeBoard()
	if (board == 'local') then
		board = platform
	end

	--console.log(util.dirname())
	local dirname = util.dirname()

	-- build sdk filesystem
	local filename = path.join(cwd, 'package.json')
	if (not fs.existsSync(filename)) then
		filename = path.join(dirname, '..', 'targets', board, 'package.json')
	end

	print('package.json: ' .. filename)

	local filedata = fs.readFileSync(filename)
	local packageInfo = json.parse(filedata)
	if (not packageInfo) then
		print('`package.json` not found or invalid.', filename)
		return false
	end

	packageInfo.version = getMakeVersion()
	packageInfo.type    = type
	packageInfo.board   = getMakeBoard()

	if (not packageInfo.target) then
		packageInfo.target = target
	end

	if (platform == 'win32') then
		sdk.buildWindowSDK(target, packageInfo)
	else
		sdk.buildCommonSDK(target, packageInfo)
	end

	return packageInfo
end

--[[
生成 SDK 包文件，相当于 ZIP 打包。

@param target {String} 构建目标，如 win,linux,pi 等等.
--]]
function sdk.buildSDKPackage(type)
	type = type or 'sdk'

	local target = getMakeTarget()
	local board = getMakeBoard()
	local version = getMakeVersion()
	local pathname  = path.join(cwd, "build", type, target)

	console.log('pathname', pathname)
	os.execute("rm -rf " .. pathname)

	local packageInfo = sdk.buildSDK(target, type, board, version)
	--console.log(target)

	-- build zip file
    local builder = zlib.ZipBuilder:new()
	builder:build(pathname)
	
	os.rename(pathname .. '.zip', pathname .. '-' .. version .. '.zip')

	-- build package info
    print('Builded: "build/sdk/' .. target .. "-" .. version .. '.zip".')
    sdk.buildPackageInfo(target, packageInfo)
end

function sdk.buildTarPackage()
	local target = getMakeTarget()
	local packageInfo = sdk.buildSDK(target)

	-- build tar.gz file
	local name = "nodelua-" .. target .. "-sdk"
    local cmd = "cd build/" .. name .. "; tar -zcvf ../" .. name .. ".tar.gz *"
    os.execute(cmd)

    print('Builded: "build/' .. name .. '.tar.gz".')
end

function sdk.buildDebPackage()
	local target = getMakeTarget()
	local packageInfo = sdk.buildSDK(target)

	local sdk_name = "nodelua-" .. target .. "-sdk"
	local deb_name = "nodelua-" .. target
	local sdk_path  = path.join(cwd, "/build/", sdk_name)
	local deb_path  = path.join(cwd, "/build/", deb_name .. "-deb")

	-- deb files
	fs.mkdirpSync(deb_path .. '/')
	os.execute('rm -rf ' .. deb_path .. '/usr/local/lnode/*')
	os.execute('cp -rf ' .. sdk_path .. '/* ' .. deb_path .. '/usr/local/lnode/')

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
function sdk.buildPackageInfo(target, packageInfo)
	local name 		= "nodelua-" .. target .. "-" .. (packageInfo.type or "sdk")

	local buildPath = path.join(cwd, "/build/")
	local filename  = path.join(buildPath, name .. "." .. process.version .. ".zip")
	local statInfo  = fs.statSync(filename)
	if (not statInfo) then
		return
	end

	local fileData = fs.readFileSync(filename)
	if (not fileData) then
		return
	end

	local fileSize = fileData and #fileData
	local fileHash = util.md5string(fileData)

	local package = packageInfo or {}
	local version = getMakeVersion()

	local registry = package.registry
	if (type(registry) ~= 'table') then
		registry = { url = app.rootURL }
	end

	local username = registry.username or 'cz'
	local password = registry.password or '888888'
	local passhash = util.md5string(username .. ":" .. password)
	registry.username 	= username

	local value = username .. ":" .. passhash .. ":" .. fileHash
	registry.sign 		= util.md5string(value)

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

-------------------------------------------------------------------------------
-- exports

function exports.sdk(...)
	sdk.buildSDKPackage("sdk", ...)
	print(console.colorize("success", 'Finished!'))
end

function exports.patch(...)
	sdk.buildSDKPackage("patch", ...)
	print(console.colorize("success", 'Finished!'))
end

function exports.deb(...)
	sdk.buildDebPackage(...)
	print(console.colorize("success", 'Finished!'))
end

function exports.tar(...)
	sdk.buildTarPackage(...)
	print(console.colorize("success", 'Finished!'))
end

function exports.version()
	local file = io.popen("svn info --xml", "r")
	if nil == file then
		return print("open pipe for svn fail")
	end

	local content = file:read("*a")
	if nil == content then
		return print("read pipe for svn fail")
	end

	local xml = require('onvif/xml')
	local parser = xml.newParser()
	local document = parser:ParseXmlText(content)
	if nil == document then
		return print("parse xml for svn fail")
	end

	local children = document:children();
	local root = children and children[1]
	_, root = xml.xmlToTable(root)

	local entry = root and root.entry
	local commit = entry and entry.commit
	local reversion = commit and commit['@revision']
	if nil == reversion then
		return print("parse reversion for svn fail")
	end

	print('reversion: ' .. reversion)
	if (reversion) then
		local data = 'local exports = { build = ' .. reversion .. '}\nreturn exports\n'
		fs.writeFileSync('core/lua/@version.lua', data)
	end
end

function exports.help()
	print([[

Node.lua SDK and application build tools

usage: lbuild <command> [args]

- help    Display help information
- sdk	  Build Node.lua SDK package (Must `make <target>` firist)

please execute this APP by the Makefile.

]])

	print("Current make target is: " .. getMakeTarget())
	print("")
end

app(exports)
