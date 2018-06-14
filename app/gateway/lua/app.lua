local app       = require('app')
local utils     = require('util')
local fs        = require('fs')
local path      = require('path')
local json      = require('json')

local bluetooth = require('bluetooth')
local rpc       = require('app/rpc')

local beacon   = require('./lua/init')
local monitor   = require('./lua/monitor')
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

function getInterfaces()
    local faces = os.networkInterfaces()
    if (faces == nil) then
        return
    end

    local list = {}
    for k, v in pairs(faces) do
        if (k == 'lo') then
            goto continue
        end

        for _, item in ipairs(v) do
            if (item.family == 'inet') then
                if (item.mac) then
                    item.mac = utils.bin2hex(item.mac)
                end

                item.name = k

                list[#list + 1] = item
            end
        end

        ::continue::
    end

    if (#list <= 0) then
        return
    end

    return list
end

function getMacAddress()
    local data = fs.readFileSync('/sys/class/net/eth0/address')
    local mac = string.gsub(data, ':', '')
    -- mac = string.upper(string.sub(mac, 1, -2))
    mac = string.sub(mac, 1, -2)
    console.log(mac)
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

    print("Settings:\n====== ======")
    for k, v in pairs(beacon.settings) do
        if (v == '') then v = '-' end
        print(" " .. string.padRight(k, 10), v or '-')
    end

    print('------ ------\n')

    beacon.register(mac, function(err, result)
        if (err) then console.log(err, result); return; end

        print("Result:\n====== ======")
        for k, v in pairs(result) do
            if (v == '') then v = '-' end
            print(" " .. string.padRight(k, 10), v or '-')
        end

        print('------ ------')
    end)
end

function exports.start(mac, timeout)
    local lockfd = app.tryLock('beacon')
    if (not lockfd) then
        print('The beacon is locked!')
        return
    end

    exports.updateSettings()

    local updated = os.uptime()

    local callback = function(err, data)
        if (err) then
            console.log(err)
            return
        end

        updated = os.uptime()
        onData(err, data)
    end

    local onPost = function()
        beacon.postData()
    end

    local ret = bluetooth.scan(callback)

    local rssi_interval_timeout = 1000
    local sensor_interval_timeout = 1000
    local monitor_interval_timeout = 5000
    local heartbeat_interval_timeout = 5000
    local register_interval_timeout = 3600000
    local CHECK_INTERVAL  = 2000 -- in 1/1000 second
    local CHECK_TIMEOUT   = 5    -- in second
    local register_state  = false

    local id = getMacAddress()

    -- setInterval(CHECK_INTERVAL, function() 
    --     beacon.clearInvalidBeacons()

    --     local now = os.uptime()
    --     local span = now - updated

    --     --console.log(bluetooth.lbluetooth, span)
    --     if (span > CHECK_TIMEOUT) then
    --         bluetooth.stop()
    --     end

    --     if (not bluetooth.ibluetooth) then
    --         bluetooth.scan(callback)
    --     end
    -- end)
    rpcServer = rpc.server(RPC_PORT, rpcMethods)
    monitor.monitor_init()
    
    utils.async(function()
        while true do
            -- Register
            while not register_state do
                local result = utils.await(beacon.register, id)--register request
                -- console.log(result.error)
                if result.error == nil then
                    register_state = true
                    local res_body = json.parse(result.data)
                    register_interval_timeout = res_body.config.register_interval * 1000
                    rssi_interval_timeout = res_body.config.datapush_interval * 1000
                    sensor_interval_timeout = res_body.config.datapush_interval * 1000
                    monitor_interval_timeout = res_body.config.datapush_interval * 1000
                    heartbeat_interval_timeout = res_body.config.heartbeat_interval * 1000
                    console.log('register success')
                    -- console.log(result)
                    console.log('register_interval: ' .. register_interval_timeout)
                    console.log('datapush_interval: ' .. rssi_interval_timeout)
                    console.log('heartbeat_interval: ' .. heartbeat_interval_timeout)
                else
                    console.log('register fail:' .. result.error)
                    local delay = utils.await(setTimeout, 5000)--register fail delay
                end
            end

            -- Create Interval
            local rssi_interval_id = setInterval(rssi_interval_timeout, onPost)
            local monitor_interval_id = setInterval(monitor_interval_timeout, monitor.monitor_post)
            local heartbeat_interval_id = setInterval(heartbeat_interval_timeout, monitor.heartbeat_post)
            
            local delay = utils.await(setTimeout, register_interval_timeout)

            -- Cancel Interval
            register_state = false
            clearInterval(rssi_interval_id)
            clearInterval(monitor_interval_id)
            clearInterval(heartbeat_interval_id)
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
