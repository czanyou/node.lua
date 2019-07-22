local app   = require('app')
local util  = require('util')
local url 	= require('url')
local fs 	= require('fs')
local path 	= require('path')
local http  = require('http')
local json  = require('json')
local wot   = require('wot')

local Promise = require('wot/promise')

local exports = {}

exports.services = {}

local function onDeviceRead()
    local device = {}
    device.deviceType = 'camera'
    device.errorCode = 0
    return device
end

local function onDeviceActions(input, webThing)
    if (not input) then
        return { code = 400, error = 'Unsupported methods' }
   
    elseif (input.reset) then
        return { code = 0 }

    elseif (input.read) then
        return onDeviceRead(input.read, webThing)

    else
        return { code = 400, error = 'Unsupported methods' }
    end
end

local function onConfigRead(input, webThing)
    local config = exports.app.get('peripherals');
    config = config and config[webThing.id]

    return config
end

local function onConfigWrite(input, webThing)
    local config = exports.app.get('peripherals') or {}
    if (input) then
        config[webThing.id] = input
        exports.app.set('peripherals', config)
    end

    return { code = 0 }
end

local function onConfigActions(input, webThing)
    if (not input) then
        return { code = 400, error = 'Unsupported methods' }

    elseif (input.read) then
        return onConfigRead(input.read, webThing)

    elseif (input.write) then
        return onConfigWrite(input.write, webThing);

    else
        return { code = 400, error = 'Unsupported methods' }
    end
end

local function onPtzStart(direction, speed)
    return { code = 0 }
end

local function onPtzStop()
    return { code = 0 }
end

local function onPtzActions(input, webThing)
    if (input.start) then
        local direction = tonumber(input.start.direction)
        local speed = input.start.speed or 1

        if direction and (direction >= 0) and (direction <= 9) then
            return onPtzStart(direction, speed)
        else 
            return { code = 400, error = 'Invalid direction' }
        end

    elseif (input.stop) then
        return onPtzStop()
        
    else
        return { code = 400, error = 'Unsupported methods' }
    end
end

local function onPresetActions(input, webThing)
    local did = webThing.id;

    local getIndex = function(input, name)
        local index = math.floor(tonumber(input[name].index))
        if index and (index > 0 and index <= 128) then
            return index
        end
    end

    if (input.set) then
        local index = getIndex(input, 'set')
        if index then
            return { code = 0 }
        else
            return { code = 400, error = "Invalid preset index" }
        end

    elseif (input['goto']) then
        local index = getIndex(input, 'goto')
        if index then
            return { code = 0 }
        else
            return { code = 400, error = "Invalid preset index" }
        end

    elseif (input.remove) then
        local index = getIndex(input, 'remove')
        if index then
            return { code = 0 }
        else
            return { code = 400, error = "Invalid preset index" }
        end

    elseif (input.read) then
        return { code = 0, presets = { { index = 1 }, { index = 2 } } }

    else
        return { code = 400, error = 'Unsupported methods' }
    end
end

local function onPlayAction(input, webThing)
    local url = input and input.url
    local did = webThing.id;

    console.log('play', did, url)

    local promise = Promise.new()
    if (not url) then
        setTimeout(0, function()
            promise:resolve({ code = 400, error = "Invalid RTMP URL" })
        end)
        return promise
    end

    local rtmp = exports.rtmp;
    if (rtmp) then
        rtmp.publishRtmpUrl(did, url);
    end

    -- promise
    setTimeout(0, function()
        promise:resolve({ code = 0 })
    end)

    return promise
end

local function onStopAction(input, webThing)
    console.log('stop', input);

    local did = webThing.id;

    local rtmp = exports.rtmp;
    if (rtmp) then
        rtmp.stopRtmpClient(did, 'stoped');
    end

    -- promise
    local promise = Promise.new()
    setTimeout(0, function()
        promise:resolve({ code = 0 })
    end)

    return promise
end

local function createCameraThing(options)
    if (not options) then
        return nil, 'need options'

    elseif (not options.mqtt) then
        return nil, 'need MQTT url option'

    elseif (not options.did) then
        return nil, 'need did option'
    end

    local camera = { 
        ['@context'] = "https://iot.beaconice.cn/schemas",
        ['@type'] = 'Camera',
        id = options.did, 
        url = options.mqtt,
        name = 'camera',
        actions = {
            play = { ['@type'] = 'play' },
            stop = { ['@type'] = 'stop' },
        },
        properties = {},
        events = {},
        version = {
            instance = '1.0'
        }
    }

    local webThing = wot.produce(camera)
    webThing.secret = options.secret

    -- play action
    webThing:setActionHandler('play', function(input)
        return onPlayAction(input, webThing)
    end)

    -- stop action
    webThing:setActionHandler('stop', function(input)
        return onStopAction(input, webThing)
    end)

    -- ptz action
    webThing:setActionHandler('ptz', function(input)
        return onPtzActions(input, webThing)
    end)

    -- preset action
    webThing:setActionHandler('preset', function(input)
        return onPresetActions(input, webThing)
    end)

    -- device actions
    webThing:setActionHandler('device', function(input)
        return onDeviceActions(input, webThing)
    end)

    -- config actions
    webThing:setActionHandler('config', function(input)
        return onConfigActions(input, webThing)
    end)

    -- register
    webThing:expose()

    webThing:on('register', function(response)
        local result = response and response.result
        if (result and result.code and result.error) then
            console.log('register', 'error', response.did, result)

        elseif (result.token) then
            console.log('register', response.did, result.token)
        end
    end)

    return webThing
end

exports.createThing = createCameraThing

return exports
