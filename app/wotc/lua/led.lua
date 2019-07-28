local fs = require("fs")

local exports = {}

local leds = {
    green = "/sys/class/gpio/gpio53/value",
    blue = "/sys/class/gpio/gpio55/value",
    yellow = "/sys/class/gpio/gpio54/value"
}

-- Set LED status
-- @param color {string} LED type (green, blue, yellow)
-- @param action {string} action type (on, off, toggle)
local function setLEDStatus(color, action)
    local filename = leds[color]
    if (not filename) then
        console.log('Invalid LED type', color)
        return
    end

    local fd, err = fs.openSync(leds[color], "w+", 438)
    if (not fd) then
        console.log('Open LED file failed', err)
        return
    end

    local value = 0
    if action == "on" then
        value = 0

    elseif action == "off" then
        value = 1

    elseif action == "toggle" then
        local result = fs.readSync(fd)
        if (tonumber(result) ~= 1) then
            value = 1
        end
    else
        return
    end

    fs.write(fd, nil, value, function(err)
        fs.closeSync(fd)
    end)
end

-- Indicate whether the current device supports leds
local function isSupport()
    local filename = '/sys/class/gpio/'
    return fs.existsSync(filename)
end

exports.setLEDStatus = setLEDStatus
exports.isSupport = isSupport

return exports
