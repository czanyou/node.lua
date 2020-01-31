local server = require('ssdp/server')
local client = require('ssdp/client')

local exports = {}

exports.version = server.version

function exports.server(options)
    return server(options)
end

function exports.client(options, callback)
    return client(options, callback)
end

return exports