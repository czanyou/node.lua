local app   = require('app')
local rpc   = require('app/rpc')
local util  = require('util')
local fs 	= require('fs')
local path 	= require('path')
local json  = require('json')

local Promise = require('promise')

local shell = require('./shell')
local tunnel = require('./tunnel')

---@class GatewayDevice
local exports = {
    config = nil,
    errorCode = 0,
    firmware = nil,
    rebootTimer = nil,
    unlock = true, -- false
    updateTimer = nil
}

local function errorMessage(name, code, err, message)
    local data = { code = code, error = err, message = message }
    if (name) then
        return { [name] = data }
    else
        return data
    end
end

-- Execute action
---@param actions table Actions table
---@param input table Input parameter
---@param webThing table WoT client
---@return {any} Output parameter
function exports.onActionExecute(actions, webThing, input)
    if (type(input) ~= 'table') then
        return errorMessage(nil, 400, 'Invalid input parameter')
    end

    local name, param = next(input)
    local action = actions and actions[name]
    if (not action) then
        return errorMessage(nil, 400, 'Unsupported methods')

    end

    return action(webThing, param)
end

function exports.getDeviceProperties()
    local device = exports.device
    if (not device) then
        device = shell.getDeviceProperties()
        exports.device = device
    end

    device.currentTime  = os.time()
    device.errorCode    = exports.errorCode or 0
    return device
end


function exports.getFirmwareProperties()
    local base = app.get('base') or '';
    local did = app.get('did') or '';

    if (not base:endsWith('/')) then
        base = base .. '/'
    end

    local uri = base .. 'device/firmware/file?did=' .. did;

    local filename = path.join(os.tmpdir, 'update/update.json')
    local filedata = fs.readFileSync(filename)
    local status = {}
    if (filedata) then
        status = json.parse(filedata) or {}
    end

    local firmware = exports.firmware or {}
    firmware.uri = uri
    firmware.state = status.state or 0
    firmware.result = status.result or 0
    firmware.protocol = 'http' -- HTTP
    firmware.delivery = 'pull' -- PULL
    return firmware
end

function exports.getNetworkProperties()
    local network = shell.getNetworkProperties()

    return network
end

function exports.bluetoothActions(webThing, input)
    local actions = {}

    function actions.read(webThing, input)
        local promise = Promise.new()

        local params = {}
        rpc.call('gateway', 'bluetooth', params, function(err, result)
            if (err) then
                promise:reject(errorMessage('read', 500, err))
            else
                promise:resolve({ read = result })
            end
        end)

        return promise
    end

    return exports.onActionExecute(actions, webThing, input)
end

-- 网关配置参数管理
function exports.configActions(webThing, input)
    local actions = {}

    function actions.read(webThing, input)
        exports.config = app.get('gateway') or {};
        return { read = exports.config }
    end

    function actions.write(webThing, config)
        if (not exports.config) then
            exports.config = {}
        end

        if (not config) then
            return errorMessage('write', 400, 'Invalid Parameter')
        end

        local lastConfig = app.get('gateway');
        local lastUpdated = lastConfig and lastConfig.updated
        if (lastUpdated == config.updated) then
            return errorMessage('write', 304, 'Not Modified')
        end

        -- console.log('config.write', config);
        exports.config = config
        app.set('gateway', config)

        exports.configReload(webThing)
        return errorMessage('write', 0)
    end

    function actions.reload(webThing, input)
        exports.configReload(webThing)
        return errorMessage('reload', 0)
    end

    return exports.onActionExecute(actions, webThing, input)
end

function exports.configReload(webThing)
    if (exports.timeoutTimer) then
        clearTimeout(exports.timeoutTimer)
        exports.timeoutTimer = nil
    end

    exports.timeoutTimer = setTimeout(10 * 1000, function()
        exports.timeoutTimer = nil
        os.execute('lpm restart gateway')
    end)
end

-- 网络连接管理
function exports.connectivityActions(webThing, input)
    local actions = {}

    -- Read connectivity
    function actions.read(webThing, input)
        return { read = exports.getNetworkProperties() or {} }
    end

    return exports.onActionExecute(actions, webThing, input)
end

-- 网关设备管理
function exports.deviceActions(webThing, input)
    local actions = {}

    -- Read device information
    function actions.read(webThing, input)
        local device = exports.getDeviceProperties()

        return { read = device }
    end

    -- Reboot the device
    -- @param input {object}
    --  - delay {number} 大于 0 表示延时重启，小于等于 0 表示取消重启
    function actions.reboot(webThing, input)
        local delay = tonumber(input and input.delay)

        local message = nil
        if (exports.rebootTimer) then
            clearTimeout(exports.rebootTimer)
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

            exports.rebootTimer = setTimeout(1000 * delay, function()
                exports.rebootTimer = nil;

                console.log('reboot timeout');
                if (os.reboot) then
                    os.reboot()
                else
                    os.execute('reboot')
                end
            end)

            message = 'The system will reboot in ' .. delay .. ' seconds'

        else
            if (not message) then
                message = 'Nothing is canceled'
            end
        end

        return { reboot = { code = 0, delay = delay, message = message } }
    end

    -- Factory Reset
    function actions.factoryReset(webThing, input)
        local type = tonumber(input and input.type)

        local message = 'device reset not implemented'
        return { factoryReset = { code = 0, type = type, message = message } }
    end

    -- Set Date & Time
    function actions.write(webThing, input)
        -- console.log('onDeviceWrite');
        if (input) then
            -- currentTime
            -- UTCOffset
            -- timezone
        end

        local message = 'device write not implemented'
        return { write = { code = 0, message = message } }
    end

    function actions.unlock(webThing, input)
        if (not input) then
            return errorMessage('unlock', 400, 'Input is null')
        end

        local data = fs.readFileSync(app.nodePath .. '/conf/lnode.key')
        if (not data) then
            exports.unlock = false
            return errorMessage('unlock', 400, 'The key is null')
        end

        data = data:trim()

        -- local did = app.get('did')
        local did = 'wot'
        local hash = util.md5string(did .. ':' .. input)
        -- console.log(did, data, hash, input)
        if (hash ~= data) and (data ~= input) then
            exports.unlock = false
            return errorMessage('unlock', 400, 'Invalid Key')
        end

        exports.unlock = true
        return { unlock = { code = 0, message = 'Device is unlocked' } }
    end

    function actions.execute(webThing, input)
        -- console.log('onDeviceExecute', input);
        if (not exports.unlock) then
            return errorMessage('execute', 500, 'Device is locked')

        elseif (not input) then
            return errorMessage('execute', 400, 'input is empty')
        end

        local promise = Promise.new()

        input = tostring(input)
        if (input:startsWith('cd ')) then
            local dir = input:sub(4)
            shell.chdir(dir, function(result)
                promise:resolve({ execute = result })
            end)

        elseif (input:startsWith('exit')) then
            promise:resolve({ execute = { code = 0, error = 'exit' } })
            setTimeout(1000, function()
                process:exit(1)
            end)

        elseif (input:startsWith('killall ')) then
            promise:resolve({ execute = { code = 0, error = 'killall' } })
            setTimeout(500, function()
                os.execute(input)
            end)

        else
            shell.shellExecute(input, function(result)
                -- console.log('shellExecute', result)
                promise:resolve({ execute = result })
            end)
        end

        return promise
    end

    function actions.errorReset(webThing, input)
        exports.errorCode = 0

        return errorMessage('errorReset', 0, nil, 'error code is reset')
    end

    -- Read log file
    function actions.log(webThing, input)
        local promise = Promise.new()
        local filename = '/tmp/log/wotc.log'
        fs.readFile(filename, function (err, data)

            if (data) then
                data = string.split(data, '\n')
            end

            promise:resolve({ log = data })
        end)

        return promise
    end

    return exports.onActionExecute(actions, webThing, input)
end

-- 固件管理
function exports.firmwareActions(webThing, input)
    local actions = {}

    function actions.read(webThing, input)
        return { read = exports.getFirmwareProperties() }
    end

    -- 开始更新固件
    function actions.update(webThing, input)
        if (exports.updateTimer) then
            clearTimeout(exports.updateTimer)
        end

        local delay = (input and input.delay) or 10

        exports.updateTimer = setTimeout(1000 * delay, function()
            exports.updateTimer = nil;
            console.warn('firmware.update');

            os.execute('lpm upgrade system> /tmp/upgrade.log &')
        end)

        return { update = { code = 0, delay = delay } }
    end

    -- 取消更新固件
    function actions.cancel(webThing, input)
        if (exports.updateTimer) then
            clearTimeout(exports.updateTimer)
            exports.updateTimer = nil
        end

        return { cancel = { code = 0 } }
    end

    return exports.onActionExecute(actions, webThing, input)
end

function exports.mediaActions(webThing, input)
    local actions = {}

    function actions.read(webThing, input)
        local promise = Promise.new()

        local params = {}
        rpc.call('gateway', 'media', params, function(err, result)
            if (err) then
                promise:reject(errorMessage('read', 500, err))
            else
                promise:resolve({ read = result })
            end
        end)

        return promise
    end

    return exports.onActionExecute(actions, webThing, input)
end

-- 配置网关的从机子设备
function exports.peripheralActions(webThing, input)
    local actions = {}

    function actions.status()
        local promise = Promise.new()

        local params = {}
        rpc.call('gateway', 'things', params, function(err, result)
            if (err) then
                promise:reject(errorMessage('status', 500, err))
            else
                promise:resolve({ status = result })
            end
        end)

        return promise
    end

    function actions.read(webThing, input)
        local did = input and input.did
        if (not did) then
            return errorMessage('read', 400, 'invalid peripheral did')
        end

        local config = input and input.config
        if (config) then
            exports.peripherals = app.get('peripherals')
            local peripherals = exports.peripherals or {}
            console.log('peripherals', peripherals)

            if (did == '@all') then
                config = peripherals
            else
                config = peripherals and peripherals[did]
            end
            --console.log(config)
            return { read = config or {} }
        end

        return errorMessage('read', 400, 'invalid parameter')
    end

    function actions.write(webThing, input)
        local did = input and input.did
        if (not did) then
            return errorMessage('write', 400, 'Invalid Parameter: `did`')
        end

        local config = input and input.config
        if (not config) then
            return errorMessage('write', 400, 'Invalid Parameter: `config`')
        end

        local peripherals = app.get('peripherals');
        if (type(peripherals) ~= 'table') then
            peripherals = {}
        end

        local lastConfig = peripherals[did]
        if (type(lastConfig) ~= 'table') then
            lastConfig = {}
        end

        local lastUpdated = (lastConfig and lastConfig.updated) or 0
        -- console.log('updated', lastUpdated == config.updated)
        if (lastUpdated == config.updated) then
            return errorMessage('write', 304, 'Not Modified')
        end

        -- console.log('config.write', config);
        peripherals[did] = config
        app.set('peripherals', peripherals)

        exports.configReload(webThing)
        return { write = { code = 0 } }
    end

    return exports.onActionExecute(actions, webThing, input)
end

-- TCP 隧道管理
function exports.tunnelActions(webThing, input)
    local actions = {}

    -- start tunnel client
    function actions.start(webThing, input)
        local promise = Promise.new()
        local options = input
        if (type(options) ~= 'table') then
            options = {}
        end

        tunnel.start(options, function(port, token)
            promise:resolve({ start = { 
                code = 0, port = port, token = token, localPort = options.localPort, localAddress = options.localAddress 
            } })
        end)

        return promise
    end

    -- stop tunnel client
    function actions.stop(webThing, input)
        tunnel.stop()
        return { stop = { code = 0 } }
    end

    -- read tunnel client
    function actions.read(webThing, input)
        return { read = tunnel.getStatus() }
    end

    return exports.onActionExecute(actions, webThing, input)
end

-- Standard device exports action interfaces:
-- device, firmware, config and log
function exports.setActions(webThing)
    webThing:setActionHandler('bluetooth', function(input)
        return exports.bluetoothActions(webThing, input)
    end)

    webThing:setActionHandler('config', function(input)
        return exports.configActions(webThing, input)
    end)

    webThing:setActionHandler('connectivity', function(input)
        return exports.connectivityActions(webThing, input)
    end)

    webThing:setActionHandler('device', function(input)
        return exports.deviceActions(webThing, input)
    end)

    webThing:setActionHandler('firmware', function(input)
        return exports.firmwareActions(webThing, input)
    end)

    webThing:setActionHandler('media', function(input)
        return exports.mediaActions(webThing, input)
    end)

    webThing:setActionHandler('peripheral', function(input)
        return exports.peripheralActions(webThing, input)
    end)

    webThing:setActionHandler('tunnel', function(input)
        return exports.tunnelActions(webThing, input)
    end)
end

return exports
