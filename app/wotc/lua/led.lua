local fs = require("fs")

local exports = {}

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

exports.setLEDStatus = setLEDStatus

return exports
