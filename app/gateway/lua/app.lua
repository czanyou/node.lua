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
    local cameras = gateway and gateway.cameras
    if (not cameras) then
        return
    end

    for index, options in ipairs(cameras) do
        -- console.log(options)
        rtsp.startRtspClient(rtmp, options)
    end
end

function exports.config()
    console.log('gateway', app.get('gateway'))
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
    camera.rtmp = rtmp
    
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
