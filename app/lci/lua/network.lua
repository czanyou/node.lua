local fs     = require('fs')
local uv     = require('luv')
local rpc    = require('app/rpc')
local core   = require('core')
local config = require('app/conf')
local path   = require('path')
local json   = require('json')
local util   = require('util')

local devices = require('devices')

local exports = {}

local context = {}

local modemManager = nil

local STARTING = 1
local RUNNING = 0
local IDLE = 2

---@class ModemManager
local ModemManager = core.Emitter:extend()

function ModemManager:initialize(options)
    options = options or {}

    self.id = options.id or '1'
    self.name = options.name or 'dt02-4G-module'
    self.status = {}
    self.enable = false

    self.uartDevice = nil
    self.uartFile = -1
    self.uartName = '/dev/ttyUSB2'
    self.uartPoll = nil
    self.uartTimer = nil

    self.step = 1

    self.atCommands = {
        "ATE0\r\n",
        "AT+CSQ\r\n",
        "AT+QCCID\r",
        "AT+CIMI\r",
        "AT+COPS?\r"
    }

    return self
end

-- 关闭 USB 4G 模块通信串口
function ModemManager:closeUart()
    if (self.uartTimer) then
        clearTimeout(self.uartTimer)
        self.uartTimer = nil
    end

    if (self.uartPoll) then
        uv.poll_stop(self.uartPoll)
        self.uartPoll = nil
    end

    if (self.uartDevice) then
        self.uartDevice:close()
        self.uartDevice = nil
    end

    self.uartFile = -1;
end

-- 返回当前网络状态
function ModemManager:getStatus()
    -- ppp0
    local status = {}
    status.ifname = 'ppp0'
    status.iccid = self.iccid
    status.imsi = self.imsi
    status.operater = self.operater
    status.signalStrength = tonumber(self.signalStrength)
    status.updated = Date.now()

    -- interface
    local interfaces = os.networkInterfaces() or {}
    local interface = interfaces[status.ifname]
    interface = interface and interface[1]
    if (interface) then
        status.ip = interface.ip
        status.netmask = interface.netmask
    end

    return status
end

-- 打开 USB 4G 模块通信串口
function ModemManager:openUart()
    self:closeUart()

    if (not fs.existsSync(self.uartName)) then
        return
    end

    -- device
    local lmodbus = require("lmodbus")
    local uartDevice = lmodbus.new(self.uartName, 115200, 78, 8, 1) -- N: 78, O: 79, E: 69
    self.uartDevice = uartDevice;

    uartDevice:connect()

    -- file
    local uartFile = uartDevice:getFD()
    if (uartFile < 0 ) then
        console.info("open device error")

        return -1
    end

    self.uartFile = uartFile

    local atCmd = self.atCommands

    local function onNextStep()
        self.step = self.step + 1

        if (self.step == 3) then
            if (self.iccid) then
                self.step = self.step + 1
            end
        end

        if (self.step == 4) then
            if (self.imsi) then
                self.step = self.step + 1
            end
        end

        if (self.step == 5) then
            if (self.operater) then
                self.step = self.step + 1
            end
        end

        if (self.step <= 5) then
            fs.writeSync(uartFile, nil, atCmd[self.step])

        elseif (self.step > 5) then
            self:closeUart()
            self:onSaveStatus()
        end
    end

    local function onData(data)
        if (data == nil or #data < 2) then
            return
        end

        -- console.log('onData', self.step, data)

        if (self.step == 1) then
            if (string.find(data, "OK\r\n")) then
                onNextStep()
            end

        elseif (self.step == 2) then
            if (string.find(data, "+CSQ: ")) then
                self.signalStrength = tonumber(string.match(data, "%d+"))
                console.log('signalStrength', self.signalStrength)
                onNextStep()
            end

        elseif (self.step == 3) then
            if (string.find(data, "+QCCID: ")) then
                self.iccid = string.match(data, "%d+")
                onNextStep()
            end

        elseif (self.step == 4) then
            if (string.find(data, "OK\r\n")) then
                self.imsi = string.match(data, "%d+")
                onNextStep()
            end

        elseif (self.step == 5) then
            if (string.find(data, "+COPS: ")) then
                local a, b, string = string.find(data, '(["].*["])')
                if (string) then
                    self.operater = string.sub(string, 2, b - a);
                end

                onNextStep()
            end
        end
    end

    local function onUartData()
        fs.read(uartFile, function(err, data, bytesRead)
            onData(data)
        end)
    end

    -- poll
    self.uartPoll = uv.new_poll(uartFile)
    if (self.uartPoll) then
        uv.poll_start(self.uartPoll, "r", onUartData)
    end
end

-- 当开始拨号
function ModemManager:onConnect()
    local MIN_CONNECT_INTERVAL = 10
    local MAX_CONNECT_INTERVAL = 60

    local checkTimer
    local retrtTimes = 0
    local now = os.time()

    local function checkPppdProcess()
        local filename = '/var/run/ppp0.pid'
        local filedata = fs.readFileSync(filename)
        local pid = tonumber(filedata) or ''

        filename = '/proc/' .. pid
        local ret = fs.existsSync(filename)
        if (ret) then
            clearInterval(checkTimer)
            checkTimer = nil
            self.status.pppd = RUNNING
            self.connectInterval = MIN_CONNECT_INTERVAL
            console.info("start pppd task success")

        else
            retrtTimes = retrtTimes + 1
            if (retrtTimes >= 5) then

                retrtTimes = 0
                clearInterval(checkTimer)
                checkTimer = nil
                self.status.pppd = IDLE
                os.execute("killall pppd")
                console.info("start pppd task failed")
            end
        end
    end

    if (not self.connectTime) then
        self.connectTime = now
        self.connectInterval = MIN_CONNECT_INTERVAL
    end

    if (self.connectTime > now) then
        return
    end

    self.connectTime = now + self.connectInterval
    self.connectInterval = self.connectInterval * 2
    if (self.connectInterval > MAX_CONNECT_INTERVAL) then
        self.connectInterval = MAX_CONNECT_INTERVAL
    end

    console.info("start pppd connect")
    self.status.pppd = STARTING
    os.execute("route del default")
    os.execute("killall pppd")
    os.execute("pppd call quectel-ppp &")

    checkTimer = setInterval(1000, checkPppdProcess)
    self:onUpdateStatus()
end

-- 对 4G 模块进行复位
function ModemManager:onReset()
    console.info("pppd reset")

    self:closeUart()

    self.status.pppd = IDLE
    devices.setSwitchState("ec20", '0', function()
        setTimeout(300, function()
            devices.setSwitchState("ec20", '1', function()
                os.execute("rm -rf /tmp/ppp/connect-errors")
            end)
        end)
    end)
end

function ModemManager:onSaveStatus()
    local data = self:getStatus()
    local filename = path.join(os.tmpdir, 'run/wan.json')
    local filedata = json.stringify(data)
    fs.writeFile(filename, filedata)
end

-- 定时查询拨号状态
function ModemManager:onUpdateStatus()
    if (not self.enable) then
        return
    end

    self:openUart()

    local atCmd = self.atCommands

    if (self.uartFile and self.uartFile > 0) then
        self.step = 1

        -- start command send
        fs.writeSync(self.uartFile, nil, atCmd[self.step])

        self.uartTimer = setTimeout(1000 * 5, function()
            self.uartTimer = nil
            self:closeUart()
        end)
    end

    return 0
end

-- 设置是否启用 4G 拨号
-- @param {boolean} isEnabled
function ModemManager:setEnabled(isEnabled)
    if (self.enable == isEnabled) then
        return
    end

    self.enable = isEnabled
    if (self.enable) then
        console.info("ppp set enable")
        self:onConnect()

    else
        console.info("ppp set disable")
        os.execute("killall pppd")
    end
end

-- 开始监控 4G 拨号状态
function ModemManager:start()
    print("Network: start network monitor")

    -- disconnect timer
    local disconnectCount = 1
    setInterval(1000 * 30, function()
        if (not self.enable) then
            return
        end

        local params = {}
        rpc.call('wotc', 'network', params, function(err, result)
            if (result) then
                disconnectCount = 1
            else
                disconnectCount = disconnectCount + 1
            end
        end)

        if (disconnectCount > 5) then
            console.warn("network status false")
            disconnectCount = 1
            self:onReset()
        end
    end)

    -- update status timer
    setInterval(1000 * 30, function()
        self:onUpdateStatus()
    end)

    setInterval(1000 * 10, function()
        if (self.status.pppd == STARTING) then
            return
        end

        local filename = '/var/run/ppp0.pid'
        local ret = fs.existsSync(filename)
        if (self.enable) then
            if (ret) then
                return
            end
            self:onConnect()

        else
            if (not ret) then
                return
            end
            os.execute("killall pppd")
        end
    end)
end

-- ////////////////////////////////////////////////////////////////////////////
-- networkManager

local networkManager = { lanConfig = {}, dhcpConfig = {}}

function networkManager.applyNetworkConfig(options)
    if (not options) then
        return
    end

    networkManager.updateNetworkNameServer(options) -- dns
    networkManager.updateNetworkAddress(options)
    networkManager.updateNetworkRouter(options)
end

function networkManager.getDomainServers()
    local result = {}
    local filedata = fs.readFileSync('/etc/resolv.conf')
    if (not filedata) then
        return
    end

    local lines = filedata:split('\n')
    for _, line in ipairs(lines) do
        local tokens = line:split(' ')
        local server = tokens and tokens[2]
        if (tokens[1]) and (tokens[1] == 'nameserver') and server then
            table.insert(result, server)
        end
    end
    return result
end

function networkManager.getStatus()
    local status = {}

    local lanConfig = networkManager.lanConfig or {}
    status.ifname = lanConfig.ifname or 'eth0'
    status.dns = networkManager.getDomainServers();

    if (lanConfig.proto == "dhcp") then
        status.dhcp = true

        local dhcpConfig = networkManager.dhcpConfig or {}
        status.router = dhcpConfig.router

    else
        status.router = lanConfig.router
    end

    -- interface
    local interfaces = os.networkInterfaces() or {}
    local interface = interfaces[status.ifname] or interfaces['enp3s0']
    interface = interface and interface[1]
    if (interface) then
        status.ip = interface.ip
        status.mac = util.hexEncode(interface.mac)
        status.netmask = interface.netmask
    end

    return status
end

-- update network address & netmask
function networkManager.updateNetworkAddress(options)
    if (not options) or (not options.ip) then
        return
    end

    local ifname = options.ifname or 'eth0'
    local cmd = "ifconfig " .. ifname .. " " .. options.ip
    if (options.netmask) then
        cmd = cmd .. " netmask " .. options.netmask
    end
    os.execute(cmd)
end

-- update default gateway route
function networkManager.updateNetworkRouter(options)
    local ifname = options.ifname or 'eth0'
    if (modemManager.enable) then
        return
    end

    os.execute("route del default")
    os.execute("ip route del dev " .. "ppp0")

    if (not options.router) then
        return
    end

    local cmd = "ip route add default via " .. options.router .. ' dev ' .. ifname
    os.execute(cmd)
end

-- update DNS server
function networkManager.updateNetworkNameServer(options)
    if (not options.dns or modemManager.enable) then
        return
    end

    local dns = tostring(options.dns)
    local tokens = dns:split(' ')
    local data = ''
    for _, name in ipairs(tokens) do
        if (name and #name > 0) then
            data = data .. 'nameserver ' .. name .. "\n"
        end
    end

    local filename = '/etc/resolv.conf'
    fs.writeFileSync(filename, data)
end

function networkManager.readConfigTimer()
    config.load("network", function(ret, profile)
        local staticConfig = profile:get('static') or {}
        local lanConfig = profile:get('lan') or staticConfig
        local wanConfig = profile:get('wan') or {}

        lanConfig.ifname = 'eth0'
        networkManager.lanConfig = lanConfig
        -- console.log('dhcpConfig', dhcpConfig)
        -- console.log('networkConfig', networkConfig)

        -- 向后兼容
        if (not wanConfig.proto) and (staticConfig.net_mode == 'ppp') then
            wanConfig.proto = "ppp"
        end

        if (not lanConfig.proto) and (staticConfig.ip_mode == 'dhcp') then
            lanConfig.proto = "dhcp"
        end

        -- LAN settings
        local isEnabled = (wanConfig.proto == "ppp")
        modemManager:setEnabled(isEnabled)

        if (lanConfig.proto == "dhcp") then
            -- dhcp
            local filename = path.join(os.tmpdir, 'run/dhcp.json')
            local dhcpProfile = config.Profile:new(filename)

            local dhcpConfig = dhcpProfile.settings or {}
            local updated = dhcpConfig.updated
            if (updated == networkManager.configUpdated) then
                return
            end

            networkManager.applyNetworkConfig(dhcpConfig)
            networkManager.configUpdated = updated
            networkManager.dhcpConfig = dhcpConfig

        else
            -- static
            local updated = profile:get('updated')
            if (updated == networkManager.configUpdated) then
                return
            end

            networkManager.applyNetworkConfig(lanConfig)
            networkManager.configUpdated = updated
        end
    end)
end

-- 在后台检测网络配置状态
---@param interval integer
function networkManager.start(interval)
    interval = (tonumber(interval) or 10) * 1000

    networkManager.readConfigTimer()
    setInterval(interval, function()
        networkManager.readConfigTimer()
    end)
end

-- --------------------
-- exports

function exports.getModemManager(callback)
    if (not modemManager) then
        modemManager = ModemManager:new()
    end

    if (callback) then
        callback(modemManager)
    end

    return modemManager
end

function exports.getNetworkStatus()
    local status = {}
    status.lan = networkManager and networkManager.getStatus() or {}
    status.wan = modemManager and modemManager:getStatus() or {}
    return status
end

function exports.start(interval)
    modemManager = exports.getModemManager()
    if (modemManager) then
        modemManager:start()
    end

    networkManager.start(interval)
end

return exports
