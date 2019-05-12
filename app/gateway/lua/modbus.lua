local util  = require('util')
local url 	= require('url')
local fs 	= require('fs')
local path 	= require('path')
local json  = require('json')
local wot   = require('wot')
local modbus = require('lmodbus')

local exports = {}

exports.services = {}

local context = {}

local function readFromModbus(webThing)

    local function initModbus(slave, options)
        options = options or {}
    
        if (not context.device) then
            local deviceName = options.device or 'COM3'
            local baudrate = options.baudrate or 9600
            local dev = modbus.new(deviceName, baudrate)
            if (dev) then
                context.device = dev
    
                dev:connect()
                dev:slave(options.slave or 1)
            end
        end
    end

    local function getPropertyValue(property, result)
        local type = property.type or 0
        local count = property.quantity or 1
        local value = 0
        if (type == 0) then
            if (count == 1) then -- int16
                value = string.unpack('>B', result)

            elseif (count == 2) then -- int32
                value = string.unpack('>I2', result)

            elseif (count == 4) then -- int64
                value = string.unpack('>I4', result)

            end

        elseif (type == 1) then
            if (count == 1) then -- uint16
                value = string.unpack('>B', result)

            elseif (count == 2) then -- uint32
                value = string.unpack('>I2', result)

            elseif (count == 4) then -- uint64
                value = string.unpack('>I4', result)

            end

        elseif (type == 2) then
            if (count == 2) then -- float
                value = string.unpack('>I2', result)

            elseif (count == 4) then -- double
                value = string.unpack('>I4', result)
            end

        elseif (type == 3) then -- string
            return result

        elseif (type == 4) then -- boolean
            return string.unpack('>B', result)

        elseif (type == 5) then -- raw
            return result

        else
            return 0
        end

        if (property.scale and property.scale ~= 1) then
            value = value * property.scale
        end

        if (property.offset and property.offset ~= 0) then
            value = value + property.offset
        end

    end

    local dev = context.device
    if (not dev) then
        initModbus(slave)

        if (not dev) then
            return
        end
    end

    local properties = webThing.modbus.properties;
    for name, property in pairs(properties) do
        local register = property.register
        local count = property.quantity

        if (register >= 0) and (count >= 1) then
            local result = dev:mread(register, count)
            property.value = getPropertyValue(property, result)
        end
    end
end

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
        property.address = value.d or common.d or 0
        property.interval = value.i or common.i or 60
        property.timeout = value.t or common.t or 500
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

    local interval = (options.interval or 60) * 1000
    setInterval(interval, function()
        readFromModbus(webThing)
    end)
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