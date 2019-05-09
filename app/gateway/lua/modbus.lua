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
    device.cpuUsage = getCpuUsage()
    device.currentTime = os.time()
    device.deviceType = 'gateway'
    device.errorCode = 0
    device.firmwareVersion = '1.0'
    device.hardwareVersion = '1.0'
    device.manufacturer = 'TDK'
    device.memoryFree = math.floor(os.freemem() / 1024)
    device.memoryTotal = math.floor(os.totalmem() / 1024)
    device.modelNumber = 'DT02'
    device.powerSources = 0
    device.powerVoltage = 12000
    device.serialNumber = getMacAddress()

    return device
end

local function onRebootDevice()

end

local function getConfigInformation()
    local config = {}

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
        return getConfigInformation()

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
        name = options.name or 'gateway' 
    }

    local mqttUrl = options.mqtt
    local webThing = wot.produce(gateway)
    webThing.secret = options.secret

    -- 
    local action = { input = { type = 'object'} }
    webThing:addAction('bind', action, function(input)
        console.log('device', input);
        local did = webThing.id;

        return { code = 0 }
    end)

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