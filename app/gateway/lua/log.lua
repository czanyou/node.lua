local exports = {}

-- Redirect log information to the WoT server
function exports.log(gateway, at, level, line, message, ...)
    console.log(at, level, line, message, ...)
    local log = {
        at = at, level = level, line = line, message = message
    }

    if (gateway) then
        gateway:emitEvent('log', log)
    end
end

-- Init log module
function exports.init(gateway)
    console.error = function (message, ...) 
        exports.log(gateway, Date.now(), 3, console.getFileLine(), message, ...)
    end

    console.warn = function (message, ...) 
        exports.log(gateway, Date.now(), 2, console.getFileLine(), message, ...)
    end

    console.info = function (message, ...) 
        exports.log(gateway, Date.now(), 1, console.getFileLine(), message, ...)
    end
end

return exports
