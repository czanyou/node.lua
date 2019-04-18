local app   = require('app')
local rtmp  = require('rtmp')
local util  = require('util')
local url 	= require('url')
local fs 	= require('fs')
local path 	= require('path')
local core 	= require('core')
local rtsp  = require('rtsp')
local http  = require('http')
local json  = require('json')
local wot   = require('wot')
local request = require('http/request')
local client  = require('rtmp/client')
local Promise = require('wot/promise')

local session  = require('./session')

local exports = {}

-- ////////////////////////////////////////////////////////////////////////////
-- Notify

local cpuInfo = {}

local function getWotClient()
    return exports.wotClient
end

-- Get the MAC address of localhost 
local function getMacAddress()
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
                list[#list + 1] = item
            end
        end

        ::continue::
    end

    if (#list <= 0) then
    	return
    end

    local item = list[1]
    if (not item.mac) then
    	return
    end

    return util.bin2hex(item.mac)
end

local function getCpuUsage()
    local data = fs.readFileSync('/proc/stat')
    if (not data) then
        return 0
    end

    local list = string.split(data, '\n')
    local d = string.gmatch(list[1], "%d+")

    local totalCpuTime = 0;
    local x = {}
    local i = 1
    for w in d do
        totalCpuTime = totalCpuTime + w
        x[i] = w
        i = i +1
    end

    local totalCpuUsedTime = x[1] + x[2] + x[3] + x[6] + x[7] + x[8] + x[9] + x[10]

    local cpuUsedTime = totalCpuUsedTime - cpuInfo.used_time
    local cpuTotalTime = totalCpuTime - cpuInfo.total_time

    cpuInfo.used_time = math.floor(totalCpuUsedTime) --record
    cpuInfo.total_time = math.floor(totalCpuTime) --record

    if (cpuTotalTime == 0) then
        return 0
    end

    local cpuUserPercent = math.floor(cpuUsedTime / cpuTotalTime * 100)
    return cpuUserPercent
end

local function sendGatewayEventNotify(name, data)
    local event = {}
    event[name] = data

    local wotClient = getWotClient();
    if (wotClient) then
        wotClient:sendEvent(event)
    end
end

local function sendGatewayDeviceInformation()
    local device = {}
    device.manufacturer = 'TDK'
    device.modelNumber = 'DT02'
    device.serialNumber = getMacAddress()
    device.firmwareVersion = '1.0'
    device.hardwareVersion = '1.0'

    local wotClient = getWotClient();
    if (wotClient) then
        wotClient:sendProperty({ device = device })
    end
end

local function sendGatewayStatus()
    local result = {}
    result.memoryFree = math.floor(os.freemem() / 1024)
    result.memoryTotal = math.floor(os.totalmem() / 1024)
    result.cpuUsage = getCpuUsage()

    local wotClient = getWotClient();
    if (wotClient) then
        wotClient:sendStream(result)
    end
end

-- ////////////////////////////////////////////////////////////////////////////
-- Web Server

function getThingStatus()
    local wotClient = exports.wotClient
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
        result.rtmp = getRtmpStatus()
        result.rtsp = getRtspStatus()
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

function exports.notify()
    cpuInfo.used_time = 0;
    cpuInfo.total_time = 0;

    setInterval(1000 * 15, function()
        sendGatewayStatus()
    end)

    setInterval(1000 * 3600, function()
        sendGatewayDeviceInformation()
    end)
end

function exports.play(rtmpUrl)
    local rtmpSession = getRtmpSession()
    rtmpSession.rtmpIsPlay = true

    local urlString = rtmpUrl or 'rtmp://iot.beaconice.cn:1935/live/test'
    local rtmpClient = createRtmpClient('test', urlString)

    rtmpClient:on('startStreaming', function()
        rtmpClient.isStartStreaming = true
        console.log('startStreaming')
    end)
end

function exports.test()
    local urlString = 'rtmp://iot.beaconice.cn:1935/live/test'
    local rtmpClient = createRtmpClient('test', urlString)
end

function exports.start()
    exports.rtmp()
    exports.rtsp()
    exports.register()
end

function exports.rtmp()
    startRtmpClient();
end

function exports.rtsp()
    local config = exports.config()
    local cameras = config.cameras or {}

    for did, camera in pairs(cameras) do
        startRtspClient(did, camera);
    end

    createHttpServer();
end

function exports.config()
    if (app.config) then
        return app.config
    end

    local filename = path.join(util.dirname(), '../config/config.json')
    local filedata = fs.readFileSync(filename)
    local config = json.parse(filedata)

    app.config = config or {}

    if (not config.did) then
        config.did = getMacAddress();
    end

    -- console.log(config)
    return app.config
end

function createCameraThing(did)
    local config = exports.config()

    local camera = { id = did, name = 'camera' }
    local webThing = wot.produce(camera)

    -- play action
    local play = { input = { type = 'object' } }
    webThing:addAction('play', play, function(input)
        console.log('play', 'input', input)

        local url = input and input.url
        local now = process.now()
        local did = webThing.id;
        local rtmpSession = getRtmpSession(did)

        rtmpSession.rtmpUrl = url;
        rtmpSession.lastNotifyTime = now;

        onRtmpSessionTimer(did);

        -- promise
        local promise = Promise.new()
        setTimeout(0, function()
            promise:resolve({ code = 0 })
        end)

        return promise
    end)

    -- stop action
    local stop = { input = { type = 'object' } }
    webThing:addAction('stop', stop, function(input)
        console.log('stop', input);

        local did = webThing.id;
        stopRtmpClient(did, 'stoped');

        -- promise
        local promise = Promise.new()
        setTimeout(0, function()
            promise:resolve({ code = 0 })
        end)

        return promise
    end)

    -- ptz action
    local ptz = { input = { type = 'object'} }
    webThing:addAction('ptz', ptz, function(input)
        console.log('ptz', input);
        local did = webThing.id;

        return { code = 0 }
    end)

    -- preset action
    local ptz = { input = { type = 'object'} }
    webThing:addAction('preset', ptz, function(input)
        console.log('preset', input);
        local did = webThing.id;

        return { code = 0 }
    end)    

    -- play event
    local event = { type = 'object' }
    webThing:addEvent('play', event)

    -- properties
    webThing:addProperty('test', { type = 'number' })

    -- register
    -- console.log('webThing', webThing)

    local url = config.mqtt
    local wotClient = wot.register(url, webThing)

    exports.wotClient = wotClient
end

function createMediaGatewayThing()
    local config = exports.config()
    local gateway = { id = config.did, name = 'gateway' }
    -- console.log('config', config);

    local webThing = wot.produce(gateway)

    -- register
    local url = config.mqtt
    local wotClient = wot.register(url, webThing)
    wotClient:on('register', function(result)
        console.log('register', result)
    end)

    exports.wotClient = wotClient
end

-- 注册 WoT 客户端
function exports.register()
    local config = exports.config()
    local cameras = config.cameras or {}

    createMediaGatewayThing()
    for did, camera in pairs(cameras) do
        createCameraThing(did)
    end

    -- report stream
    exports.notify()
end

app(exports)
