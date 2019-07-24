local path = require("path")
local fs = require("fs")
local wot = require("wot")
local config  = require('app/conf')
local app = require('app')

local http = require('./http')

local exports = {}

local function checkButtonStatus(interval_ms)
    local TIMEOUT_NETWORK_RESET = 4
    local TIMEOUT_SYSTEM_RESET = 10
    local DEFAULT_IP = "192.168.1.12"

    local pressTime = 0
    local networkReset = 0
    local systemReset = 0

    function onNetworkReset()
        console.log("network reset")
        local cmd = 'ifconfig eth0 ' .. DEFAULT_IP
        console.log(cmd)
        os.execute(cmd)
    end

    function onSystemReset()
        console.log("system reset")

    end
    
    setInterval(interval_ms, function()
        local filename = "/sys/class/gpio/gpio62/value"
        local filedata, err = fs.readFileSync(filename)
        if (not filedata) then
            console.log('checkButtonStatus', err)
            return
        end

        local state = tonumber(filedata)
        -- console.log('state', state, filedata)

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
                    -- os.execute("ifconfig eth0 192.168.8.104")
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
                data = data .. 'nameserver ' .. name .. "\r\n"
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

function exports.button(...)
    checkButtonStatus((interval or 1) * 1000)
end

function exports.network(interval)
    checkNetworkstatus((interval or 10) * 1000)
end

function exports.start(...)
    exports.network()
    exports.button()
    exports.http(...)
end

app(exports)
