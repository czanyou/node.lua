local app    = require('app')
local fs     = require('fs')
local path   = require('path')
local rpc    = require('app/rpc')
local util   = require('util')
local devices   = require('devices')

local http      = require('./http')
local network   = require('./network')

local services = {}

-- 执行并监控子服务进程
-- @param {string} name 要执行的执行文件名称
-- @param {string} file 要执行的执行文件完整路径
-- @param {string} params 执行参数列表
local function shellExecute(name, file, params)
    if (not fs.existsSync(file)) then
        console.info("Execute file not found:", file)
        return false, "Execute file not found"
    end

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

    if (not services.shellTimer) then
        services.shellTimer = setInterval(5000, function() end)
    end

    return true
end

-- 在后台监控复位按钮状态
-- - 长按 5 秒后临时复位以太网地址
-- - 长按 10 秒后将恢复到出厂设置并自动重启
---@param interval integer
function services.button(interval)

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
        services.reset('all')

        setTimeout(1000, function()
            os.reboot()
        end)

        devices.setLEDStatus('green', 'on')
        devices.setLEDStatus('blue', 'on')
        devices.setLEDStatus('yellow', 'on')
    end

    -- 在后台检测复位按钮状态
    ---@param interval integer
    local function checkButtonStatus(interval)
        local TIMEOUT_NETWORK_RESET = 5
        local TIMEOUT_SYSTEM_RESET = 10

        local pressTime = 0
        local networkReset = 0
        local systemReset = 0

        setInterval(interval, function()
            local state = devices.getButtonState('reset')
            -- console.log('reset button state', state)
            if (state ~= 0) then
                pressTime = 0
                networkReset = 0
                systemReset = 0
                return
            end

            print('reset button: ' .. tostring(state))

            pressTime = pressTime + 1
            print('The reset button is pressed', pressTime)

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

    if (not devices.isSupport()) then
        print('Error: Current device not support reset button I/O device')
        return
    end

    print('Start watch reset button...')

    interval = (tonumber(interval) or 1) * 1000
    checkButtonStatus(interval)
end

-- 计划任务调度器
function services.crond()
    print('Start crond service')

    -- Start task scheduler
    -- (-f) Run in foreground
    -- /usr/sbin/crond
    local name = 'crond'
    local file = '/usr/sbin/crond'
    local params = '-f'
    shellExecute(name, file, params)
end

-- DHCP 客户端
function services.dhcp(ifname)
    print('Start DHCP client...')

    local script =  path.join(app.nodePath, 'bin/udhcpc.script')

    -- start DHCP client
    -- (-i) ifname is eth0
    -- (-p) pid file is /var/run/udhcpc.pid
    -- (-f) Run in foreground
    -- /sbin/udhcpc
    ifname = ifname or 'eth0'
    local name = 'udhcpc'
    local file = '/sbin/udhcpc'
    local params = '-f -i ' .. ifname .. ' -p /var/run/udhcpc.pid -s ' .. script
    shellExecute(name, file, params)
end

-- 网页配置服务
-- @param {string} ...
function services.http(...)
    http.start(...)
end

-- 运行网络配置服务
-- - 在后台监控网络状态
-- - 监控网络配置参数，并在有改动后自动应用新的配置
-- @param {string} interval 检查间隔，默认为 10 秒
function services.network(interval)
    network.start(interval)
end

-- NTP 时间同步客户端
function services.ntp()
    print('Start NTP client...')

    -- start NTP (Network time protocol) client
    -- (-p) NTP (Time) server is ntp.ubuntu.com, cn.ntp.org.cn, ntp1.aliyun.com
    -- (-n) Run in foreground
    -- /usr/sbin/ntpd
    local name = 'ntpd'
    local file = '/usr/sbin/ntpd'
    local params = '-n -p ntp1.aliyun.com'
    shellExecute(name, file, params)
end

-- 创建 RPC 服务，将提供网络等相关的状态查询接口
function services.rpc()
    local handler = {}
    local name = 'lci'

    handler.network = network.getNetworkStatus
    handler.status = network.getNetworkStatus
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

    print('Start RPC server: ' .. table.concat(util.keys(handler), ', '))
    rpc.server(name, handler, function(event, ...)
        console.log('rpc', event, ...)
    end)
end

-- 恢复出厂设置
-- - 恢复网络设置
-- - 恢复用户设置
---@param action string
function services.reset(action)
    if (not action) then
        return print('Usage: lci reset all|default|network|user')
    end

    local nodePath = app.nodePath
    print('Node Path: ' .. nodePath)

    -- reset default.conf
    if (action == 'all') or (action == 'default') then
        print('Reset default setting...')
        os.execute('lpm unset default:activate')
    end

    -- reset network.conf
    if (action == 'all') or (action == 'network') then
        print('Reset network setting...')
        local filename = path.join(nodePath, 'conf/network.default.conf')
        local destname = path.join(nodePath, 'conf/network.conf')
        os.remove(destname)
        fs.copyfileSync(filename, destname)
    end

    -- reset user.conf
    if (action == 'all') or (action == 'user') then
        print('Reset user setting...')
        local filename = path.join(nodePath, 'conf/default.conf')
        local destname = path.join(nodePath, 'conf/user.conf')
        os.remove(destname)
        fs.copyfileSync(filename, destname)
    end
end

-- 计划定时重启系统
function services.schedule()
    print('Schedule a task to reboot periodically...')

    local interval = 5 * 60
    setInterval(interval * 1000, function()
        local now = os.date("*t")
        local uptime = math.floor(os.uptime())
        print('Device uptime: ' .. util.formatDuration(uptime), uptime)

        if (uptime > 3600) and (now.hour == 15) and (now.min >= 55) then
            os.reboot()
        end
    end)
end

-- SSDP service
--[[
function services.ssdp()
    local device = gateway.getDeviceProperties()
    local version = process.version
    local did = app.get('did') or client.getMacAddress();
    local model = device.deviceType .. '/' .. version
    local ssdpSig = "lnode/" .. version .. ", ssdp/" .. ssdp.version

    local options = {
        udn = 'uuid:' .. did,
        ssdpSig = ssdpSig,
        deviceModel = model
    }

    -- console.log(options, did)
    local server, error = ssdp.server(options)
    if (error) then
        print('Start sddp error:', error)
        return
    end

    print('start ssdp: ', ssdpSig, model)
    exports.ssdpServer = server
end
--]]

return services
