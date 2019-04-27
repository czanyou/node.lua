local util  = require('util')
local url 	= require('url')
local fs 	= require('fs')
local path 	= require('path')
local json  = require('json')
local wot   = require('wot')

local exports = {}

local cpuInfo = {}

local function getWotClient()
    return wot.client
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
        wotClient:sendEvent(event, exports.gateway)
    end
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

local function sendGatewayDeviceInformation()
    local device = {}
    device.manufacturer = 'TDK'
    device.modelNumber = 'DT02'
    device.serialNumber = getMacAddress()
    device.firmwareVersion = '1.0'
    device.hardwareVersion = '1.0'

    local wotClient = getWotClient();
    if (wotClient) then
        wotClient:sendProperty({ device = device }, exports.gateway)
    end
end

local function sendGatewayStatus()
    local result = {}
    result.memoryFree = math.floor(os.freemem() / 1024)
    result.memoryTotal = math.floor(os.totalmem() / 1024)
    result.cpuUsage = getCpuUsage()

    local wotClient = getWotClient();
    if (wotClient) then
        wotClient:sendStream(result, exports.gateway)
    end
end

local function createMediaGatewayThing(options)
    if (not options) then
        return nil, 'need options'

    elseif (not options.mqtt) then
        return nil, 'need MQTT url option'

    elseif (not options.did) then
        return nil, 'need did option'
    end

    local gateway = { id = options.did, name = 'gateway' }

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

    webThing:setPropertyReadHandler('firmware', function(input)
        console.log('read device', input);
        local did = webThing.id;

        return { firmwareVersion = "1.0" }
    end)

    webThing:setPropertyReadHandler('location', function(input)
        console.log('read device', input);
        local did = webThing.id;

        return { firmwareVersion = "1.0" }
    end)

    -- register
    local cient, err = wot.register(mqttUrl, webThing)
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

exports.createThing = createMediaGatewayThing

return exports
