local app = require('app')
local rpc = require('app/rpc')

local server = require('./server')

local exports = {}

function exports.view(type, ...)
    local params = { ... }
    rpc.call('tunneld', type or 'test', params, function(err, result)
        console.printr(type, result or '-', err or '')
    end)
end

function exports.start()
    return server.start()
end

function exports.init()
    print("Usage: ")
    print("  lpm tunneld start")
end

app(exports)
