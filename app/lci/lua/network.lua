local fs     = require("fs")
local modbus = require("lmodbus")
local uv     = require("luv")
local rpc    = require('app/rpc')
local core   = require('core')
local config = require('app/conf')
local path   = require('path')
local json   = require('json')

local devices = require('devices')

local exports = {}

local networkManager = nil

local STARTING = 1
local RUNNING = 0
local IDLE = 2

local NetworkManager = core.Emitter:extend()

function NetworkManager:initialize(options)
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

function NetworkManager:closeUart()
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

-- 打开串口
function NetworkManager:openUart()
    self:closeUart()

    -- device
    local uartDevice = modbus.new(self.uartName, 115200, 78, 8, 1) -- N: 78, O: 79, E: 69
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

-- 设置是否启用 4G 拨号
-- @param {boolean} isEnabled
function NetworkManager:setEnabled(isEnabled)
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
function NetworkManager:start()
    console.log("start monitor")

    -- disconnect timer
    local disconnectCount = 1
    setInterval(1000 * 30, function()
        if (not self.enable) then
            return
        end

        local name = 'wotc'
        local params = {}

        rpc.call(name, 'network', params, function(err, result)
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

    setInterval(10 * 1000, function()
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

-- 定时查询拨号状态
function NetworkManager:onUpdateStatus()
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

function NetworkManager:onSaveStatus()
    local data = self:getStatus()
    local filename = path.join(os.tmpdir, 'run/network.json')
    local filedata = json.stringify(data)
    fs.writeFile(filename, filedata)
end

-- 当开始拨号
function NetworkManager:onConnect()
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
function NetworkManager:onReset()
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

-- 返回当前网络状态
function NetworkManager:getStatus()
    -- ppp
    local pppStatus = {}
    pppStatus.interface = 'ppp0'
    pppStatus.iccid = self.iccid
    pppStatus.imsi = self.imsi
    pppStatus.operater = self.operater
    pppStatus.signalStrength = tonumber(self.signalStrength)
 
    -- interface
    local interfaces = os.networkInterfaces() or {}
    local interface = interfaces[pppStatus.interface]
    interface = interface and interface[1]
    if (interface) then
        pppStatus.ip = interface.ip
        pppStatus.netmask = interface.netmask
    end

    return pppStatus
end

-- ////////////////////////////////////////////////////////////////////////////
-- public method

function exports.getManager(callback)
    if (not networkManager) then
        networkManager = NetworkManager:new()
    end

    if (callback) then
        callback(networkManager)
    end

    return networkManager
end

local networkConfig = {}
local dhcpConfig = {}

-- 在后台检测网络配置状态
-- @param {string} interval
function exports.checkNetworkStatus(interval_ms)

    -- update network address & netmask
    local function updateNetworkAddress(config)
        if (not config) and (not config.ip) then
            return
        end
        local interface = config.interface or 'eth0'
        local cmd = "ifconfig " .. interface .. " " .. config.ip
        if (config.netmask) then
            cmd = cmd .. " netmask " .. config.netmask
        end
        os.execute(cmd)
    end

    -- update default gateway route
    local function updateNetworkRouter(config)
        local interface = config.interface or 'eth0'
        if (networkManager.enable) then
            return
        end

        os.execute("route del default")
        os.execute("ip route del dev " .. "ppp0")
        local cmd = "ip route add default via " .. config.router .. ' dev '..interface
        os.execute(cmd)
    end

    -- update DNS server
    local function updateNetworkNameServer(config)
        if (not config.dns or networkManager.enable) then
            return
        end

        local tokens = config.dns:split(' ')
        local data = ''
        for _, name in ipairs(tokens) do
            data = data .. 'nameserver ' .. name .. "\n"
        end

        local filename = '/etc/resolv.conf'
        fs.writeFileSync(filename, data)
    end

    local function applyNetworkConfig(config)
        updateNetworkNameServer(config) -- dns
        updateNetworkAddress(config)
        updateNetworkRouter(config)
    end

    local configUpdated
    local function readConfigTimer()
        config.load("network", function(ret, profile)

            networkConfig = profile:get('static') or {}
            dhcpConfig = profile:get('dhcp') or {}
            local updated = profile:get('updated')
            networkConfig.interface = 'eth0'

            -- LAN settings
            if (updated == configUpdated) or (not networkConfig ) then
                return
            end

            local isEnabled = (networkConfig.net_mode == "ppp")

            -- local isEnabled = (networkConfig.net_mode == "ppp")
            networkManager:setEnabled(isEnabled)

            local config = {}
            if (networkConfig.ip_mode == "dhcp") then
                config.ip = dhcpConfig.ip
                config.netmask = dhcpConfig.netmask
                config.dns = dhcpConfig.dns
                config.router = dhcpConfig.router
                config.interface = dhcpConfig.interface

            else
                config.ip = networkConfig.ip
                config.netmask = networkConfig.netmask
                config.dns = networkConfig.dns
                config.router = networkConfig.router
                config.interface = networkConfig.interface
            end

            applyNetworkConfig(config)
            configUpdated = updated
        end)
    end

    readConfigTimer()
    setInterval(interval_ms, function()
        readConfigTimer()
    end)
end

function exports.getNetworkStatus()
    local status = {}

    -- ethernet
    status.ethernet = {}
    local ethernetStatus = networkConfig
    if (networkConfig.ip_mode == "dhcp") then
        ethernetStatus = dhcpConfig
        status.ethernet.dhcp = true
    end

    status.ethernet.ip = ethernetStatus.ip
    status.ethernet.router = ethernetStatus.router
    status.ethernet.netmask = ethernetStatus.netmask
    status.ethernet.dns = ethernetStatus.dns
    status.ethernet.interface = ethernetStatus.interface

    -- wan
    status.wan = {}
    if (networkConfig.net_mode == "ppp") then
        status.bearer = 5
    end

    local pppStatus = networkManager and networkManager:getStatus()
    if (not pppStatus) then
        return status
    end

    status.wan = pppStatus
    return status
end

return exports
