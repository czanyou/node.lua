local utils     = require('utils')
local path 	    = require('path')
local conf      = require('ext/conf')
local json      = require('json')
local fs        = require('fs')
local thread    = require('thread')
local querystring = require('querystring')
local rpc       = require('vision/express/rpc')

local function on_status(request, response)
    local method    = 'status'
    local params    = {}

    local IPC_PORT = 39901
    rpc.call(IPC_PORT, method, params, function(err, result)
        if (result) then
            result.now = process.now()
        end
        response:json(result)
    end)
end

local function on_device_status(request, response)
    local lpm = conf('lpm')

    local device = {}
    local status = { device = device }
    --status.lpm  = lpm.options
    --status.sscp = sscp.options
    status.interfaces = get_network_interfaces()

    if (lpm) then
        local cpu = os.cpus() or {}
        cpu = cpu[1] or {}
        cpu = cpu.model or ''

        local stat = fs.statfs('/') or {}
        local storage_total = (stat.blocks or 0) * (stat.bsize or 0)
        local storage_free  = (stat.bfree or 0) * (stat.bsize or 0)

        local memmory_total = os.totalmem()
        local memmory_free  = os.freemem()

        local memmory = app.formatBytes(memmory_free) .. " / " .. app.formatBytes(memmory_total) .. 
            " (" .. math.floor(memmory_free * 100 / memmory_total) .. "%)"

        local storage = app.formatBytes(storage_free) .. " / " .. app.formatBytes(storage_total) .. 
            " (" .. math.floor(storage_free * 100 / storage_total) .. "%)"

        local model = get_system_target() .. " (" .. os.arch() .. ")"

        device.device_name      = lpm:get('device.id')
        device.device_model     = model
        device.device_version   = process.version
        device.device_memmory   = memmory
        device.device_cpu       = cpu
        device.device_root      = app.rootPath
        device.device_url       = app.rootURL        
        device.device_storage   = storage
        device.device_time      = os.date('%Y-%m-%dT%H:%M:%S')
        device.device_uptime    = os.uptime()

    end

    response:json(status)   
end

local function do_api(request, response, onEnd)
    local api = request.api

    if (api == '/status') then
        on_status(request, response)

    else
        response:sendStatus(400, "No `api` parameters specified!")
    end
end

request.params  = querystring.parse(request.uri.query) or {}
request.api     = request.params['api']
do_api(request, response)

return true
