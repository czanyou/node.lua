local fs = require("fs")
local config = require('app/conf')
local app = require('app')
local path = require('path')
local util = require('util')
local luv = require('luv')

local http = require('./http')
local device = require('./device')

local exports = {}

local function checkButtonStatus(interval_ms)
    if (not device.isSupport()) then
        print('Error: gpio not exists')
        return
    end

    local TIMEOUT_NETWORK_RESET = 4
    local TIMEOUT_SYSTEM_RESET = 10
    local DEFAULT_IP = "192.168.8.12"

    local pressTime = 0
    local networkReset = 0
    local systemReset = 0

    local function onNetworkReset()
        console.log("network reset")

        local cmd = 'ifconfig eth0 ' .. DEFAULT_IP
        os.execute(cmd)
    end

    local function onSystemReset()
        console.log("system reset")
        exports.reset()

        setTimeout(1000, function()
            os.execute('reboot')
        end)
    end

    setInterval(interval_ms, function()
        local state = device.getButtonState('reset')
        if (state == 0) then
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

        else
            pressTime = 0
            networkReset = 0
            systemReset = 0
        end
    end)
end

local function checkNetworkStatus(interval_ms)
    local function updateNetworkAddress(config)
        local interface = config.interface or 'eth0'

        if (not config.ip) then
            return
        end

        print("set config ip:" .. config.ip)
        local cmd = "ifconfig " .. interface .. " " .. config.ip
        if (config.netmask) then
            cmd = cmd .. " netmask " .. config.netmask
        end

        console.log(cmd)
        os.execute(cmd)
    end

    local function updateNetworkRouter(config)
        local interface = config.interface or 'eth0'

        if (not config.router) then
            return
        end

        print("set router:" .. config.router)
        local cmd = "ip route del dev " .. interface
        for i = 1, 10 do
            console.log(cmd)
            if (not os.execute(cmd)) then
                break
            end
        end

        cmd = "ip route add default via " .. config.router .. " dev " .. interface
        console.log(cmd)
        os.execute(cmd)
    end

    local function updateNetworkNameServer(config)
        if (not config.dns) then
            return
        end

        print("set name servers:" .. config.dns)
        local tokens = config.dns:split(' ')
        local data = ''
        for _, name in ipairs(tokens) do
            data = data .. 'nameserver ' .. name .. "\n"
        end

        console.log(data)
        local filename = '/etc/resolv.conf'
        fs.writeFileSync(filename, data)
    end

    local function applyNetworkConfig(config)
        console.log('network config:', config)
        config.interface = 'eth0'

        updateNetworkAddress(config) -- ip & netmask
        updateNetworkRouter(config)
        updateNetworkNameServer(config) -- dns
    end

    local configUpdated = 1

    local function readConfig()
        config.load("network", function(ret, profile)

            local staticConfig = profile:get('static')
            local dhcpConfig = profile:get('dhcp')
            local updated = profile:get('updated')
            if (updated ~= configUpdated and staticConfig) then
                if (staticConfig.ip_mode == "dhcp") then
                    applyNetworkConfig(dhcpConfig)

                else
                    applyNetworkConfig(staticConfig)
                end

                configUpdated = updated
            end
        end)
    end

    readConfig()
    setInterval(interval_ms, function()
        readConfig()
    end)
end

function exports.http(...)
    print('did: ', app.get('did'))
    http.start(...)
end

function exports.button(interval)
    checkButtonStatus((interval or 1) * 1000)
end

function exports.network(interval)
    checkNetworkStatus((interval or 10) * 1000)
end

function exports.start(...)
    if (app.lock()) then
        exports.network()
        exports.button()
        exports.http(...)
    end
end

-- 激活设备
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
function exports.reset()
    os.execute('lpm unset default:activate')

    local nodePath = app.nodePath
    local filename = path.join(nodePath, 'conf/network.default.conf')
    local destname = path.join(nodePath, 'conf/network.conf')

    os.remove(destname)
    fs.copyfileSync(filename, destname)

    filename = path.join(nodePath, 'conf/default.conf')
    destname = path.join(nodePath, 'conf/user.conf')

    os.remove(destname)
    fs.copyfileSync(filename, destname)
end

function exports.test(type)
    if (type == 'button') then
        local state, err = device.getButtonState()
        console.log('RESET button: ', state or err)

    elseif (type == 'led') then
        device.setLEDStatus('green', 'on')
        device.setLEDStatus('blue', 'on')
        device.setLEDStatus('yellow', 'on')

        setTimeout(1000, function()
            device.setLEDStatus('green', 'off')
            device.setLEDStatus('blue', 'off')
            device.setLEDStatus('yellow', 'off')
        end)
    elseif (type == 'test') then
        local test = require('./test')
        test.start()

    else
        print("Usage: lpm lci test <button,led,test>")
    end
end

app(exports)
