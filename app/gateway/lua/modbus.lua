local util  = require('util')
local url 	= require('url')
local fs 	= require('fs')
local path 	= require('path')
local json  = require('json')
local wot   = require('wot')

local exports = {}

local function createModbusThing(options)
    if (not options) then
        return nil, 'need options'

    elseif (not options.mqtt) then
        return nil, 'need MQTT url option'

    elseif (not options.did) then
        return nil, 'need did option'
    end

    local gateway = { 
        id = options.did, 
        name = options.name or 'gateway' 
    }

    local mqttUrl = options.mqtt
    local webThing = wot.produce(gateway)
    webThing.secret = options.secret

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

    -- properties
    webThing:addProperty('device', { type = 'service' })

    webThing:setPropertyReadHandler('device', function(input)
        console.log('read device', input);
        local did = webThing.id;

        return { firmwareVersion = "1.0" }
    end)

    webThing:setPropertyWriteHandler('device', function(input)
        console.log('write device', input);
        local did = webThing.id;

        return 0
    end)   

    -- register
    local wotClient, err = wot.register(mqttUrl, webThing)
    if (err) then
        return nil, err
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

exports.createThing = createModbusThing

return exports