local app       = require('app')
local utils     = require('utils')
local fs        = require('fs')
local path      = require('path')
local json      = require('json')

local bluetooth = require('device/bluetooth')
local rpc       = require('ext/rpc')

local ibeacon   = require('beacon')
local device    = require('device')

local SCAN_RESPONSE = 0x04
local RPC_PORT      = 38888

local function onData(err, data)
    if (not data) then
        return

    elseif data:byte(6) == SCAN_RESPONSE then
        return
    end

    --console.printBuffer(data)
 
    local message = ibeacon.parseBeaconMessage(data)
    if (message == nil) then
        return
    end

    setTimeout(0, function()
        ibeacon.handleMessage(message)
    end)
end

-------------------------------------------------------------------------------
-- 

local rpcMethods = {}
local rpcServer  = nil

function rpcMethods:delete( )
    
end

function rpcMethods:getBeacons()
    return ibeacon.getList()
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
    local list = getInterfaces() or {}
    if (#list < 1) then
        return nil

    elseif (#list == 1) then
        return list[1].mac
    end

    for _, item in ipairs(list) do
        if (item.name == 'wlp2s0') then
            return item.mac
        end
    end

    return list[1].mac
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

    ibeacon.settings = settings
end

function exports.info()
    exports.updateSettings()
    local mac = getMacAddress()

    ibeacon.settings.id = mac

    print("Settings:\n====== ======")
    for k, v in pairs(ibeacon.settings) do
        if (v == '') then v = '-' end
        print(" " .. string.padRight(k, 10), v or '-')
    end

    print('------ ------\n')

    ibeacon.register(mac, function(err, result)
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
        ibeacon.postData()
    end

    local ret = bluetooth.scan(callback)  

    local REPORT_INTERVAL = 1000
    local CHECK_INTERVAL  = 2000 -- in 1/1000 second
    local CHECK_TIMEOUT   = 5    -- in second

    timeout = timeout or REPORT_INTERVAL
    setInterval(timeout, onPost)
    setInterval(CHECK_INTERVAL, function() 
        ibeacon.clearInvalidBeacons()

        local now = os.uptime()
        local span = now - updated

        --console.log(bluetooth.lbluetooth, span)
        if (span > CHECK_TIMEOUT) then
            bluetooth.stop()
        end

        if (not bluetooth.ibluetooth) then
            bluetooth.scan(callback)
        end
    end)
    rpcServer = rpc.server(RPC_PORT, rpcMethods)

    local id = getMacAddress()
    ibeacon.register(id, function(err, result)
        --console.log(err, result)
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
