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

local function getWotClient()
    return wot.client
end

local function createCameraThing(options)
    if (not options) then
        return nil, 'need options'

    elseif (not options.mqtt) then
        return nil, 'need MQTT url option'

    elseif (not options.did) then
        return nil, 'need did option'

    elseif (not options.rtmp) then
        console.log('need rtmp option')
    end

    local mqttUrl = options.mqtt
    local did = options.did
    local rtmp = options.rtmp

    local camera = { id = did, name = 'camera' }
    local webThing = wot.produce(camera)

    webThing.secret = options and options.secret

    -- play action
    local play = { input = { type = 'object' } }
    webThing:addAction('play', play, function(input)
        -- console.log('play', 'input', input)

        local url = input and input.url
        local did = webThing.id;

        local promise = Promise.new()
        if (not url) then
            setTimeout(0, function()
                promise:resolve({ code = 400, error = "Invalid RTMP URL" })
            end)
            return promise
        end

        if (rtmp) then
            rtmp.publishRtmpUrl(did, url);
        end

        -- promise
        
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
        if (rtmp) then
            rtmp.stopRtmpClient(did, 'stoped');
        end

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
        local did = webThing.id;
        console.log('ptz', did, input);

        if (input and input.start) then
            local direction = tonumber(input.start.direction)
            local speed = input.start.speed or 1

            if direction and (direction >= 0) and (direction <= 9) then
                return { code = 0 }
            else 
                return { code = 400, error = 'Invalid direction' }
            end

        elseif (input and input.stop) then
            return { code = 0 }
            
        else
            return { code = 400, error = 'Unsupported methods' }
        end

        return { code = 0 }
    end)

    -- preset action
    local preset = { input = { type = 'object'} }
    webThing:addAction('preset', preset, function(input)
        console.log('preset', input);
        local did = webThing.id;

        local getIndex = function(input, name)
            local index = math.floor(tonumber(input[name].index))
            if index and (index > 0 and index <= 128) then
                return index
            end
        end

        if (input and input.set) then
            local index = getIndex(input, 'set')
            if index then
                return { code = 0 }
            else
                return { code = 400, error = "Invalid preset index" }
            end

        elseif (input and input['goto']) then
            local index = getIndex(input, 'goto')
            if index then
                return { code = 0 }
            else
                return { code = 400, error = "Invalid preset index" }
            end

        elseif (input and input.remove) then
            local index = getIndex(input, 'remove')
            if index then
                return { code = 0 }
            else
                return { code = 400, error = "Invalid preset index" }
            end

        elseif (input and input.list) then
            return { code = 0, presets = { { index = 1 }, { index = 2 } } }

        else
            return { code = 400, error = 'Unsupported methods' }
        end

        return { code = 0 }
    end)

    -- device:reboot action
    local action = { input = { type = 'object'} }
    webThing:addAction('device', action, function(input)
        console.log('device', input);
        local did = webThing.id;

        if (input and input.reboot) then
            return { code = 0 }

        elseif (input and input.reset) then
            return { code = 0 }

        else
            return { code = 400, error = 'Unsupported methods' }
        end

        return { code = 0 }
    end)

    -- firmware:update action
    local action = { input = { type = 'object'} }
    webThing:addAction('firmware', action, function(input)
        console.log('firmware', input);
        local did = webThing.id;

        if (input and input.update) then
            return { code = 0 }
        else
            return { code = 400, error = 'Unsupported methods' }
        end
    end)

    -- properties
    webThing:addProperty('device', { type = 'service' })
    webThing:addProperty('firmware', { type = 'service' })
    webThing:addProperty('location', { type = 'service' })
    webThing:addProperty('statistics', { type = 'service' })
    webThing:addProperty('connectivity', { type = 'service' })

    webThing:setPropertyReadHandler('device', function(input)
        console.log('read device', input);
        local did = webThing.id;
        return { 
            manufacturer = "TDK",
            modelNumber = "DT01",
            serialNumber = did,
            hardwareVersion = "1.0",
            memoryTotal = 1024,
            memoryFree = 1024,
            cpuUsage = 0,
            firmwareVersion = "1.0" 
        }
    end)

    webThing:setPropertyReadHandler('firmware', function(input)
        local did = webThing.id;
        local firmware = webThing.properties['firmware'];
        if (firmware and firmware.value) then
            return firmware.value
        end

        return {
            uri = "",
            state = "",
            result = 0,
            name = "",
            version = "1.0" 
        }
    end)

    webThing:setPropertyWriteHandler('firmware', function(input)
        console.log('write firmware', input);
        local did = webThing.id;
        local firmware = webThing.properties['firmware'];
        if (firmware) then
            if (not firmware.value) then
                firmware.value = {}
            end

            if (input.uri) then
                firmware.value.uri = uri
            end

            if (input.name) then
                firmware.value.name = name
            end

            if (input.version) then
                firmware.value.version = version
            end
        end

        return 0
    end)   

    webThing:setPropertyReadHandler('connectivity', function(input)
        local did = webThing.id;
        return { 
            signalStrength = -92,
            linkQuality = 2,
            ip = "192.168.0.100",
            router = "192.168.0.1",
            utilization = 0,
            apn = "internet",
        }
    end)

    webThing:setPropertyReadHandler('location', function(input)
        local did = webThing.id;
        return { 
            latitude = 0,
            longitude = 0,
            atitude = 0,
            radius = 0,
            timestamp = 0,
            speed = 0
        }
    end)

    webThing:setPropertyReadHandler('statistics', function(input)
        local did = webThing.id;
        return { 
            txPackets = 0,
            rxPackets = 0,
            txBytes = 0,
            rxBytes = 0,
            maxMessageSize = 0,
            avgMessageSize = 0,
            period = 0
        }
    end)    

    -- play event
    local event = { type = 'object' }
    webThing:addEvent('play', event)

    -- register
    -- console.log('webThing', webThing)
    local client, err = wot.register(mqttUrl, webThing)
    if (err) then
        console.log(err)
    end

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
