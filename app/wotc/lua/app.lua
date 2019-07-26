local util  = require('util')
local path  = require('path')
local fs    = require('fs')
local app   = require('app')
local wot   = require('wot')
local rpc   = require('app/rpc')
local ssdpServer = require('ssdp/server')

local client = require('./client')
local log = require('./log')
local led = require('./led')

local exports = {}

function exports.led()
    setInterval(500, function()
        led.setLEDStatus("green", "toggle")

        local ret = wot.isConnected()
        if ret then
            led.setLEDStatus("yellow", "on")
        else
            led.setLEDStatus("yellow", "off")
        end
    end)
end

function exports.config()
    console.log('gateway', app.get('gateway'))
end

function exports.ssdp()
    local version = process.version
    local did = app.get('did') or client.getMacAddress();
    local model = 'DT02/' .. version
    local ssdpSig = "lnode/" .. version .. ", ssdp/" .. ssdpServer.version
    
    local options = {
        udn = 'uuid:' .. did, 
        ssdpSig = ssdpSig, 
        deviceModel = model 
    }
    -- console.log(options, did)
    local server, error = ssdpServer(options)
    if (error) then
        print('Start sddp error:', error)
        return
    end

    exports.ssdpServer = server
end

function exports.gateway()
    -- options
    -- - did
    -- - mqtt
    -- - secret
    local options = {}
    options.did = app.get('did')
    options.mqtt = app.get('mqtt')
    options.secret = app.get('secret')
    options.clientId = 'wotc_' .. options.did

    local webThing, error = client.createThing(options)
    if (error) then
        print('Create thing error:', error)
        return
    end

    app.gateway = webThing
    log.init(webThing)
end

function exports.start()
    local lock = app.lock()
    if (lock) then
        exports.led()
        exports.ssdp()
        exports.rpc()
        exports.gateway()
    end
end

function exports.rpc()
    local handler = {}
    local name = 'wotc'

    handler.test = function(...)
        console.log('test', ...)
        return 0
    end

    handler.firmware = function(handler, data, qos)
        console.log('firmware', data)

        local gateway = app.gateway
        if (gateway) then
            gateway:emitEvent('firmware', data)
        end
    end

    handler.log = function(handler, message)
        console.warn(message)
        return 0
    end

    local server = rpc.server(name, handler, function(event, ...)
        console.log(event, ...)
    end)
end

function exports.test()
    --[[
    local name = 'wotc'
    local params = {{ at = 100, level = 200 }}
    rpc.call(name, 'test', params, function(err, result)
        print('test', err, result)
    end)
    --]]
end

function exports.key(key, did)
    did = did or app.get('did')
    key = key or '123456'
    local hash = did .. ':' .. key
    print(hash, util.md5string(hash))
end

app(exports)
