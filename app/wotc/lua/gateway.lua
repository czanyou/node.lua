local util  = require('util')
local url 	= require('url')
local fs 	= require('fs')
local path 	= require('path')
local json  = require('json')
local wot   = require('wot')
local Promise  = require('wot/promise')
local exec  = require('child_process').exec

local exports = {}

exports.services = {}

local cpuInfo = {
    used_time = 0,
    total_time = 0
}

local SHELL_RUN_TIMEOUT = 2000
local isWindows = (os.platform() == 'win32')

local function shellGetEnvironment()
    return { hostname = hostname, path = process.cwd() }
end

function shellExecute(cmd, callback, timeout)
	local result = {}

    if (not isWindows) then
        -- 重定向 stderr(2) 输出到 stdout(1)
        cmd = cmd .. " 2>&1"
    end

    -- [[
    local options = { timeout = (timeout or SHELL_RUN_TIMEOUT), env = process.env }

    exec(cmd, options, function(err, stdout, stderr)
        --console.log(err, stdout, stderr)
        if (not stdout) or (stdout == '') then
            stdout = stderr
        end

        if (err and err.message) then
            stdout = err.message .. ': \n\n' .. stdout
        end

        os.execute(cmd)

        result.output = stdout
        result.environment = shellGetEnvironment()

        callback(result)
    end)
    --]]
end

function shellChdir(dir, callback)
    local result = {}

    -- console.log('dir', dir)

    if (type(dir) == 'string') and (#dir > 0) then
        local cwd = process.cwd()
        local newPath = dir
        if (not dir:startsWith('/')) then
            newPath = path.join(cwd, dir)
        end
        --console.log(dir, newPath)

        if newPath and (newPath ~= cwd) then
            local ret, err = process.chdir(newPath)
            --console.log(dir, newPath, ret, err)
            if (not ret) then
                result.output = err or 'Unable to change directory'
            end
        end
    end

    result.environment = shellGetEnvironment()

    setImmediate(function()
        callback(result)
    end)
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

-- Read device information
local function onDeviceRead(input, webThing)
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

-- Reboot the device
-- @param input {object}
--  - delay {number} 大于 0 表示延时重启，小于等于 0 表示取消重启
local function onDeviceReboot(input, webThing)
    local delay = tonumber(input and input.delay)

    if (exports.rebootTimer) then
        clearTimeout(exports.rebootTimer)
    end

    if (delay and delay > 0) then
        if (delay < 5) then
            delay = 5
        end

        exports.rebootTimer = setTimeout(1000 * delay, function()
            exports.rebootTimer = nil;
            console.log('reboot timeout');
            process:exit(0);
        end)
        return { code = 0, delay = delay, message = 'Device will reboot' }

    else 
        return { code = 0, delay = delay, message = 'reboot is cancel' }
    end
end

-- Factory Reset
local function onDeviceReset(input, webThing)
    local type = tonumber(input and input.type)
    return { code = 0, type = type, message = 'device reset' }
end

-- Set Date & Time
local function onDeviceWrite(input, webThing)
    -- console.log('onDeviceWrite');
    if (input) then
        -- currentTime
        -- UTCOffset
        -- timezone
    end

    return { code = 0, message = 'write' }
end

local function onDeviceExecute(input, webThing)
    -- console.log('onDeviceExecute', input);

    local promise = Promise.new()

    if (input and input:startsWith('cd ')) then
        local dir = input:sub(4)
        shellChdir(dir, function(result)
            -- console.log('shellChdir', dir, result)
            promise:resolve(result)
        end)

    else
        shellExecute(input, function(result)
            -- console.log('shellExecute', input, result)
            promise:resolve(result)
        end)
    end

    return promise
end

local function onDeviceActions(input, webThing)
    -- console.log('onDeviceActions', input);

    if (not input) then
        return { code = 400, error = 'Unsupported methods' }

    elseif (input.reboot) then
        return onDeviceReboot(input.reboot, webThing);

    elseif (input.reset) then
        return onDeviceReset(input.reset, webThing)

    elseif (input.factoryReset) then
        return onDeviceReset(input.factoryReset, webThing)

    elseif (input.read) then
        return onDeviceRead(input.read, webThing)

    elseif (input.write) then
        return onDeviceWrite(input.write, webThing)

    elseif (input.execute) then
        return onDeviceExecute(input.execute, webThing)

    else
        return { code = 400, error = 'Unsupported methods' }
    end
end

local function onFirmwareRead(input, webThing)
    console.error('onFirmwareRead');

    local base = exports.app.get('base') or '';
    local did = exports.app.get('did') or '';
    local uri = base .. 'device/firmware/file?did=' .. did;

    local rootPath = exports.app.rootPath
    local filename = path.join(rootPath, 'update/status.json')
    local filedata = fs.readFileSync(filename)
    local status = {}
    if (filedata) then
        status = json.parse(filedata) or {}
    end

    local firmware = exports.services.firmware or {}
    firmware.uri = uri
    firmware.state = status.state or 0
    firmware.result = status.result or 0
    firmware.protocol = 2 -- HTTP
    firmware.delivery = 0 -- PULL
    return firmware
end

local function onFirmwareUpdate(params)
    console.warn('onFirmwareUpdate');

    if (exports.updateTimer) then
        clearTimeout(exports.updateTimer)
    end

    exports.updateTimer = setTimeout(1000 * 10, function()
        exports.updateTimer = nil;
        console.log('updateTimer');

        os.execute('lpm upgrade > /tmp/upgrade.log &')
    end)

    return { code = 0 }
end

local function onFirmwareActions(input, webThing)
    if (not input) then
        return { code = 400, error = 'Unsupported methods' }

    elseif (input.update) then
        return onFirmwareUpdate(input.update, webThing);

    elseif (input.read) then
        return onFirmwareRead(input.read, webThing)

    else
        return { code = 400, error = 'Unsupported methods' }
    end
end

local function onConfigRead(input, webThing)
    exports.services.config = exports.app.get('gateway');
    local config = exports.services.config or {}

    return config
end

local function onConfigWrite(config, webThing)
    if (not exports.services.config) then
        exports.services.config = {}
    end

    if (config) then
        exports.services.config = config
        exports.app.set('gateway', config)
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

local function onLogRead(input, webThing)
    local result = {
        enable = true,
        level = 1,
        columns = {"at", "level", "message"},
        data = {{
            0, 0, "message"
        }}
    }
    return result
end

local function onLogWrite(input, webThing)
    if (input) then
        
    end
    return { code = 0 }
end

local function onLogActions(input, webThing)
    if (not input) then
        return { code = 400, error = 'Unsupported methods' }

    elseif (input.read) then
        return onLogRead(input.read, webThing)

    elseif (input.write) then
        return onLogWrite(input.write, webThing);
        
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

    
    local clientId = 'gateway_' .. options.did

    local gateway = { 
        id = options.did, 
        clientId = clientId,
        url = options.mqtt,
        name = 'gateway',
        actions = {},
        properties = {},
        events = {},
        version = { instance = '1.0' }
    }

    gateway['@context'] = 'http://iot.beaconice.cn/schemas'
    gateway['@type'] = 'Gateway'

    local webThing = wot.produce(gateway)
    webThing.secret = options.secret

    -- device actions
    webThing:setActionHandler('device', function(input)
        return onDeviceActions(input, webThing)
    end)

    -- firmware actions
    webThing:setActionHandler('firmware', function(input)
        return onFirmwareActions(input, webThing)
    end)

    -- config actions
    webThing:setActionHandler('config', function(input)
        return onConfigActions(input, webThing)
    end)

    -- log actions
    webThing:setActionHandler('log', function(input)
        return onLogActions(input, webThing)
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

        if (not webThing.started) then
            webThing.started = true;
            console.info('Gateway service restart.')  
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
