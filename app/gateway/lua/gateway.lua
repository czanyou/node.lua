local util  = require('util')
local url 	= require('url')
local fs 	= require('fs')
local path 	= require('path')
local json  = require('json')
local wot   = require('wot')

local exports = {}

exports.services = {}

local cpuInfo = {
    used_time = 0,
    total_time = 0
}

local function getWotClient()
    return wot.client
end

local function resetCpuUsage() 
    cpuInfo.used_time = 0;
    cpuInfo.total_time = 0;
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
    console.log('onRebootDevice');

    if (exports.rebootTimer) then
        clearTimeout(exports.rebootTimer)
    end

    exports.rebootTimer = setTimeout(1000 * 10, function()
        exports.rebootTimer = nil;
        console.log('reboot timeout');

        process:exit(0);
    end)
end

local function onUpdateFirmware(params)
    console.log('onUpdateFirmware');

    params = params or {}
    -- uri
    -- version
    -- md5sum
    -- size

    if (not exports.services.firmware) then
        exports.services.firmware = {}
    end

    local firmware = exports.services.firmware
    if (params.uri) then
        firmware.uri = params.uri
    end

    if (params.version) then
        firmware.version = params.version
    end

    if (params.md5sum) then
        firmware.md5sum = params.md5sum
    end

    if (params.size) then
        firmware.size = params.size
    end

    if (exports.updateTimer) then
        clearTimeout(exports.updateTimer)
    end

    exports.updateTimer = setTimeout(1000 * 10, function()
        exports.updateTimer = nil;
        console.log('updateTimer');

        os.execute('lpm upgrade > /tmp/upgrade.log &')
    end)
end

local function getFirmwareInformation()
    local firmware = exports.services.firmware or {}
    firmware.state = 0
    firmware.result = 0
    firmware.protocol = 2
    firmware.delivery = 0
    return firmware
end

local function getConfigInformation()
    exports.services.config = exports.app.get('gateway');
    local config = exports.services.config or {}

    return config
end

local function setConfigInformation(config)
    if (not exports.services.config) then
        exports.services.config = {}
    end

    if (config) then
        exports.services.config = config
        exports.app.set('gateway', config)
    end
end

local function processDeviceActions(input)
    console.log('processDeviceActions', input)

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

local function processFirmwareActions(input, webThing)
    console.log('processFirmwareActions', input)

    if (input.update) then
        onUpdateFirmware(input.update);
        return { code = 0 }

    elseif (input.read) then
        return getFirmwareInformation()

    elseif (input.write) then   
        return { code = 0 }

    else
        return { code = 400, error = 'Unsupported methods' }
    end
end

local function processConfigActions(input, webThing)
    -- console.log('processConfigActions', input)

    if (input.read) then
        return getConfigInformation()

    elseif (input.write) then
        setConfigInformation(input.write);
        return { code = 0 }

    else
        return { code = 400, error = 'Unsupported methods' }
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

    local gateway = { 
        id = options.did, 
        url = options.mqtt,
        name = 'gateway',
        actions = {},
        properties = {},
        events = {}
    }

    local webThing = wot.produce(gateway)
    webThing.secret = options.secret

    -- device actions
    webThing:setActionHandler('device', function(input)
        if (input) then
            return processDeviceActions(input, webThing)
            
        else
            return { code = 400, error = 'Unsupported methods' }
        end
    end)

    -- firmware actions
    webThing:setActionHandler('firmware', function(input)
        if (input) then
            return processFirmwareActions(input, webThing)
            
        else
            return { code = 400, error = 'Unsupported methods' }
        end
    end)

    -- config actions
    webThing:setActionHandler('config', function(input)
        if (input) then
            return processConfigActions(input, webThing)
            
        else
            return { code = 400, error = 'Unsupported methods' }
        end
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

    if (not cpuInfo.timer) then
        cpuInfo.timer = setInterval(1000 * 5, function()
            -- console.log('resetCpuUsage')
            resetCpuUsage()
        end);
    end

    return webThing
end

exports.createThing = createMediaGatewayThing

return exports
