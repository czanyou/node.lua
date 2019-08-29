local fs = require("fs")
local config  = require('app/conf')
local app = require('app')
local path = require('path')
local util = require('util')

local http = require('./http')
local device = require('./device')

local exports = {}

local function checkButtonStatus(interval_ms)
    if (not device.isSupport()) then
        print('Error: gpio not exists')
        return
    end

    local TIMEOUT_NETWORK_RESET = 5
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

        local cmd = 'rm /usr/local/lnode/conf/network.conf'
        os.execute(cmd)
        local cmd = 'cp /usr/local/lnode/conf/network.deault.conf /usr/local/lnode/conf/network.conf'
        os.execute(cmd)

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

local function checkNetworkstatus(interval_ms)
    local function applyNetworkConfig(config)
        console.log('network config:', config)
        local interface = 'eth0'

        -- ip & netmask
        if (config.ip) then
            console.log("set config ip:" .. config.ip)
            local cmd = "ifconfig " .. interface .. " " .. config.ip
            if (config.netmask) then
                cmd = cmd .. " netmask " .. config.netmask
            end

            console.log(cmd)
            os.execute(cmd)
        end

        -- router
        if (config.router) then
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

        -- dns
        if (config.dns) then
            local tokens = config.dns:split(' ')
            local data = ''
            for index, name in ipairs(tokens) do
                data = data .. 'nameserver ' .. name .. "\n"
            end

            console.log(data)
            local filename = '/etc/resolv.conf'
            fs.writeFileSync(filename, data)
        end
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
    http.start(...)
end

function exports.button(interval)
    checkButtonStatus((interval or 1) * 1000)
end

function exports.network(interval)
    checkNetworkstatus((interval or 10) * 1000)
end

function exports.start(...)
    if (app.lock()) then
        exports.network()
        exports.button()
        exports.http(...)
    end
end

-- 激活设备
function exports.activate(newPassword, newSecret)
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
function exports.reset(newSecret)
    local nodePath = app.nodePath

    -- secret
    if (newSecret) then
        newSecret = util.md5string('wot:' .. newSecret)
    else
        newSecret = '60b495fa71c59a109d19b6d66ce18dc2'
    end

    local filename = path.join(nodePath, 'conf/lnode.key')
    fs.writeFileSync(filename, newSecret)

    -- telnet secret
    local passwd = 'root:HCIq1D.VMsZRw:0:0::/root:/bin/sh\n'
    fs.writeFileSync('/etc/passwd', passwd)
end

function exports.test(type)
    if (type == 'button') then
        local state, err = device.getButtonState()
        console.log('RESET button: ', state or err)

    elseif (type == 'button') then
        device.setLEDStatus('green', 'on')
        device.setLEDStatus('blue', 'on')
        device.setLEDStatus('yellow', 'on')

        setTimeout(1000, function()
            device.setLEDStatus('green', 'off')
            device.setLEDStatus('blue', 'off')
            device.setLEDStatus('yellow', 'off')
        end)
    else
        local test = require('./test')
        test.start()
    end
end

app(exports)
