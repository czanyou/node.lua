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
    cpuInfo.used_time = 0;
    cpuInfo.total_time = 0;

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
    console.log('config', loadConfig())

    console.log('gateway', app.get('gateway'))

end

function exports.gateway()
    local config = loadConfig()
    app.gateway = gateway.createThing(config)
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
