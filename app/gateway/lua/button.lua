local path = require("path")
local fs = require("fs")
local wot = require("wot")


local SYS_CONFIG = 5
local SYS_RESET = 8
local DEFAULT_IP = "192.168.8.2"

local exports = {}
local pressTime = 0
local function CheckButtonState(interval_ms)
    console.log("button check")
    setInterval(
        interval_ms,
        function()
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
                    io.popen("ifconfig eth0 192.168.8.104")
                   
                elseif (pressTime > SYS_RESET) then
                    console.log("sys reset")
                end
                pressTime = 0
            end

            -- console.log(state)
        end
    )
end

local function ledSwitch(color, state)
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
    
    fs.write(
        fd,
        nil,
        value,
        function(err, written)
            fs.closeSync(fd)
        end
    )
end

exports.checkButton = CheckButtonState
exports.runningLed = runningStateindex
exports.ledSwitch = ledSwitch
return exports
