local util 		= require('util')
local path  	= require('path')
local fs  		= require('fs')
local zlib  	= require('zlib')
local json  	= require('json')
local miniz     = require('miniz')

local copy  	= fs.copyfileSync
local cwd		= process.cwd()
local join  	= path.join

-------------------------------------------------------------------------------
-- copy

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
	local board = fs.readFileSync('build/board') or 'local'
	board = board:trim()
	return board
end

local sdk = {}

function sdk.getMakeArch()
	local board = getMakeBoard()
	if (board == "dt02") then
		return "arm"

	elseif (board == "dt02b") then
		return "arm"

	elseif (board == "t31a") then
		return "mips"

	else
		return os.arch()
	end
end

function sdk.getMakePlatform()
	local board = getMakeBoard()
	if (board == "dt02") then
		return "linux"

	elseif (board == "dt02b") then
		return "linux"

	else
		return os.platform()
	end

end

function sdk.getMakeTarget()
	local arch = sdk.getMakeArch()
	local board = getMakeBoard()
	local platform = sdk.getMakePlatform()

	if (board == "local") then
		board = 'lnode'

	elseif (board == "linux") then
		board = 'lnode'

	elseif (board == "darwin") then
		board = 'lnode'

	elseif (board == "windows") then
		board = 'lnode'
	end

	return board .. "-" .. arch .. "-" .. platform
end

function sdk.getMakeVersion()
	local version = process.version
	version = version:trim()
	return version
end

--[[
生成 SDK 目录框架 (如 /bin/nodelua-xxx-sdk/*)

@param target {String} 构建目标，如 win,linux,pi 等等.
--]]
function sdk.getSDKBuildPath(target)
	return join(process.cwd(), "build", "sdk", target)
end

function sdk.buildApp(name, appPath)
	local function getSourcePath()
		local filename = path.join(cwd, 'core/deps/lua')
		if (fs.existsSync(filename)) then
			return cwd
		end

		local sourcePath = util.dirname()
		sourcePath = path.dirname(sourcePath)
		sourcePath = path.dirname(sourcePath)
		sourcePath = path.dirname(sourcePath)
		return sourcePath
	end

	local sourcePath = getSourcePath()
	local pathname = path.join(sourcePath, 'app', name)
	-- print('Source pathname: ' .. pathname);
	if (not fs.existsSync(pathname)) then
		return
	end

	local writer = miniz.createWriter()

	local function loadAppFiles(sourcePath)
		-- console.log('loadAppFiles', sourcePath)

		local function loadSubFiles(package, basePath, subPath)
			-- console.log('loadSubFiles', basePath, subPath)

			local fileList = {}
			local pathName = join(basePath, subPath)
			local files = fs.readdirSync(pathName) or {}
			for _, file in ipairs(files) do
				if (file:sub(1, 1) == ".") then
					goto continue;
				end

				local stat = fs.statSync(join(pathName, file))
				if (not stat) then
					-- console.log(pathName, file)
					goto continue;
				end

				-- console.log(basePath, subPath, file)

				if (stat.type == 'file') then
					local filedata = fs.readFileSync(pathName .. '/' .. file)
					if (subPath) then
						local packageName = path.join(package, subPath, file)
						writer:add(packageName, filedata, 9)
						--console.log('packageName', packageName)

					else
						local packageName = path.join(package, file)
						writer:add(packageName, filedata, 9)
						--console.log('packageName', packageName)
					end
					
					table.insert(fileList, util.md5string(filedata) .. '@' .. file)

				elseif (stat.type == 'directory') then

					if (subPath) then
						file = path.join(subPath, file)
					end

					local hashdata = loadSubFiles(package, basePath, file)
					table.insert(fileList, hashdata .. '@' .. file)
				end

				::continue::
			end

			fileList = table.concat(fileList, ';')
			-- console.log('fileList', basePath, subPath, fileList)

			return util.md5string(fileList)
		end

		-- modules
		local fileList = {}
		local files = fs.readdirSync(sourcePath) or {}
		for _, file in ipairs(files) do
			-- console.log(file)
			if (file:sub(1, 1) == ".") then
				goto continue

			elseif (file == 'tests') then
				goto continue
			end

			local stat = fs.statSync(join(sourcePath, file))
			if (not stat) then
				goto continue
			end

			-- print('file', file)
			if (stat.type == 'directory') then
				local basePath = path.join(sourcePath, file)
				local hashdata = loadSubFiles(file, basePath)
				table.insert(fileList, hashdata .. '@' .. file)

			elseif (stat.type == 'file') then
				local filedata = fs.readFileSync(sourcePath .. '/' .. file)
				writer:add(file, filedata, 9)

				table.insert(fileList, util.md5string(filedata) .. '@' .. file)
			end

			::continue::
		end

		fileList = table.concat(fileList, ';')
		--console.log('fileList', sourcePath, fileList)
		--console.log('hashdata', util.md5string(fileList))
	end

	loadAppFiles(pathname)

	local fileData = writer:finalize()
	writer:close()

	-- console.log('appPath', appPath)
	local filename = appPath .. '.zip'
	fs.writeFileSync(filename, fileData)
	return name
end

function sdk.buildCommonSDK(target, packageInfo)

	local function getSourcePath()
		local filename = path.join(cwd, 'core/deps/lua')
		if (fs.existsSync(filename)) then
			return cwd
		end

		local sourcePath = util.dirname()
		sourcePath = path.dirname(sourcePath)
		sourcePath = path.dirname(sourcePath)
		sourcePath = path.dirname(sourcePath)
		return sourcePath
	end

    local function copyModuelFiles(nodePath, buildPath)
        local libs = packageInfo.libs or {}
        -- console.log(libs)
        for _, file in ipairs(libs) do
			local destFile = join(nodePath, 'lib', file)
			if (fs.existsSync(destFile)) then
				print('Add module:', file)
				copy(join(buildPath,  file), destFile)
			end
        end

        -- copy modules lua files
        --[[ libs

        local visionPath = join(sourcePath, "modules")
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
        --]]
    end

    local function copyCoreFiles(nodePath, buildPath)
		copy(buildPath .. "/lnode", join(nodePath, "bin/lnode"))

        -- copy node lua files
        -- local nodeluaPath = join(sourcePath, "core")
        -- xcopy(nodeluaPath .. "/lua", 	 nodePath .. "/lua")
    end

    local function copyApplications(nodePath, sourcePath)
        local applications = packageInfo.applications
        if (not applications) then
            return
        end

		local names = {}
		for i = 1, #applications do
			local name = applications[i]
			local appPath = join(sourcePath, 'app', name)
			--console.log(appPath)

			if (fs.existsSync(appPath)) then
				local pathName = join(nodePath, "app", name)
				if (sdk.buildApp(name, pathName)) then
					table.insert(names, name)
				end
				--xcopy(appPath, pathName)
				--os.execute('rm -rf ' .. pathName .. '/tests/')
			else
				console.log('APP', name, 'does not exists!');
			end
		end

		copy(sourcePath .. "/app/lci/data/default.script", join(nodePath, "bin/udhcpc.script"))
		print('Applcations:    ' .. table.concat(names, ', '))
	end

	local sourcePath = getSourcePath()
	-- print('Source path:', sourcePath);

	local nodePath  = sdk.getSDKBuildPath(target)

	local mkdir = fs.mkdirpSync
	mkdir(join(nodePath, "app"))
	mkdir(join(nodePath, "lib"))
	mkdir(join(nodePath, "lua"))
    mkdir(join(nodePath, "bin"))

    local board = getMakeBoard()
    local buildPath  = join(sourcePath, "build", board)

    copyModuelFiles(nodePath, buildPath)
    copyCoreFiles(nodePath, buildPath)
    copyApplications(nodePath, sourcePath)

	-- update package.json
	local packageText = json.stringify(packageInfo)
	fs.writeFileSync(join(nodePath, "package.json"), packageText)
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
		local pathName = join(sdkPath , "lnode/app", file)
		xcopy(join(cwd, "app", file), pathName)
		os.execute('rm -rf ' .. pathName .. '/tests/')
	end

	-- package.json
	packageInfo.files = nil
	fs.writeFileSync(sdkPath .. "/lnode/package.json", json.stringify(packageInfo))
	fs.writeFileSync(sdkPath .. "/package.json", json.stringify(packageInfo))
end

-------------------------------------------------------------------------------
-- build

-- 生成 SDK 包文件，相当于 ZIP 打包。
---@param type string 构建类型
function sdk.buildPackage(type)
	type = type or 'sdk'

	local target = sdk.getMakeTarget()
	local version = sdk.getMakeVersion()
	local pathname = path.join(cwd, "build", type, target)

	print('SDK path:', pathname)
	os.execute("rm -rf " .. pathname)

	local packageInfo = sdk.loadPackageInfo(target)
	--console.log(target)

	local platform = os.platform()
	if (platform == 'win32') then
		sdk.buildWindowSDK(target, packageInfo)
	else
		sdk.buildCommonSDK(target, packageInfo)
	end

	-- build zip file
    local builder = zlib.ZipBuilder:new()
	builder:build(pathname)

	os.rename(pathname .. '.zip', pathname .. '-' .. version .. '.bin')

	-- build package info
	print('--')
    print('-- SDK building done: ' .. 'build/sdk/' .. target .. "-" .. version .. '.bin')
    sdk.buildPackageInfo(target, packageInfo)
end

-- 生成 SDK 包文件描述文件, 包含SDK 包长度，版本，创建日期等信息。
-- 将生成和 SDK 包同名，但扩展名为 json 的文本文件。
---@param target string 构建目标，如 win,linux,pi 等等.
---@param packageInfo table
function sdk.buildPackageInfo(target, packageInfo)
    local version   = sdk.getMakeVersion()
	local name 		= target .. "-" .. version

	local buildPath = path.join(cwd, "/build/sdk/")
	local filename  = path.join(buildPath, name .. ".bin")
	local statInfo  = fs.statSync(filename)
    if (not statInfo) then
        print('File not found:', filename)
		return
	end

	local fileData = fs.readFileSync(filename)
    if (not fileData) then
        print('File is empty:', filename)
		return
	end

	local fileSize = fileData and #fileData
	local fileHash = util.md5string(fileData)

	local package = packageInfo or {}

	package.arch 	 = sdk.getMakeArch()
	package.build    = os.date("%Y-%m-%dT%H:%M:%S")
	package.md5sum   = fileHash
	package.mtime    = statInfo.mtime.sec
	package.platform = sdk.getMakePlatform()
	package.registry = nil
	package.size 	 = fileSize
	package.target 	 = package.arch .. '-' .. package.platform
	package.version  = version

	filename = path.join(buildPath, name .. ".json")
	fs.writeFileSync(filename, json.stringify(package))

    -- print('Build SDK info:', 'build/' .. name .. '.json".')
end

-- 生成 SDK 目录
---@param target string 构建目标，如 win,linux,pi 等等.
---@return table
function sdk.loadPackageInfo(target)
	local board = getMakeBoard()
	if (board == 'local') then
		board = os.platform()
	end

	--console.log(util.dirname())
	local dirname = util.dirname()

	-- build sdk filesystem
	local filename = path.join(cwd, 'package.json')
	if (not fs.existsSync(filename)) then
		filename = path.join(dirname, '..', 'targets', board, 'package.json')
	end

	print('Package info: ', filename)

	local filedata = fs.readFileSync(filename)
	local packageInfo = json.parse(filedata)
	if (not packageInfo) then
		print('`package.json` not found or invalid.', filename)
		return false
	end

	packageInfo.version = sdk.getMakeVersion()
	packageInfo.board   = getMakeBoard()

	if (not packageInfo.target) then
		packageInfo.target = target
	end

	return packageInfo
end

return sdk
