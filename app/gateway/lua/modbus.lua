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

local function initModbusProperties(options, webThing)
    -- console.log(options.properties);
    -- console.log(options.modbus);

    local common = options.modbus or {}

    webThing.modbus = {}
    webThing.modbus.properties = {}
    local properties = webThing.modbus.properties;

    for name, value in pairs(options.properties) do
        local property = {}
        properties[name] = property
        property.address = common.d or 0
        property.interval = common.i or 60
        property.timeout = common.t or 500
        property.register = value.a or 0
        property.quantity = value.quantity or 1
        property.scale = value.s or 1
        property.offset = value.o or 0
        property.code = value.c or 0x03
        property.type = value.y or 0
        property.flags = value.f or 0
        property.fixed = value.x or 0
        property.value = 0

        local property = {}
        property.value = 0
        webThing:addProperty(name, property);
    end

    console.log(webThing.properties);
end

local function processReadAction(input, webThing)
    local properties = webThing.modbus.properties;
    local result = {}

    for name, property in pairs(options.properties) do
        result[name] = property.value or 0
    end

    console.log(properties, result);

    return result
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

    initModbusProperties(options, webThing)

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

    local action = { input = { type = 'object'} }
    webThing:addAction('read', action, function(input)
        console.log('read', input);
        return processReadAction(input, webThing)
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