local app   = require('app')
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

local exports = {}

app.name = 'gateway'

-- ////////////////////////////////////////////////////////////////////////////
-- Web Server

function getThingStatus()
    local wotClient = wot.client
    local things = wotClient and wotClient.things
    local list = {}
    if (things) then
        for did, thing in pairs(things) do 
            local data = {}
            data.id = thing.id
            data.name = thing.name
            data.token = thing.token
            data.deviceId = thing.deviceId
            data.instance = thing.instance
            data.registerExpires = thing.registerExpires
            data.registerInterval = thing.registerInterval
            data.registerState = thing.registerState
            data.registerTime = thing.registerTime
            data.registerUpdated = thing.registerUpdated

            list[did] = data
        end
    end

    return list
end

function createHttpServer()
    local server = httpd.createServer()

    server:get('/status/', function(req, res)
        -- console.log(req.url, req.method)

        local result = {}
        result.rtmp = rtmp.getRtmpStatus()
        result.rtsp = rtsp.getRtspStatus()
        result.things = getThingStatus()

        local body = json.stringify(result)
        res:setHeader("Content-Type", "application/json")
        res:setHeader("Content-Length", #body)
        res:finish(body)
    end)
end

-- ////////////////////////////////////////////////////////////////////////////
--

function exports.notify()
    setInterval(1000 * 15, function()
        -- sendGatewayStatus()
    end)

    setInterval(1000 * 3600, function()
        -- sendGatewayDeviceInformation()
    end)
end

function exports.play(rtmpUrl)
    local urlString = rtmpUrl or 'rtmp://iot.beaconice.cn:1935/live/test'
    local rtmpClient = rtmp.open('test', urlString, { isPlay = true })

    rtmpClient:on('startStreaming', function()
        rtmpClient.isStartStreaming = true
        console.log('startStreaming')
    end)
end

function exports.start()
    exports.rtmp()
    exports.rtsp()
    exports.gateway()
    exports.cameras() 

    createHttpServer()
end

function exports.rtmp()
    rtmp.startRtmpClient()
end

function exports.rtsp()
    local gateway = app.get('gateway')
    local peripherals = gateway and gateway.peripherals
    local cameras = peripherals and peripherals.camera
    for index, options in ipairs(cameras) do
        -- console.log(options)
        rtsp.startRtspClient(rtmp, options)
    end
end

function exports.config()
    console.log('gateway', app.get('gateway'))
    --console.log('modbus', app.get('gateway.peripherals'))
end

function exports.gateway()
    gateway.app = app

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
    local peripherals = gateway and gateway.peripherals
    local list = peripherals and peripherals.modbus

    local did = app.get('did')
    local secret = app.get('secret')
    local mqtt = app.get('mqtt')

    peripherals = app.get('peripherals') or {}
    if (not list) then
        return
    end

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

        -- console.log(options);

        local thing, err = modbus.createThing(options)
        if (err) then
            console.log('createThing', err)
        end

        things[did] = thing
    end

    app.modbusDevices = things
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
    local mqtt = app.get('mqtt')
    local secret = app.get('secret')
    local gateway = app.get('gateway')
    local peripherals = gateway and gateway.peripherals
    local cameras = peripherals and peripherals.camera
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
