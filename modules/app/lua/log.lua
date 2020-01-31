local fs = require('fs')

local exports = {}

-- Log levels
local LEVEL_INFO  = 1
local LEVEL_WARN  = 2
local LEVEL_ERROR = 3

-- Redirect log information to the WoT server
-- @param level {number} Log level
-- @param line {number} Line number of the source code
-- @param message {string} Message text
function exports.log(level, line, ...)
    local at = os.date('%Y-%m-%d,%H:%M:%S')

    -- print to console
    -- console.log(at, level, line, message, ...)
    local args = table.pack(...);
    if (not args) then
        return
    end

    -- write to file
    local data = { at, level, line }

    for _, value in ipairs(args) do
        if (value ~= nil) then
            local valueType = type(value)
            if (valueType == 'boolean') then
                table.insert(data, value and 'true' or 'false')
            elseif (valueType ~= 'table') then
                table.insert(data, value)
            end
        end
    end

    local LOG_MAX_SIZE = 1024 * 64 -- in bytes
    local logMessage = table.concat(data, ',') .. '\r\n'
    local filename = "/tmp/log/wotc.log"
    fs.stat(filename, function(err, stat)
        if (stat and stat.size > LOG_MAX_SIZE) then
            console.log(stat.size)
            os.rename(filename, '/tmp/log/wotc_old.log')
        end
        fs.appendFile(filename, logMessage)
    end)

    print(table.concat(data, ', '));
end

-- Init log module
-- @param client {Thing} WoT client
function exports.init(client)
    console.error = function (message, ...)
        exports.log(LEVEL_ERROR, console.getFileLine(), message, ...)
    end

    console.warn = function (message, ...)
        exports.log(LEVEL_WARN, console.getFileLine(), message, ...)
    end

    console.info = function (message, ...)
        exports.log(LEVEL_INFO, console.getFileLine(), message, ...)
    end
end

return exports
