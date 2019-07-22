local app   = require('app/init')
local util  = require('util')
local url 	= require('url')
local fs 	= require('fs')
local path 	= require('path')
local http  = require('http')
local json  = require('json')
local wot   = require('wot')

local httpd   = require('wot/bindings/http')

local rtmp  = require('./rtmp')
local rtsp  = require('./rtsp')
local modbus = require('./modbus')
local camera  = require('./camera')
local gateway = require('./gateway')
local log = require('./log')
local bluetooth = require('./bluetooth')
local button = require('./button')

local exports = {}

-- ////////////////////////////////////////////////////////////////////////////
-- Web Server

function getThingsStatus()
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

function createHttpServer()
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

-- ////////////////////////////////////////////////////////////////////////////
--

function exports.play(rtmpUrl)
    local urlString = rtmpUrl or 'rtmp://iot.beaconice.cn:1935/live/test'
    local rtmpClient = rtmp.open('test', urlString, { isPlay = true })

    rtmpClient:on('startStreaming', function()
        rtmpClient.isStartStreaming = true
        console.log('startStreaming')
    end)
end

local function runningStateindex()
    setInterval(1000,function()
        button.ledSwitch("green","toggle")

        local ret = wot.isConnected()
        if ret == 1 then
            button.ledSwitch("yellow","on")
        else
            button.ledSwitch("yellow","off")
        end

        ret = bluetooth:dataStatus() or modbus:dataStatus()
        -- console.log(ret)
        if ret == 1 then
            button.ledSwitch("blue","on")
        else
            button.ledSwitch("blue","off")
        end
    
    end)
end



function exports.start()

    console.log("start")
    
    exports.rtmp()
    exports.rtsp()
    -- exports.gateway()
    exports.cameras() 
    exports.modbus()
    exports.bluetooth()
    exports.button()

    createHttpServer()
    runningStateindex()
end

function exports.button()
    console.log("app check button")
    button.checkButton(1000)

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
        

        options.mqtt = mqtt
        options.secret = secret

        console.log(options);
        local thing = bluetooth.createBluetooth(options)

        things[options.did] = thing
    end

    app.bluetoothDevices = things
end

function exports.rtmp()
    rtmp.startRtmpClient()
end

function exports.rtsp()
    -- gateway.cameras
    local gateway = app.get('gateway')
    local cameras = gateway and gateway.cameras
    if (not cameras) then
        return
    end

    -- options
    -- - `did` Device ID
    -- - `url` RTSP URL
    -- - `username` Username
    -- - `password` Password
    for index, options in ipairs(cameras) do
        rtsp.startRtspClient(rtmp, options)
    end
end

function exports.config()
    console.log('gateway', app.get('gateway'))
end

function exports.gateway()
    gateway.app = app
    
    -- options
    -- - did
    -- - mqtt
    -- - secret
    local options = {}
    options.did = app.get('did')
    options.mqtt = app.get('mqtt')
    options.secret = app.get('secret')
    app.gateway = gateway.createThing(options)

    log.init(app.gateway)
end

function exports.test()
    
end

function exports.modbus()
    modbus.app = app

    local gateway = app.get('gateway')
    local list = gateway and gateway.modbus
    
    
    local did = app.get('did')
    local secret = app.get('secret')
    local mqtt = app.get('mqtt')

    local peripherals = app.get('peripherals') or {}
    console.log(peripherals);
    if (not list) then
        return
    end

    console.log(list);
    local things = {}
    for index, options in ipairs(list) do
        console.log(index);
        console.log(options);
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

    app.modbusDevices = thing
end

function exports.server()
    gateway.app = app

    local options = {}
    options.did = app.get('did')
    options.mqtt = app.get('mqtt')
    options.secret = app.get('secret')
    app.gateway = gateway.createThing(options)

    createHttpServer()
end

-- 注册 WoT 客户端
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
