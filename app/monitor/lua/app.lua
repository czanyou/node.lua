local path = require("path")
local fs = require("fs")
local wot = require("wot")
local config  = require('app/conf')
local app   = require('app')

local http = require('./http')

local SYS_CONFIG = 5
local SYS_RESET = 8
local DEFAULT_IP = "192.168.8.2"

local exports = {}
local pressTime = 0

local function checkButtonState()
    console.log("button check")
    setInterval( 1000,function()
        local path = "/sys/class/gpio/gpio62/value"
        local source = fs.openSync(path, "r", 438)
        if (not source) then
            return
        end

        local result = fs.readSync(source)
        fs.closeSync(source)
        state = tonumber(string.match(result, "(%d)\n"))
        if (state == 0) then
            pressTime = pressTime + 1
            console.log(pressTime)
        end

        if (state == 1) then
            if (pressTime > SYS_CONFIG and pressTime < SYS_RESET) then
                console.log("set ip:" .. DEFAULT_IP)
                local cmd = "ifconfig eth0 "..DEFAULT_IP
                os.execute(cmd)
                os.execute("rm /usr/local/lnode/conf/network.conf")
                
            elseif (pressTime > SYS_RESET) then
                console.log("sys reset")
            end
            pressTime = 0
        end

        -- console.log(state)
    end)
end

local function checkNetworkstatus(interval_ms)
    local profile 
    local staticConfig
    local udhcConfig
    local profile 
    console.log("network status check")

    local function applyNetworkConfig(config)
        if (config.ip) then
            console.log("set config ip:" .. config.ip)
            cmd = "ifconfig eth0 " .. config.ip
            os.execute(cmd)
        end
    end

    local function readConfig()  
        console.log("network status check")
        config.load("network", function(ret, profile)

            staticConfig = profile:get('static')
            udhcConfig = profile:get('udhc')
            local update = profile:get('update')

            local cmd
            if (update == "true" and staticConfig) then
                if (staticConfig.ip_mode == "dhcp") then
                    applyNetworkConfig(udhcConfig)
                    
                else
                    applyNetworkConfig(staticConfig)
                end

                profile:set("update", "false")
                profile:commit()
            end
        end)
    end

    setInterval(interval_ms, function()
        readConfig()
    end)
end

function exports.http(...)
    http.start(...)
end

function exports.button(...)
    checkButtonState()
end

function exports.network(...)
    checkNetworkstatus(10000)
end

function exports.start(...)
    exports.network()
    exports.button()
    exports.http(...)
end

app(exports)
