local app    = require('app')
local path   = require('path')
local util   = require('util')
local rpc    = require('app/rpc')
local log    = require('app/log')
local devices = require('devices')

local services  = require('./services')
local network   = require('./network')
local boot      = require('./boot')

local exports = {}

local _executeApplication = function (name, action, ...)
	--print(name, action, ...)
	if (not name) then
		print("Error: missing required argument '<name>'.")
		print("")
		return
	end

	local basePath = path.join(os.tmpdir, 'app', name)
	local ret, err = app.load(basePath, action, ...)
	if (not ret) or (ret < 0) then
		print("Error: unknown command or application: '" .. tostring(basePath) .. "'")
		print("")
	end
end

-- 激活设备
-- - 必须要输入新的管理密码才能激活设备
-- @param {string} newPassword 要设备的管理密码
function exports.activate(newPassword)
    print('Usage: lci activate <password>', '\n')

    if (not newPassword) then
        return print('Invalid password: password is empty')
    end

    newPassword = util.md5string('wot:' .. newPassword)
    os.execute("lpm set password " .. newPassword)
end

-- 在系统启动后调用这个接口，完成相关初始化工作
function exports.boot(...)
    boot.start()
end

function exports.call(command, ...)
	local func = exports[command or 'init']
	if (type(func) == 'function') then
		local status, ret = pcall(func, ...)
		runLoop()

		if (not status) then
			print(ret)
		end

		return ret

	else
		_executeApplication(command, ...)
	end
end

function exports.board(...)
    boot.update(...)
end

function exports.get(...)

end

function exports.info()
    local function printInfo(name, value)
		print(console.colorful('${braces}' .. name .. '      ${normal}') .. tostring(value))
    end

    local deviceInfo = devices.getDeviceInfo()

    --console.log(devices)

    local device = devices.getDeviceProperties()
    print(console.colorful('${string}device:${normal}'))
    printInfo('serialNumber   ', device.serialNumber)
    printInfo('deviceType     ', device.deviceType)
    printInfo('firmwareVersion', device.firmwareVersion)
    printInfo('hardwareVersion', device.hardwareVersion)
    printInfo('manufacturer   ', device.manufacturer)
    printInfo('memoryTotal    ', device.memoryTotal)
    printInfo('modelNumber    ', device.modelNumber)

    printInfo('Arch           ', deviceInfo.arch)
    printInfo('UDN            ', deviceInfo.udn)

    local macAddress = devices.getMacAddress()
    printInfo('MAC            ', macAddress)

    console.log(devices.getSystemInfo())

    local networkStatus = network.getNetworkStatus()
    if (networkStatus.lan) then
        local lan = networkStatus.lan
        console.log(lan)
    end

    if (networkStatus.wan) then
        local wan = networkStatus.wan
        console.log(wan)
    end
end

function exports.init()
    exports.usage()
end

function exports.post(...)

end

function exports.password(username, password)
    if (not password) then
        return print('usage: lci password <username> <password>')
    end

    local hash = util.md5string('wot:' .. password)
    print('password: ' .. hash)
end

function exports.service(name, ...)
    local method = services[name]
    if (method) then
        method(...)
    else
        local names = util.keys(services)
        table.sort(names)
        print('Usage: lci service <command> [args]')
        print('  where <command> is one of:')
        print(table.concat(names, ', '))
    end
end

-- 恢复出厂设置
-- - 恢复网络设置
-- - 恢复用户设置
---@param action string
function exports.reset(action)
    services.reset(action)
end

-- 启动 lci 后台服务
function exports.start(...)
    if (not app.lock()) then
        return
    end

    print('Usage: lci start <http port>\n')

    local uname = os.uname()
    local machine = uname and uname.machine

    log.init()
    app.watchProfile()

    -- start http and rpc server
    services.http(...)
    services.rpc()

    -- start all timers
    print('machine: ' .. tostring(machine))
    if (machine == 'armv5tejl') or (machine == 'mips') then
        services.button()
        services.dhcp()
        services.network()
        services.ntp()
        services.schedule()
    end
end

-- 设置开关状态
---@param type string
---@param value string
function exports.switch(type, value)
    print('Usage: lci switch <name> <value>\n')
    local name = devices.getGpioName(type) or type

    if (name) then
        if (value ~= nil) then
            devices.setSwitchState(name, value)
        else
            print('Current state: ', devices.getGpioState(name))
        end

    else
        print('Names: ' .. table.concat(devices.getSwitchNames(), ', '))
    end
end

-- 测试
function exports.test(type, ...)
    local test = require('./test')
    test.test(type, ...)

    -- console.log(tonumber('1\n'), tonumber(''), tonumber('1a'), not nil, not '', not 0, '0' == 0)
end

function exports.usage()
    local names = util.keys(exports)
    table.sort(names)

    print([[
This is the config interface for Node.lua.

Usage: lci <command> [args]

  where <command> is one of: 

]] .. table.concat(names, ', ') .. [[


lci - ]] .. process.version .. [[
]])

end

-- 查看 rpc 查询接口
function exports.view(name, ...)
    if (not name) then
        print('Usage: lci view <name> [params...]')
        return
    end

    local params = { ... }
    rpc.call('lci', name, params, function(err, result)
        console.printr(name, err or result or '-')
    end)
end

app(exports)
