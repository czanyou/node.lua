local app       = require('app')
local utils     = require('util')
local fs        = require('fs')
local path      = require('path')
local json      = require('json')

local bluetooth = require('bluetooth')
local rpc       = require('app/rpc')

local beacon    = require('./clound')
local monitor   = require('./monitor')
local device    = require('sdl')

local SCAN_RESPONSE = 0x04
local RPC_PORT      = 38888

local function onData(err, data)
    if (not data) then
        return

    elseif data:byte(6) == SCAN_RESPONSE then
        return
    end

    --console.printBuffer(data)
 
    -- local message, sensor = beacon.parseBeaconMessage(data)
    local message = beacon.parseBeaconMessage(data)
    if (message == nil) then
        return
    end

    setTimeout(0, function()
        beacon.handleMessage(message)
        -- beacon.handleSensorList(sensor)
    end)
end

-------------------------------------------------------------------------------
-- 

local rpcMethods = {}
local rpcServer  = nil

function rpcMethods:delete( )
    
end

function rpcMethods:getBeacons()
    return beacon.getList()
end

function rpcMethods:alive()
    return true
end

-------------------------------------------------------------------------------
-- 

function getMacAddress()
    local data = fs.readFileSync('/sys/class/net/eth0/address')
    local mac = string.gsub(data, ':', '')
    -- mac = string.upper(string.sub(mac, 1, -2))
    mac = string.sub(mac, 1, -2)
    console.log('MAC', mac)
    return mac
end

local exports = {}

function exports.updateSettings()
    local settings = {}
    settings.server         = app.get('reader.server')
    settings.device_id      = app.get('reader.id')
    settings.device_key     = app.get('reader.key')
    settings.stat_timeout   = app.get('reader.stat_timeout')
    settings.stat_max_count = app.get('reader.stat_max_count')
    settings.stat_max_time  = app.get('reader.stat_max_time')
    settings.stat_factor    = app.get('reader.stat_factor')

    beacon.settings = settings
end

function exports.info()
    exports.updateSettings()
    local mac = getMacAddress()

    beacon.settings.id = mac

    print("Settings:\n======")
    console.log(beacon.settings)

    print('\n')
    monitor.init()

    local deviceInfo = monitor.getProperties()
    deviceInfo.mac = mac

    console.log('device.info', deviceInfo)
    beacon.register(deviceInfo, function(err, result)
        if (err) then 
            console.log(err, result)
            return
        end

        print("Response:\n======")
        console.log(result)

        beacon.settings.collector = '10.10.38.205:8951'
        
        local deviceStatus = monitor.getStatus()
        console.log('device.status', deviceStatus)
        beacon.onHeartbeat(deviceStatus, function(err, result)
            if (err) then 
                console.log(err, result)
                return
            end

            print("Heartbeat:\n======")
            console.log(result)

            beacon.postData()
        end)
    end)
end

function exports.start(mac, timeout)
    local lockfd = app.tryLock('beacon')
    if (not lockfd) then
        print('The beacon is locked!')
        return
    end

    exports.updateSettings()
    console.log('Settings', beacon.settings)

    local updated = os.uptime()

    local callback = function(err, data)
        if (err) then
            console.log(err)
            return
        end

        updated = os.uptime()
        onData(err, data)
    end

    local onPublishData = function()
        beacon.postData()
    end

    local ret = bluetooth.scan(callback)

    local publishTimeout = 1000
    local heartbeatTimeout = 5000
    local registerTimeout = 3600 * 1000

    local registerTimer = nil;
    local registerState  = false

    local id = getMacAddress()

    rpcServer = rpc.server(RPC_PORT, rpcMethods)
    monitor.init()
    
    utils.async(function()
        console.log('loop');

        while true do
            -- Register
            while not registerState do
                --console.log('registerState', registerState);

                local deviceInfo = monitor.getProperties()
                deviceInfo.mac = id

                local error, result = utils.await(beacon.register, deviceInfo)--register request
                -- console.log(result.error)
                if not error then
                    registerState = true
                    local config = result.config or {}
                    --registerTimeout = config.register_interval * 1000
                    --publishTimeout = config.datapush_interval * 1000
                    --heartbeatTimeout = config.datapush_interval * 1000
                    
                    console.log('register success')

                 else
                    console.log('register fail:' .. result.error)
                    utils.await(setTimeout, 5000) --register fail delay
                end
            end

            -- Create Interval
            local publishTimer   = setInterval(publishTimeout, onPublishData)
            local heartbeatTimer = setInterval(heartbeatTimeout, monitor.onHeartbeat)
 
            utils.await(setTimeout, registerTimeout)

            -- Cancel Interval
            registerState = false
            clearInterval(publishTimer)
            clearInterval(heartbeatTimer)
        end        
    end)
end

function exports.status(name)
    local method    = name or 'getBeacons'
    local params    = {}

    rpc.call(RPC_PORT, method, params, function(err, result)
        if (result) then
            console.log(result)
        end
    end)
end

app(exports)
