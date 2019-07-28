local exports = {}

-- Log levels
local LEVEL_INFO  = 1
local LEVEL_WARN  = 2
local LEVEL_ERROR = 3

-- @type {Thing} WoT client
local wotClient = nil

-- Redirect log information to the WoT server
-- @param level {number} Log level
-- @param line {number} Line number of the source code
-- @param message {string} Message text
function exports.log(level, line, message, ...)
    local at = Date.now()

    -- print to console
    console.log(at, level, line, message, ...)

    local log = {
        at = at, 
        level = level, 
        line = line, 
        message = message
    }

    -- push to WoT cloud
    if (wotClient) then
        wotClient:emitEvent('log', log)
    end
end

-- Init log module
-- @param client {Thing} WoT client
function exports.init(client)
    wotClient = client

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
