local path = require("path")
local fs = require("fs")
local wot = require("wot")

local TIMEOUT_NETWORK_RESET = 4
local TIMEOUT_SYSTEM_RESET = 10
local DEFAULT_IP = "192.168.8.2"

local exports = {}
local pressTime = 0
local networkReset = 0
local systemReset = 0

local function checkButtonStatus(interval_ms)
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
                    console.log("system reset")
                end

            elseif (pressTime >= TIMEOUT_NETWORK_RESET) then
                if (networkReset ~= 1) then
                    networkReset = 1
                    console.log("network reset:", DEFAULT_IP)
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

local function setLEDStatus(color, state)
    local value
    local led = {
        green = "/sys/class/gpio/gpio53/value",
        blue = "/sys/class/gpio/gpio55/value",
        yellow = "/sys/class/gpio/gpio54/value"
    }

    local fd = fs.openSync(led[color], "w+", 438)
    if (not fd) then
        return
    end

    if state == "on" then
        value = 0
    elseif state == "off" then
        value = 1
    elseif state == "toggle" then
        local result = fs.readSync(fd)
        if (tonumber(string.match(result, "(%d)\n")) == 1) then
            value = 0
        else
            value = 1
        end
    else
        return
    end
    
    fs.write(fd, nil, value, function(err, written)
        fs.closeSync(fd)
    end)
end

exports.checkButton = checkButtonStatus
exports.runningLed = runningStateindex
exports.ledSwitch = setLEDStatus

return exports
