local utils     = require('utils')
local path 	    = require('path')
local conf      = require('ext/conf')
local json      = require('json')
local fs        = require('fs')
local thread    = require('thread')
local querystring = require('querystring')
local rpc       = require('ext/rpc')
local httpd     = require('httpd')

local function on_status(request, response)
    local method    = 'status'
    local params    = {}

    local IPC_PORT = "rpc-mqtt"
    rpc.call(IPC_PORT, method, params, function(err, result)
        if (result) then
            result.now = process.now()
        end
        response:json(result)
    end)
end

local methods = {}
methods['/status']     = on_status

httpd.call(methods, request, response)

return true
