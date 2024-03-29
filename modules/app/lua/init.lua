--[[

Copyright 2016-2020 The Node.lua Authors. All Rights Reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS-IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

--]]

local meta = {}
meta.description = "Application module for lnode"

local fs     	= require('fs')
local json   	= require('json')
local path   	= require('path')
local util      = require('util')
local miniz     = require('miniz')
local conf      = require('app/conf')
local process   = require('process')
local uv        = require('luv')

local exec  = require('child_process').exec

local exports = { meta = meta }

-------------------------------------------------------------------------------
-- misc

local function getRootPath()
    if (exports.rootPath) then
        return exports.rootPath
    end

    exports.rootPath = "/usr/local/lnode"
    if (process.rootPath) then
        exports.rootPath = process.rootPath
    end

    local osType = os.platform()
    if (osType == 'win32') then
        local pathname = path.dirname(process.execPath)
        exports.rootPath = path.dirname(pathname)
    end

	return exports.rootPath
end

local function getNodePath()
    if (exports.nodePath) then
        return exports.nodePath
    end

    exports.nodePath = "/usr/local/lnode"

    local osType = os.platform()
    if (osType == 'win32') then
        local pathname = path.dirname(process.execPath)
        exports.nodePath = path.dirname(pathname)

    else
        if (process.nodePath) then
            exports.nodePath = process.nodePath
        end
    end

	return exports.nodePath
end

local function getAppPath()
	local rootPath = getRootPath()
	local appPath = path.join(rootPath, "app")
	if (not fs.existsSync(appPath)) then
		appPath = path.join(path.dirname(rootPath), "app")
	end

	return appPath
end

local function getApplicationInfo(basePath)
	local filename = path.join(basePath, "package.json")
    local data = fs.readFileSync(filename)
    if (not data) then
        local reader = miniz.createReader(basePath)
        if (reader) then
            data = reader:readFile('package.json')
            reader:close()
            reader = nil
        end
    end

	return data and json.parse(data)
end

-- 通过 cmdline 解析出相关的应用的名称
local function getApplicationName(cmdline)
	if (type(cmdline) ~= 'string') then
		return
    end

    -- /xxx/lua/app.lua
    local _, _, appName = cmdline:find('/([%w]+)/lua/app.lua')
    -- console.log(cmdline, appName)

    if (not appName) then
        -- lpm xxx start
        _, _, appName = cmdline:find('/lpm%S([%w]+)%Sstart')
    end

    if (not appName) then
        -- lpm start xxx
        _, _, appName = cmdline:find('/lpm%Sstart%S([%w]+)')
    end

    if (not appName) then
        -- $wotc/lua/app.lua
        _, _, appName = cmdline:find('$([%w]+)/lua/app.lua')
    end

    -- console.log('appName', appName, cmdline)
    return appName
end

local function executeApplication(basePath, ...)
	local filename = basePath .. '.zip'
    if (fs.existsSync(filename)) then
        local appname = path.basename(basePath)
        local script = package.loadZipFile(filename, appname, 'app')

        _G.arg = table.pack(...)
        return 0, script(...)
	end

	filename = path.join(basePath, "lua", "app.lua")
	if (not fs.existsSync(filename)) then
		return -3, '"' .. basePath .. '/lua/app.lua" not exists!'
	end

    --console.log(package.path)

	local script, err = loadfile(filename)
	if (err) then
		error(err)
		return -4, err
	end

	_G.arg = table.pack(...)
	return 0, script(...)
end

-- 显示错误信息
local function printError(errorInfo, ...)
	print('Error:', console.color("err"), tostring(errorInfo), console.color(), ...)

end

-------------------------------------------------------------------------------
-- exports

exports.meta  = {}
setmetatable(exports, exports.meta)

--
exports.rootPath 		= getRootPath()
exports.nodePath 		= getNodePath()
exports.rootURL 		= 'http://iot.wotcloud.cn/v2/'
exports.appPath 		= getAppPath()

-------------------------------------------------------------------------------
-- profile

local function getDefaultProfile()
    if (exports._defaultProfile) then
        return exports._defaultProfile
    end

    exports._defaultProfile = conf('default')
    return exports._defaultProfile
end

local function getUserProfile(reload)
    if (exports._userProfile) and (not reload) then
        return exports._userProfile
    end

    exports._userProfile = conf('user')
    return exports._userProfile
end

function exports.appName()
	return exports.name or 'user'
end

-- 开始监控 Profile 改变
function exports.watchProfile(callback)
    -- load a profile first
    local updated = exports.get('updated')
    print('Start watch profile: ' .. exports.appName())

    local profile = exports._defaultProfile
    if (profile) then
        profile:startWatch(callback)
    end

    profile = exports._userProfile
    if (profile) then
        profile:startWatch(callback)
    end

    return updated
end

-- 重新加载 Profile 改变
function exports.reloadProfile()
    local profile = exports._defaultProfile
    if (profile) then
        profile:reload()
    end

    profile = exports._userProfile
    if (profile) then
        profile:reload()
    end
end

-- 删除指定名称的配置参数项的值
-- @param key {String}
function exports.unset(key)
    if (not key) then
        return
    end

	local profile = getUserProfile(true)
	if (profile) and (profile:set(key, nil)) then
		profile:commit()
	end
end

-- 打印指定名称的配置参数项的值
-- @param key {String}
function exports.get(key)
	if (not key) then
        return
    end

    local profile = getUserProfile()
    local value = profile and profile:get(key)
    if (value ~= nil) then
        return value
    end

	profile = getDefaultProfile()
    if (profile) then
		return profile:get(key)
	end
end

-- 设置指定名称的配置参数项的值
-- @param key {String|Object}
-- @param value {String|Number|Boolean}
function exports.set(key, value)
	if (not key) then
		return
	end

	local profile = getUserProfile(true)
    if (not profile) then
        return
    end

    if (type(key) == 'table') then
        local count = 0
        for k, v in pairs(key) do
            local oldValue = profile:get(k)
            --print(k, v, oldValue)

            if (not oldValue) or (v ~= oldValue) then
                profile:set(k, v)

                count = count + 1
            end
        end

        if (count > 0) then
            profile:commit()
        end

    else
        if (not key) or (not value) then
            return
        end

        local oldValue = profile:get(key)
        if (not oldValue) or (value ~= oldValue) then
            profile:set(key, value)
            profile:commit()
        end
    end
end

-------------------------------------------------------------------------------
-- methods

-- 更新应用进程管理列表
local function updateProcessList(add, remove)
    local configPath = path.join(getNodePath(), 'conf/process.conf')
    local fileData = fs.readFileSync(configPath) or ''
    local tokens = fileData:split(',') or {}
    local set = {}
    for _,name in ipairs(tokens) do
        if (#name > 0) then
            set[name] = 1
        end
    end

    if (add) then
        set[add] = 1
    end

    if (remove) then
        set[remove] = 0
    end

    local list = {}
    for key,value in pairs(set) do
        if (value == 1) then
            list[#list + 1] = key
        end
    end

    table.sort(list)
    local newData = table.concat(list, ',')
    if (newData == fileData) then
        return
    end

    local ret, error = fs.writeFileSync(configPath, newData)
    if (error) then
        console.log(error)
    end
end

-- 以后台的方式运行指定的应用
function exports.daemon(name)
	if (not name) or (name == '') then
        return -1, "Error: missing required argument '<name>'."
    end

    local appPath = getAppPath()
    local tempPath = path.join(os.tmpdir, 'app')

    local filename = path.join(tempPath, name, 'lua', 'app.lua')
    if (not fs.existsSync(filename)) then
        -- console.log(filename)
        filename = path.join(appPath, name, 'lua', 'app.lua')
        if (not fs.existsSync(filename)) then
            filename = path.join(appPath, name .. '.zip')
            if (not fs.existsSync(filename)) then
                return -3, '"' .. filename .. '" not exists!'
            end
        end
    end

    updateProcessList(name)

    local action = 'start'
    if (name == 'lpm') then
        action = 'run'
    end

    local cmdline  = "lnode -d " .. filename .. " " .. action
    local options = {
        timeout = 1000,
        env = process.env
    }

    exec(cmdline, options, function(err, stdout, stderr)
        if (err) then
            console.log(err, stdout, stderr)
        end
    end)

    return 0
end

-- 执行指定名称的应用
function exports.execute(name, ...)
	local basePath
	if (not name) then
		basePath = process.cwd()
	else
		basePath = path.join(getAppPath(), name)
	end

	return executeApplication(basePath, ...)
end

function exports.load(basePath, ...)
    -- console.log('basePath', basePath)
    return executeApplication(basePath, ...)
end

-- 返回指定名称的应用的信息
function exports.info(name)
	local filename = path.join(getAppPath(), name)
	return getApplicationInfo(filename)
end

-- kill 指定名称的进程
function exports.kill(name)
    if (not name) then
        return nil, 'missing required argument `name`!\n'
    end

    local list = exports.processes()
    if (not list) or (#list < 1) then
        return nil, 'process list is empty'
    end

    local ppid = process.pid

    if (name == 'all') then
        local result = {}
        for _, proc in ipairs(list) do
            if (ppid ~= proc.pid) then
                local ret, err = uv.kill(proc.pid, "sigterm")
                result[proc.name] = { ret = ret, error = err, pid = proc.pid }
            end
        end

        return result

    else
        local ret, err, pid
        for _, proc in ipairs(list) do
            if (proc.name == name) and (ppid ~= proc.pid) then
                ret, err = uv.kill(proc.pid, "sigterm")
                pid = proc.pid
            end
        end

        return ret, err, pid
    end
end

-- 返回包含所有安装的应用的列表
function exports.list()
	local appPath = getAppPath()
	local list = {}

	local files = fs.readdirSync(appPath)
	if (not files) then
		return list
	end

	for i = 1, #files do
		local file 		= files[i]
		local filename  = path.join(appPath, file)
		local name 		= path.basename(file, ".zip")
		local info 		= getApplicationInfo(filename)
		if (info) then
			info.name = name or info.name
			list[#list + 1] = info
		end
	end

	return list
end

function exports.main(handler, action, ...)
    -- console.log('main', action, ...)
    local method = handler[action or 'init']

    exports.name = getApplicationName(util.filename(4))
    -- console.log('method', action, method, exports.name, util.filename(4))

    if (method) then
        return method(...)
    end

    if (handler.call) then
        return handler.call(action, ...)
    end

    if (handler.help) then
        return handler.help(action, ...)
    end

    print('usage: lpm ' .. (exports.name or '<applet>') .. ' <name> [<params>...]')
end

-- 打印所有安装的应用
function exports.printList()
	local appPath = path.join(getAppPath())

	local apps = exports.list()
	if (not apps) or (#apps <= 0) then
		print("No applications are installed yet.", appPath)
		return
	end

    print(util.formatTable(apps, {'name', 'version', 'description'}))
    
    print(string.format("+ total %s applications (%s).",
        #apps, appPath))
end

-- 通过 cmdline 解析出相关的应用的名称
function exports.parseName(cmdline)
    -- lnode -d path/to/app/xxx/lua/app.lua
    local _, _, appName = cmdline:find('app/([%w]+)/lua/app.lua')

    if (not appName) then
        -- lnode -d path/to/app/xxx.zip
        _, _, appName = cmdline:find('app/([%w]+).zip')
    end

    return appName
end

-- 返回包含所有正在运行中的应用进程信息的数组
-- @return {Array} 返回 [{ name = '...', pid = ... }, ... ]
function exports.processes2()
    local list = {}
    local count = 0

    local files = fs.readdirSync('/proc') or {}
    if (not files) or (#files <= 0) then
        print('This command only support Linux!')
        return
    end

    local execPath = process.execPath
    --console.log(exepath)

    for _, file in ipairs(files) do
        local pid = tonumber(file)
        if (not pid) then
            goto continue
        end

        local filename = path.join('/proc', file, 'exe')
        local pathname = fs.readlinkSync(filename)
        if (not pathname) then
            --

        elseif (pathname ~= execPath) then
            goto continue
        end

        local filename = path.join('/proc', file, 'cmdline')
        if not fs.existsSync(filename) then
            goto continue
        end

        local cmdline, err = fs.readFileSync(filename) or ''
        console.log(filename, cmdline, err)
        --console.log(pathname)

        local name = exports.parseName(cmdline)
        if (not name) then
            goto continue
        end

        table.insert(list, {name = name, pid = pid})
        count = count + 1

        ::continue::
    end

    return list, count
end

function exports.processes()
    local list = {}
    local count = 0

    local file = io.popen("ps -o pid,args -A", "r")
	if nil == file then
		return print("open pipe for ps fail")
	end

	local content = file:read("*a")
	if nil == content then
		return print("read pipe for ps fail")
	end

    local lines = string.split(content, '\n')

    for _, line in ipairs(lines) do
        line = string.trim(line)
        local tokens = string.split(line, ' ')

        if (tokens[2] ~= 'lnode') then
            goto continue
        end

        local pid = tonumber(tokens[1])
        if (not pid) then
            goto continue
        end

        local name = exports.parseName(tokens[4])
        if (not name) then
            goto continue
        end

        table.insert(list, { name = name, pid = pid })
        count = count + 1

        ::continue::
    end

    return list, count
end

-- 打印所有正在运行中的进程
function exports.printProcesses(...)
    local processes = exports.processes()

    -- process list
    local services = {}
    if (processes) and (#processes > 0) then
        for _, proc in ipairs(processes) do
            local service = services[proc.name]
            if (not service) then
                service = { name = proc.name }
                services[proc.name] = service
            end

            if (not service.pids) then
                service.pids = {}
            end

            service.pids[#service.pids + 1] = tostring(proc.pid)
        end
    end

    -- process list
    local configPath = path.join(getNodePath(), 'conf/process.conf')
    local fileData = fs.readFileSync(configPath) or ''
    local tokens = fileData:split(',') or {}
    for _, name in ipairs(tokens) do
        if (#name > 0) then
            local service = services[name]
            if (not service) then
                service = { name = name }
                services[name] = service
            end

            service.isEnable = 1
        end
    end

    -- process list
    local list = {}
    for name, service in pairs(services) do
        if (name ~= '') then
            list[#list + 1] = service
        end
    end

    if (not list) or (#list < 1) then
        return print('No matching application process were found!')
    end

    table.sort(list, function(a, b)
        return tostring(a.name) < tostring(b.name)
    end)

    local rows = {}
    for _, proc in ipairs(list) do
        local pids = proc.pids or { '-' }
        table.insert(rows, {
            name = proc.name,
            pid = table.concat(pids, ","),
            enable = proc.isEnable and 'Y' or '-'
        })
    end

    print(util.formatTable(rows, {"name", "pid", 'enable'}))
end

-- 重启指定的名称的应用程序
function exports.restart(name, ...)
    if (not name) then
        return nil, 'missing required argument `name`!\n'

    elseif (name == 'all') then
        exports.kill('all')
        return exports.start('all')

    else
        return exports.start(name, ...)
    end
end

-- Start and deamonize specified application
function exports.start(name, ...)
    if (not name) then
        return nil, 'missing required argument `name`!\n'
    end

    local list = table.pack(name, ...)

    for _, app in ipairs(list) do
        exports.kill(app)
    end

    local result = {}
    for _, app in ipairs(list) do
        local ret, err = exports.daemon(app)
        result[app] = { ret = ret, error = err }
    end

    return result
end

-- 杀掉指定名称的进程，并阻止其在后台继续运行
function exports.stop(name, ...)
    if (not name) then
        return nil, 'missing required argument `name`!\n'
    end

    local list = table.pack(name, ...)
    if (name == 'all') then
        return exports.kill('all')
    end

    local result = {}
    for _, app in ipairs(list) do
        updateProcessList(nil, app)
        local ret, err, pid = exports.kill(app)
        result[app] = { ret = ret, error = err, pid = pid }
    end

    return result
end

-- 返回当前系统目标平台名称, 一般是开发板的型号或 PC 操作系统的名称
-- 因为不同平台的可执行二进制文件格式是不一样的, 所有必须严格匹配
function exports.getSystemTarget()
    local platform = os.platform()
    local arch = os.arch()

    local target = (arch .. "-" .. platform)
    target = target:trim()
    return target
end

-- 检查是否有另一个进程正在更新系统
function exports.lock(name)
    local lockdir = os.tmpdir or '/tmp'
    if fs.existsSync('/var/lock/') then
        lockdir = '/var/lock/'
    end

    local appName = name or exports.appName()
    -- console.log('appName', appName)

	local lockname = path.join(lockdir, '/app_' .. appName .. '.lock')
    local lockfd, err = fs.openSync(lockname, 'w+')
    if (lockfd == nil) then
        print("Error: ", err)
        return nil
    end

	local ret = fs.fileLock(lockfd, 'w')
    if (ret == -1) then
        fs.close(lockfd)
		print('Error: The ' .. appName .. ' app already locked!')
		return nil
    end

	return lockfd
end

-- 释放文件锁
function exports.unlock(lockfd)
    if (lockfd) then
        fs.fileLock(lockfd, 'u')
        fs.close(lockfd)
    end
end

function exports.open(filename)
    local appname = path.basename(filename, '.zip')
	local script, reader = package.loadZipFile(filename, appname, 'app')
    if (script) then
        exports.bundle = reader
        script()
    end
end

exports.meta.__call = function(self, handler)
    exports.main(handler, table.unpack(arg))
end

return exports
