local app   = require('app')
local json  = require('json')
local wot   = require('wot')
local http  = require('wot/bindings/http')

local modbus = require('./modbus')
local camera  = require('./camera/camera')
local bluetooth = require('./bluetooth')
local device = require('./device')

local exports = {}

-- ////////////////////////////////////////////////////////////////////////////
-- Web Server

-- Things status
local function getThingsStatus()
    local wotClient = wot.client
    local things = wotClient and wotClient.things
    local list = {}
    if (not things) then
        return list
    end

    for did, thing in pairs(things) do
        local data = {}
        data.id = thing.id
        data.name = thing.name
        data.token = thing.token
        data.deviceId = thing.deviceId

        data.register = {}
        data.register.expires = thing.register.expires
        data.register.interval = thing.register.interval
        data.register.state = thing.register.state
        data.register.time = thing.register.time
        data.register.updated = thing.register.updated

        if (thing.getStatus) then
            thing.status = thing:getStatus()
        end

        list[did] = data
    end

    return list
end

-- Client status
local function getAllStatus(req, res)
    -- console.log(req.url, req.method)

    local result = {}
    result.media = camera.getStatus()
    result.things = getThingsStatus()

    if (app.cameras) then
        result.cameras = {}
        for did, thing in pairs(app.cameras) do
            result.cameras[did] = thing:getStatus()
        end
    end

    local body = json.stringify(result)
    res:set("Content-Type", "application/json")
    res:set("Content-Length", #body)
    res:finish(body)
end

-- Data LED light state timer
local function startLedTimer()
    setInterval(1000, function()
        local state = 'off'
        local ret = bluetooth:dataStatus() or modbus:isDataReady()
        if ret == 1 then
            state = 'on'
        end

        device.setLEDStatus("blue", state)
    end)
end

-- ////////////////////////////////////////////////////////////////////////////
--

function exports.start()
    if (app.lock()) then
        exports.cameras()
        exports.modbus()
        exports.bluetooth()
        exports.http()

        startLedTimer()
    end
end

function exports.http()
    local server = http.createServer()
    app.httpServer = server

    server:get('/status/', getAllStatus)
end

function exports.bluetooth()
    bluetooth.app = app

    local did = app.get('did')
    local secret = app.get('secret')
    local mqtt = app.get('mqtt')

    local gateway = app.get('gateway')
    local list = gateway and gateway.bluetooth
    if (not list) then
        return
    end

    local things = {}
    for _, options in ipairs(list) do
        options.clientId = "lnode-" .. did
        options.mqtt = mqtt
        options.secret = secret

        -- console.log(options);
        local thing = bluetooth.createBluetooth(options)

        things[options.did] = thing
    end

    app.bluetoothDevices = things
end

function exports.modbus()
    modbus.app = app

    local gateway = app.get('gateway')
    local list = gateway and gateway.modbus
    if (not list) then
        return
    end

    local did = app.get('did')
    local secret = app.get('secret')
    local mqtt = app.get('mqtt')
    local peripherals = app.get('peripherals') or {}

    local things = {}
    for _, options in ipairs(list) do
        options.gateway = did
        options.mqtt = mqtt
        options.secret = secret

        local config = peripherals[options.did]
        if (config) then
            options.properties = config.p
            options.modbus = config.f
        end

        console.log(options);

        local thing, err = modbus.createModbus(options)
        if (err) then
            console.log('createThing', err)
        end

        things[options.did] = thing
    end

    app.modbusDevices = things
end

-- Create camera things
function exports.cameras()
    camera.app = app

    local mqtt = app.get('mqtt')
    local secret = app.get('secret')
    local gateway = app.get('gateway')
    local cameras = gateway and gateway.cameras
    if (not cameras) then
        return
    end

    -- Camera thing options
    -- `options.did` Camera Device ID
    -- `options.mqtt` MQTT URL
    -- `options.secret` register secret
    local things = {}
    for _, options in ipairs(cameras) do
        options.mqtt = mqtt

        if (not options.secret) then
            options.secret = secret
        end

        -- console.log('cameras', options)
        local thing, err = camera.createThing(options)
        if (err) then
            console.log('createThing', err)
        end

        things[options.did] = thing
    end

    app.cameras = things
end

function exports.test(type, ...)
    local test = require('./test')

    if (not type) then
        print("Available tests: version")

    elseif (type == 'version') then
        test.version()

    elseif (type == 'led') then
        test.led()

    elseif (type == 'button') then
        test.button()

    elseif (type == 'bluetooth') then
        test.bluetooth()

    elseif (type == 'update') then
        test.update()

    elseif (type == 'register') then
        test.register()

    elseif (type == 'dhcp') then
        test.dhcp()

    elseif (type == 'onvif') then
        camera.onvif(...)

    elseif (type == 'config') then
        console.log('gateway', app.get('gateway'))
    end
end

function exports.init()
    print('WoT Cloud Gateway')
    print('Usage: ')
    print('  lpm gateway start')
    print('  lpm gateway test ...')
end

app(exports)
