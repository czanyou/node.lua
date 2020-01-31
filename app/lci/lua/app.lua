local app    = require('app')
local fs     = require("fs")
local path   = require('path')
local util   = require('util')
local rpc    = require('app/rpc')
local log    = require('app/log')

local devices   = require('devices')

local http      = require('./http')
local network   = require("./network")

local exports = {}

local networkManager

-- 网页配置服务
-- @param {string} ...
function exports.http(...)
    print('did: ', app.get('did'))
    http.start(...)
end

-- 在后台监控复位按钮状态
-- - 长按 5 秒后临时复位以太网地址
-- - 长按 10 秒后将恢复到出厂设置并自动重启
-- @param {string} interval
function exports.button(interval)
    -- 在后台检测复位按钮状态
    -- @param {string} interval
    local function checkButtonStatus(interval_ms)
        if (not devices.isSupport()) then
            print('Error: gpio not exists')
            return
        end

        local TIMEOUT_NETWORK_RESET = 5
        local TIMEOUT_SYSTEM_RESET = 10

        local pressTime = 0
        local networkReset = 0
        local systemReset = 0

        -- Reset network settings
        local function onNetworkReset()
            console.log("network reset")
            os.execute('ifconfig eth0 192.168.8.12')

            devices.setLEDStatus('green', 'off')
            devices.setLEDStatus('blue', 'off')
            devices.setLEDStatus('yellow', 'off')
        end

        -- Reset factory settings
        local function onSystemReset()
            console.log("system reset")
            exports.reset()

            setTimeout(1000, function()
                os.reboot()
            end)

            devices.setLEDStatus('green', 'on')
            devices.setLEDStatus('blue', 'on')
            devices.setLEDStatus('yellow', 'on')
        end

        print('start watch reset button state...')

        setInterval(interval_ms, function()
            local state = devices.getButtonState('reset')
            -- console.log('reset button state', state)
            if (state ~= 0) then
                pressTime = 0
                networkReset = 0
                systemReset = 0
                return
            end

            pressTime = pressTime + 1
            print('reset button down', pressTime)

            if (pressTime >= TIMEOUT_SYSTEM_RESET) then
                if (systemReset ~= 1) then
                    systemReset = 1

                    onSystemReset()
                end

            elseif (pressTime >= TIMEOUT_NETWORK_RESET) then
                if (networkReset ~= 1) then
                    networkReset = 1

                    onNetworkReset()
                end
            end
        end)
    end

    checkButtonStatus((interval or 1) * 1000)
end

-- 运行网络配置服务
-- - 在后台监控网络状态
-- - 监控网络配置参数，并在有改动后自动应用新的配置
-- @param {string} interval 检查间隔，默认为 10 秒
function exports.network(interval)
    networkManager = network.getManager()
    if (networkManager) then
        networkManager:start()
    end

    network.checkNetworkStatus((interval or 10) * 1000)
end

-- 激活设备
-- - 必须要输入新的管理密码才能激活设备
-- @param {string} newPassword 要设备的管理密码
function exports.activate(newPassword)
    local nodePath = app.nodePath
    console.log(nodePath)

    -- password
    if (not newPassword) then
        return print('Invalid password')
    end

    newPassword = util.md5string('wot:' .. newPassword)
    os.execute("lpm set password " .. newPassword)
end

-- 恢复出厂设置
-- - 恢复网络设置
-- - 恢复用户设置
function exports.reset()
    -- reset default.conf
    -- TODO: reset
    os.execute('lpm unset default:activate')
    local nodePath = app.nodePath
    console.log('nodePath', nodePath)

    -- reset network.conf
    local filename = path.join(nodePath, 'conf/network.default.conf')
    local destname = path.join(nodePath, 'conf/network.conf')
    os.remove(destname)
    fs.copyfileSync(filename, destname)

    -- reset user.conf
    filename = path.join(nodePath, 'conf/default.conf')
    destname = path.join(nodePath, 'conf/user.conf')
    os.remove(destname)
    fs.copyfileSync(filename, destname)
end

-- 测试
function exports.test(type, ...)
    local test = require('./test')
    test.test(type, ...)
end

-- 执行并监控子服务进程
-- @param {string} name 要执行的执行文件名称
-- @param {string} file 要执行的执行文件完整路径
-- @param {string} params 执行参数列表
local function shellExecute(name, file, params)
    local thread = require('thread')

    thread.start(function(name, file, params)
        local execFile = require('child_process').execFile

        local interval = 1000
        local maxLimit = 1000 * 60
        local startTime = 0
        local child = nil

        local function updateInterval()
            local now = Date.now();
            local span = now - startTime
            if (span > maxLimit) then
                interval = 1000
            else
                interval = math.min(maxLimit, interval * 2)
            end
        end

        local function shell(name, file, params)
            if (params) then
                params = string.split(params, ' ')
            end
            startTime = Date.now()

            -- console.log(name, file, params)
            local options = {}
            child = execFile(file, params or {}, options, function(err, stdout, stderr)
                console.log(name, err, stdout, stderr)
                child = nil
                updateInterval()
            end)

            --[[
            local ret, event, code = os.execute(cmdline)
            if (not ret) and (event == 'signal') and (code == 2) then
                return false
            end
            --]]

            return true
        end

        setInterval(1000, function()
            if (child) then
                return
            end

            local now = Date.now();
            local span = now - startTime
            if (span > interval) then
                os.execute('killall ' .. name)
                shell(name, file, params)
            end
        end)

    end, name, file, params)

    if (not fs.existsSync(file)) then
        return false, "File not found"
    end

    if (not exports.timer) then
        exports.timer = setInterval(5000, function() end)
    end

    return true
end

-- NTP 时间同步客户端
function exports.ntp()
    -- start NTP (Network time protocol) client
    -- (-p) NTP (Time) server is ntp.ubuntu.com
    -- (-n) Run in foreground
    -- /usr/sbin/ntpd
    local name = 'ntpd'
    local file = '/usr/sbin/ntpd'
    local params = '-n -p ntp.ubuntu.com'
    shellExecute(name, file, params)
end

-- DHCP 客户端
function exports.dhcp(ifname)
    -- start DHCP client
    -- (-i) interface is eth0
    -- (-p) pid file is /var/run/udhcpc.pid
    -- (-f) Run in foreground
    -- /sbin/udhcpc
    ifname = ifname or 'eth0'
    local name = 'udhcpc'
    local file = '/sbin/udhcpc'
    local params = '-f -i ' .. ifname .. ' -p /var/run/udhcpc.pid'
    shellExecute(name, file, params)
end

-- 计划任务调度器
function exports.crond()
    -- Start task scheduler
    -- (-f) Run in foreground
    -- /usr/sbin/crond
    local name = 'crond'
    local file = '/usr/sbin/crond'
    local params = '-f'
    shellExecute(name, file, params)
end

-- 硬件看门狗
function exports.watchdog()
    -- (-T) Timeout is 60S
    -- (-t) Feed (reset) interval is 20s
    -- (-F) Run in foreground
    -- /sbin/watchdog
    local name = 'watchdog'
    local params = '-F -T 10 -t 2 /dev/watchdog'
    shellExecute(name, params)
end

-- 设置开关状态
-- @param {string} name
-- @param {string} value
function exports.switch(name, value)
    print('switch <name> <value>:', name, value)
    if (value ~= nil) then
        devices.setSwitchState(name, value)
    elseif (name) then
        print('Current state: ', devices.getGpioState(name))
    else
        print(devices.getSwitchNames())
    end
end

-- 查看网络状态
-- @param {string} name 网口名称
function exports.ifconfig(name)
    local interfaces = os.networkInterfaces() or {}
    if (not name) then
        for ifname, _ in pairs(interfaces) do
            print(ifname)
        end
        return
    end

    local interface = interfaces[name]
    interface = interface and interface[1]
    if (interface) then
        interface.mac = util.hexEncode(interface.mac)
        console.printr(interface)
    else
        print('Device not found')
    end
end

-- 定时重启系统
function exports.restartSystem()
    local function getTime()
        return os.date("*t")
    end

    setInterval(5 * 60 * 1000, function()
        local now = getTime()
        if (now.hour == 15 and now.min >= 55) then
            os.reboot()
        end
    end)
end

-- 创建 RPC 服务，将提供网络等相关的状态查询接口
function exports.rpc()
    local handler = {}
    local name = 'lci'

    handler.network = network.getNetworkStatus
    handler.test = function(handler)
        return  "rpc test"
    end

    local lastSnaphost = nil

    -- 导出所有对象到 /tmp/dump.txt, 用于分析内存泄露
    handler.dump = function()
        local snapshot = require('snapshot')
        local S2 = snapshot()
        if (lastSnaphost) then
            local diff = {}
            for k,v in pairs(S2) do
                if not lastSnaphost[k] then
                    table.insert(diff, v)
                end
            end
            --console.log(diff)

            local data = table.concat(diff, '\r\n')
            fs.writeFile('/tmp/dump.txt', data)
        end

        lastSnaphost = S2
    end

    rpc.server(name, handler, function(event, ...)
        console.log('rpc', event, ...)
    end)
end

-- 查看 rpc 查询接口
function exports.view(type, ...)
    local name = 'lci'
    local params = { ... }
    rpc.call(name, type or 'test', params, function(err, result)
        console.printr(type, err or result or '-')
    end)
end

-- 在系统启动后调用这个接口，完成相关初始化工作
function exports.boot(...)
    local boot = require('./boot')
    boot.onSystemBoot()
end

function exports.config ()
    setInterval(100, function()
        exports.view('network')
    end)
end

function exports.init()
    print([[
This is the config interface for Node.lua.

Usage: lci <command> [args]

where <command> is one of: 
    start test

lci - ]] .. process.version .. [[
]])

end

-- 启动 lci 后台服务
function exports.start(...)
    local function installPppFiles()
        fs.mkdirpSync('/tmp/lock')
        fs.mkdirpSync('/tmp/log')
        fs.mkdirpSync('/tmp/ppp')
        fs.mkdirpSync('/tmp/run')
        fs.mkdirpSync('/tmp/sock')

        -- 安装 pppd 所需要的脚本和配置文件
        local rootPath = app.rootPath
        local cmdline = 'cp -rf ' .. rootPath .. '/app/lci/data/ppp/* /tmp/ppp/'
        os.execute(cmdline)
        os.execute('chmod 777 /tmp/ppp/ip-up')
    end

    if (app.lock()) then
        installPppFiles()

        log.init()
        app.watchProfile()
        exports.button()
        exports.dhcp()
        exports.http(...)
        exports.network()
        exports.ntp()
        exports.restartSystem()
        exports.rpc()
    end
end

app(exports)
