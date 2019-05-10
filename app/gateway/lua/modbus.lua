local util  = require('util')
local url 	= require('url')
local fs 	= require('fs')
local path 	= require('path')
local json  = require('json')
local wot   = require('wot')

local exports = {}

exports.services = {}

local function getDeviceInformation()
    local device = {}
    device.deviceType = 'modbus'
    device.errorCode = 0
    device.firmwareVersion = '1.0'
    device.hardwareVersion = '1.0'
    device.manufacturer = 'MODBUS'
    device.modelNumber = 'MODBUS'

    return device
end

local function onRebootDevice()

end

local function getConfigInformation(input, webThing)
    local peripherals = exports.app.get('peripherals') or {}
    local config = peripherals[webThing.id] or {}

    return config
end

local function setConfigInformation(config)
    local config = {}

    return config
end

local function processDeviceActions(input)
    if (input.reboot) then
        onRebootDevice(input.reboot);
        return { code = 0 }

    elseif (input.reset) then
        return { code = 0 }

    elseif (input.read) then
        return getDeviceInformation()

    elseif (input.write) then   
        return { code = 0 }

    else
        return { code = 400, error = 'Unsupported methods' }
    end
end

local function processConfigActions(input, webThing)
    if (input.read) then
        return getConfigInformation(input.read, webThing)

    elseif (input.write) then
        setConfigInformation(input.write);
        return { code = 0 }

    else
        return { code = 400, error = 'Unsupported methods' }
    end
end

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
        name = options.name or 'modbus' 
    }

    local mqttUrl = options.mqtt
    local webThing = wot.produce(gateway)
    webThing.secret = options.secret

    -- device actions
    local action = { input = { type = 'object'} }
    webThing:addAction('device', action, function(input)
        if (input) then
            return processDeviceActions(input, webThing)
            
        else
            return { code = 400, error = 'Unsupported methods' }
        end
    end)

    -- config actions
    local action = { input = { type = 'object'} }
    webThing:addAction('config', action, function(input)
        if (input) then
            return processConfigActions(input, webThing)
            
        else
            return { code = 400, error = 'Unsupported methods' }
        end
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