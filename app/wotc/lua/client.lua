
local app   = require('app')
local util  = require('util')
local fs 	= require('fs')
local path 	= require('path')
local json  = require('json')
local wot   = require('wot')
local Promise = require('wot/promise')
local exec  = require('child_process').exec

local exports = {}

local client = {}

client.services = {}
client.unlock = false

local cpuInfo = {
    usedTime = 0,
    totalTime = 0
}

local SHELL_RUN_TIMEOUT = 2000

local function shellGetEnvironment()
    return { path = process.cwd() }
end

local function shellExecute(cmd, callback)

    local isWindows = (os.platform() == 'win32')
    if (not isWindows) then
        -- 重定向 stderr(2) 输出到 stdout(1)
        cmd = cmd .. " 2>&1"
    end

    -- [[
    local options = {
        timeout = SHELL_RUN_TIMEOUT,
        env = process.env
    }

    exec(cmd, options, function(err, stdout, stderr)
        console.log(cmd, err, stdout, stderr)

        if (not stdout) or (stdout == '') then
            stdout = stderr
        end

        -- error
        if (err) then
            if (err.message) then
                err = err.message
            end

            stdout = err .. ': \n\n' .. stdout
        end

        local result = {}
        result.output = stdout
        result.environment = shellGetEnvironment()

        callback(result)
    end)
    --]]
end

local function shellChdir(dir, callback)
    local result = {}

    if (type(dir) == 'string') and (#dir > 0) then
        local cwd = process.cwd()
        local newPath = dir
        if (not dir:startsWith('/')) then
            newPath = path.join(cwd, dir)
        end

        if newPath and (newPath ~= cwd) then
            local ret, err = process.chdir(newPath)
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
    cpuInfo.usedTime = 0;
    cpuInfo.totalTime = 0;
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

    local cpuUsedTime = totalCpuUsedTime - cpuInfo.usedTime
    local cpuTotalTime = totalCpuTime - cpuInfo.totalTime

    cpuInfo.usedTime = math.floor(totalCpuUsedTime) --record
    cpuInfo.totalTime = math.floor(totalCpuTime) --record

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

local function onDeviceActions(input, webThing)

    -- Read device information
    local function onDeviceRead(input, webThing)
        local device = {}
        device.cpuUsage    = getCpuUsage()
        device.currentTime = os.time()
        device.deviceType  = 'gateway'
        device.errorCode   = 0
        device.firmwareVersion = '1.0'
        device.hardwareVersion = '1.0'
        device.manufacturer = 'CD3'
        device.memoryFree   = math.floor(os.freemem() / 1024)
        device.memoryTotal  = math.floor(os.totalmem() / 1024)
        device.modelNumber  = 'DT02'
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

        local message = nil
        if (client.rebootTimer) then
            clearTimeout(client.rebootTimer)
            message = 'Reboot is canceled'
        end

        if (not delay) then
            message = '`delay` parameter is null'

        elseif (delay > 0) then
            if (delay < 3) then
                delay = 3

            elseif (delay > 60) then
                delay = 60
            end

            client.rebootTimer = setTimeout(1000 * delay, function()
                client.rebootTimer = nil;
                console.log('reboot timeout');
                console.log(os.execute('reboot'));
            end)

            message = 'The system will reboot in ' .. delay .. ' seconds'

        else
            if (not message) then
                message = 'Nothing is canceled'
            end
        end

        return { code = 0, delay = delay, message = message }
    end

    -- Factory Reset
    local function onDeviceReset(input, webThing)
        local type = tonumber(input and input.type)

        local message = 'device reset not implemented'
        return { code = 0, type = type, message = message }
    end

    -- Set Date & Time
    local function onDeviceWrite(input, webThing)
        -- console.log('onDeviceWrite');
        if (input) then
            -- currentTime
            -- UTCOffset
            -- timezone
        end

        local message = 'device write not implemented'
        return { code = 0, message = message }
    end

    local function onDeviceUnlock(input, webThing)
        if (not input) then
            return { code = -1, message = 'Input is null' }
        end

        local data = fs.readFileSync(app.nodePath .. '/conf/lnode.key')
        if (not data) then
            client.unlock = false
            return { code = -1, message = 'Unlock key is null' }
        end

        data = data:trim()

        local did = app.get('did')
        local hash = util.md5string(did .. ':' .. data)
        console.log(did, data, hash, input)
        if (hash ~= input) then
            client.unlock = false
            return { code = -1, message = 'Bad input parameter' }
        end

        client.unlock = true
        return { code = 0, message = 'Device unlocked' }
    end

    local function onDeviceExecute(input, webThing)
        -- console.log('onDeviceExecute', input);
        if (not client.unlock) then
            return { code = -1, message = 'Device is locked' }
        end

        local promise = Promise.new()

        if (input and input:startsWith('cd ')) then
            local dir = input:sub(4)
            shellChdir(dir, function(result)
                promise:resolve(result)
            end)

        else
            shellExecute(input, function(result)
                promise:resolve(result)
            end)
        end

        return promise
    end

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

    elseif (input.unlock) then
        return onDeviceUnlock(input.unlock, webThing)

    else
        return { code = 400, error = 'Unsupported methods' }
    end
end

local function onFirmwareActions(input, webThing)

    local function onFirmwareRead(input, webThing)
        local base = app.get('base') or '';
        local did = app.get('did') or '';

        if (not base:endsWith('/')) then
            base = base .. '/'
        end
        local uri = base .. 'device/firmware/file?did=' .. did;

        local rootPath = app.rootPath
        local filename = path.join(rootPath, 'update/status.json')
        local filedata = fs.readFileSync(filename)
        local status = {}
        if (filedata) then
            status = json.parse(filedata) or {}
        end

        local firmware = client.services.firmware or {}
        firmware.uri = uri
        firmware.state = status.state or 0
        firmware.result = status.result or 0
        firmware.protocol = 2 -- HTTP
        firmware.delivery = 0 -- PULL
        return firmware
    end

    local function onFirmwareUpdate(params, webThing)

        if (client.updateTimer) then
            clearTimeout(client.updateTimer)
        end

        client.updateTimer = setTimeout(1000 * 10, function()
            client.updateTimer = nil;
            console.warn('firmware.update');

            os.execute('lpm upgrade system> /tmp/upgrade.log &')
        end)

        return { code = 0 }
    end

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

local function onConfigActions(input, webThing)

    local function onConfigRead(input, webThing)
        client.services.config = app.get('gateway');
        local config = client.services.config or {}

        return config
    end

    local function onConfigWrite(config, webThing)
        if (not client.services.config) then
            client.services.config = {}
        end

        if (config) then
            console.warn('config.write');

            client.services.config = config
            app.set('gateway', config)
        end

        return { code = 0 }
    end

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

local function onLogActions(input, webThing)

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

        return { code = 0 }
    end

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

local function createThing(options)
    if (not options) then
        return nil, 'need options'

    elseif (not options.mqtt) then
        return nil, 'need MQTT url option'

    elseif (not options.did) then
        return nil, 'need did option'
    end

    local gateway = {
        id = options.did,
        clientId = options.clientId,
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

exports.createThing = createThing
exports.getMacAddress = getMacAddress

return exports
