local app   = require('app')
local util  = require('util')
local url 	= require('url')
local fs 	= require('fs')
local path 	= require('path')
local http  = require('http')
local json  = require('json')
local wot   = require('wot')

local rtmp  = require('../lua/rtmp')
local rtsp  = require('../lua/rtsp')
local modbus = require('../lua/modbus')
local camera  = require('./camera')
local gateway = require('./gateway')

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
            data.deviceId = thing.deviceId
            list[did] = data
        end
    end

    return list
end

function createHttpServer()
    local server = http.createServer(function(req, res)
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

    server:listen(8000, function()

    end)
end

-- ////////////////////////////////////////////////////////////////////////////
--

local function loadConfig()
    if (app.config) then
        return app.config
    end

    local filename = path.join(util.dirname(), '../config/config.json')
    local filedata = fs.readFileSync(filename)
    local config = json.parse(filedata)

    app.config = config or {}

    -- console.log(config)
    return app.config
end

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

function exports.test()
    local urlString = 'rtmp://iot.beaconice.cn:1935/live/test'
    local rtmpClient = rtmp.open('test', urlString)
end

function exports.start()
    exports.rtmp()
    exports.rtsp()
    exports.gateway()
    exports.cameras()
end

function exports.rtmp()
    rtmp.startRtmpClient();
end

function exports.rtsp()
    local config = loadConfig()
    local cameras = config.cameras or {}
    for did, options in pairs(cameras) do
        options.rtmp = rtmp
        rtsp.startRtspClient(did, options);
    end

    createHttpServer();
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
            
        end

        console.log(options);

        local thing, err = modbus.createThing(options)
        if (err) then
            console.log('createThing', err)
        end

        things[did] = thing
    end
    app.modbusDevices = things
end

-- 注册 WoT 客户端
function exports.cameras()
    local config = loadConfig()
    local cameras = config.cameras or {}

    local things = {}
    for did, options in pairs(cameras) do
        options.did = did
        options.mqtt = config.mqtt
        local thing, err = camera.createThing(options)
        if (err) then
            console.log('createThing', err)
        end

        things[did] = thing
    end
    app.cameras = things
end

app(exports)
