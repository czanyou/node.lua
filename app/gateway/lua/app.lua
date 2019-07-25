local app   = require('app')
local json  = require('json')
local wot   = require('wot')

local httpd   = require('wot/bindings/http')

local rtmp  = require('./rtmp')
local rtsp  = require('./rtsp')
local modbus = require('./modbus')
local camera  = require('./camera')
local bluetooth = require('./bluetooth')
local button = require('./button')

local exports = {}

-- ////////////////////////////////////////////////////////////////////////////
-- Web Server

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
        data.instance = thing.instance

        data.register = {}
        data.register.expires = thing.registerExpires
        data.register.interval = thing.registerInterval
        data.register.state = thing.registerState
        data.register.time = thing.registerTime
        data.register.updated = thing.registerUpdated

        list[did] = data
    end
    
    return list
end

local function createHttpServer()
    local server = httpd.createServer()
    app.httpServer = server

    server:get('/status/', function(req, res)
        -- console.log(req.url, req.method)

        local result = {}
        result.rtmp = rtmp.getRtmpStatus()
        result.rtsp = rtsp.getRtspStatus()
        result.things = getThingsStatus()

        local body = json.stringify(result)
        res:set("Content-Type", "application/json")
        res:set("Content-Length", #body)
        res:finish(body)
    end)
end

local function runningStateindex()
    setInterval(1000, function()
        local ret = bluetooth:dataStatus() or modbus:dataStatus()
        if ret == 1 then
            button.setLEDStatus("blue", "on")
        else
            button.setLEDStatus("blue", "off")
        end
    end)
end

-- ////////////////////////////////////////////////////////////////////////////
--

function exports.play(rtmpUrl)
    local urlString = rtmpUrl or 'rtmp://iot.beaconice.cn/live/test'
    local rtmpClient = rtmp.open('test', urlString, { isPlay = true })

    rtmpClient:on('startStreaming', function()
        rtmpClient.isStartStreaming = true
        console.log('startStreaming')
    end)
end

function exports.start()
    exports.rtmp()
    exports.rtsp()
    exports.cameras()
    exports.modbus()
    exports.bluetooth()
    exports.http()

    runningStateindex()
end

function exports.http()
    createHttpServer()
end

function exports.bluetooth()
    bluetooth.app =app
    -- local options = {}
    local did = app.get('did')
    local secret = app.get('secret')
    local mqtt = app.get('mqtt')

    local gateway = app.get('gateway')
    console.log('start bluetooth')
    local list = gateway and gateway.bluetooth
    if (not list) then
        return
    end
    console.log('start bluetooth')
    console.log(list)
     
    local things = {}
    for index, options in ipairs(list) do
        console.log(index);
        options.clientId = "lnode-" .. did
        options.mqtt = mqtt
        options.secret = secret

        console.log(options);
        local thing = bluetooth.createBluetooth(options)

        things[options.did] = thing
    end

    app.bluetoothDevices = things
end

-- start RTMP push client
function exports.rtmp()
    rtmp.startRtmpClient()
end

-- start RTSP client
function exports.rtsp()
    -- gateway.cameras
    local gateway = app.get('gateway')
    local cameras = gateway and gateway.cameras
    if (not cameras) then
        return
    end

    -- RTSP camera options
    -- `options.did` Device ID
    -- `options.url` RTSP URL
    -- `options.username` Username
    -- `options.password` Password
    for index, options in ipairs(cameras) do
        rtsp.startRtspClient(rtmp, options)
    end
end

function exports.config()
    console.log('gateway', app.get('gateway'))
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
    for index, options in ipairs(list) do
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
    camera.rtmp = rtmp
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
    for index, options in ipairs(cameras) do
        options.mqtt = mqtt
        options.secret = secret

        -- console.log('cameras', options)
        local thing, err = camera.createThing(options)
        if (err) then
            console.log('createThing', err)
        end

        things[options.did] = thing
    end

    app.cameras = things
end

app(exports)
