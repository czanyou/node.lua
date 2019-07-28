
local app   = require('app')
local util  = require('util')
local fs 	= require('fs')
local path 	= require('path')
local json  = require('json')
local wot   = require('wot')
local Promise = require('wot/promise')
local exec  = require('child_process').exec

local exports = {}

-------------------------------------------------------------------------------
-- Device shell

local SHELL_RUN_TIMEOUT = 2000

local deviceShell = {
    usedTime = 0,
    timer = nil,
    totalTime = 0,
    lastStatus = {}
}

function deviceShell.init()
    if (deviceShell.timer) then
        return
    end

    deviceShell.timer = setInterval(1000 * 2, function()
        local cpuUsage = deviceShell.getCpuUsage()
        local memoryUsage, freeMemory = deviceShell.getMemoryUsage()
        local stat = deviceShell.getStorageInfo()
        -- console.log('cpu', cpuUsage, 'mem', memoryUsage, stat)

        local lastStatus = deviceShell.lastStatus
        local updated = lastStatus.updated or 0
        local span = Date.now() - updated
        -- console.log(span)
        if (span > 10) then
            lastStatus.updated = Date.now()
            lastStatus.cpuUsage = cpuUsage
            lastStatus.freeMemory = freeMemory

            if (stat) then
                lastStatus.freeStorage = stat.free
            end

            console.log(lastStatus)
        end
    end);
end

function deviceShell.resetCpuUsage()
    deviceShell.usedTime = 0;
    deviceShell.totalTime = 0;
end

function deviceShell.getMemoryUsage()
    local free = os.freemem() or 0
    local total = os.totalmem() or 0
    if (total == 0) then
        return 0
    end

    return math.floor(free * 100 / total + 0.5), math.floor(free / 1024)
end

function deviceShell.getStorageInfo()
    local stat = fs.statfs(app.rootPath)
    if (stat == nil) then
        return
    end

    local result = {}
    result.type = stat.type
    result.total = stat.blocks * (stat.bsize / 1024)
    result.free = stat.bfree * (stat.bsize / 1024)
    return result
end

function deviceShell.getCpuUsage()
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

    local cpuUsedTime = totalCpuUsedTime - deviceShell.usedTime
    local cpuTotalTime = totalCpuTime - deviceShell.totalTime

    deviceShell.usedTime = math.floor(totalCpuUsedTime) --record
    deviceShell.totalTime = math.floor(totalCpuTime) --record

    if (cpuTotalTime == 0) then
        return 0
    end

    return math.floor(cpuUsedTime / cpuTotalTime * 100)
end

function deviceShell.getEnvironment()
    return { path = process.cwd() }
end

-- Get the MAC address of localhost
function deviceShell.getMacAddress()
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

function deviceShell.shellExecute(cmd, callback)

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
        result.environment = deviceShell.getEnvironment()

        callback(result)
    end)
    --]]
end

function deviceShell.chdir(dir, callback)
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

    result.environment = deviceShell.getEnvironment()

    setImmediate(function()
        callback(result)
    end)
end

-------------------------------------------------------------------------------
-- Device management

local deviceManagement = {
    rebootTimer = nil,
    updateTimer = nil,
    firmware = nil,
    config = nil,
    unlock = false
}

-- Execute action
-- @param actions {object} Actions table
-- @param input {object} Input parameter
-- @param webThing {object} WoT client
-- @return {any} Output parameter
function deviceManagement.onActionExecute(actions, input, webThing)
    if (type(input) ~= 'table') then
        return { code = 400, error = 'Invalid input parameter' }
    end

    local name, value = next(input)
    local action = actions[name]
    if (action) then
        return action(value, webThing)
    else
        return { code = 400, error = 'Unsupported methods' }
    end
end

function deviceManagement.deviceActions(input, webThing)
    local actions = {}

    -- Read device information
    function actions.read(input, webThing)
        local device = {}
        device.cpuUsage    = getCpuUsage()
        device.currentTime = os.time()
        device.deviceType  = 'Gateway'
        device.errorCode   = 0
        device.firmwareVersion = '1.0'
        device.hardwareVersion = '1.0'
        device.softwareVersion = process.version
        device.manufacturer = 'CD3'
        device.memoryFree   = math.floor(os.freemem() / 1024)
        device.memoryTotal  = math.floor(os.totalmem() / 1024)
        device.modelNumber  = 'DT02'
        device.powerSources = 0
        device.powerVoltage = 12000
        device.serialNumber = deviceShell.getMacAddress()

        return device
    end

    -- Reboot the device
    -- @param input {object}
    --  - delay {number} 大于 0 表示延时重启，小于等于 0 表示取消重启
    function actions.reboot(input, webThing)
        local delay = tonumber(input and input.delay)

        local message = nil
        if (deviceManagement.rebootTimer) then
            clearTimeout(deviceManagement.rebootTimer)
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

            deviceManagement.rebootTimer = setTimeout(1000 * delay, function()
                deviceManagement.rebootTimer = nil;
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
    function actions.reset(input, webThing)
        local type = tonumber(input and input.type)

        local message = 'device reset not implemented'
        return { code = 0, type = type, message = message }
    end

    -- Set Date & Time
    function actions.write(input, webThing)
        -- console.log('onDeviceWrite');
        if (input) then
            -- currentTime
            -- UTCOffset
            -- timezone
        end

        local message = 'device write not implemented'
        return { code = 0, message = message }
    end

    function actions.unlock(input, webThing)
        if (not input) then
            return { code = -1, message = 'Input is null' }
        end

        local data = fs.readFileSync(app.nodePath .. '/conf/lnode.key')
        if (not data) then
            deviceManagement.unlock = false
            return { code = -1, message = 'Unlock key is null' }
        end

        data = data:trim()

        local did = app.get('did')
        local hash = util.md5string(did .. ':' .. data)
        console.log(did, data, hash, input)
        if (hash ~= input) then
            deviceManagement.unlock = false
            return { code = -1, message = 'Bad input parameter' }
        end

        deviceManagement.unlock = true
        return { code = 0, message = 'Device unlocked' }
    end

    function actions.execute(input, webThing)
        -- console.log('onDeviceExecute', input);
        if (not deviceManagement.unlock) then
            return { code = -1, message = 'Device is locked' }
        end

        local promise = Promise.new()

        if (input and input:startsWith('cd ')) then
            local dir = input:sub(4)
            deviceShell.chdir(dir, function(result)
                promise:resolve(result)
            end)

        else
            deviceShell.shellExecute(input, function(result)
                promise:resolve(result)
            end)
        end

        return promise
    end

    return deviceManagement.onActionExecute(actions, input, webThing)
end

function deviceManagement.firmwareActions(input, webThing)
    local actions = {}

    function actions.read(input, webThing)
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

        local firmware = deviceManagement.firmware or {}
        firmware.uri = uri
        firmware.state = status.state or 0
        firmware.result = status.result or 0
        firmware.protocol = 2 -- HTTP
        firmware.delivery = 0 -- PULL
        return firmware
    end

    function actions.update(params, webThing)

        if (deviceManagement.updateTimer) then
            clearTimeout(deviceManagement.updateTimer)
        end

        deviceManagement.updateTimer = setTimeout(1000 * 10, function()
            deviceManagement.updateTimer = nil;
            console.warn('firmware.update');

            os.execute('lpm upgrade system> /tmp/upgrade.log &')
        end)

        return { code = 0 }
    end

    return deviceManagement.onActionExecute(actions, input, webThing)
end

function deviceManagement.configActions(input, webThing)
    local actions = {}

    function actions.read(input, webThing)
        deviceManagement.config = app.get('gateway');
        local config = deviceManagement.config or {}

        return config
    end

    function actions.write(config, webThing)
        if (not deviceManagement.config) then
            deviceManagement.config = {}
        end

        if (config) then
            console.warn('config.write');

            deviceManagement.config = config
            app.set('gateway', config)
        end

        return { code = 0 }
    end

    return deviceManagement.onActionExecute(actions, input, webThing)
end

-- device log actions (read, write)
-- @param input {any} Input parameters
-- @param webThing {thing} wot client
-- @return {any} Output parameters
function deviceManagement.logActions(input, webThing)
    local actions = {}

    -- Read device logs
    function actions.read(input, webThing)
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

    -- Write device log settings
    function actions.write(input, webThing)

        return { code = 0 }
    end

    return deviceManagement.onActionExecute(actions, input, webThing)
end

-- Standard device management action interfaces:
-- device, firmware, config and log
function deviceManagement.setActions(webThing)
    webThing:setActionHandler('device', function(input)
        return deviceManagement.deviceActions(input, webThing)
    end)

    webThing:setActionHandler('firmware', function(input)
        return deviceManagement.firmwareActions(input, webThing)
    end)

    webThing:setActionHandler('config', function(input)
        return deviceManagement.configActions(input, webThing)
    end)

    webThing:setActionHandler('log', function(input)
        return deviceManagement.logActions(input, webThing)
    end)
end

-------------------------------------------------------------------------------
-- Gateway thing

-- Create and expose the WoT gateway thing
-- @param options {object} options
--  - mqtt {string} MQTT server URL (ex: mqtt://iot.text.com)
--  - did {string} Device ID
--  - secret {string} Device secret
local function createThing(options)
    if (not options) then
        return nil, 'need options'

    elseif (not options.mqtt) then
        return nil, 'need MQTT url option'

    elseif (not options.did) then
        return nil, 'need did option'
    end

    -- Gateway status timer
    deviceShell.init()

    -- Gateway thing description
    local gatewayDescription = {
        id = options.did,
        clientId = options.clientId,
        url = options.mqtt,
        name = 'gateway',
        actions = {},
        properties = {},
        events = {},
        version = {
            instance = '1.0',
            software = process.version
        }
    }

    gatewayDescription['@context'] = 'http://iot.beaconice.cn/schemas'
    gatewayDescription['@type'] = 'Gateway'

    local webThing = wot.produce(gatewayDescription)
    deviceManagement.setActions(webThing)

    -- register

    -- register options
    webThing.secret = options.secret
    webThing:expose()
    webThing:on('register', function(response)
        local result = response and response.result
        if (result and result.code and result.error) then
            console.log('register', 'error', response.did, result)

        elseif (result.token) then
            -- access token
            webThing.token = result.token
            console.log('register', response.did, result.token)
        end

        if (not webThing.started) then
            webThing.started = true;
            console.info('Gateway service restart.')
        end
    end)

    return webThing
end

exports.createThing = createThing
exports.getMacAddress = deviceShell.getMacAddress

return exports
