local app   = require('app')
local util  = require('util')
local fs 	= require('fs')
local path 	= require('path')
local json  = require('json')
local wot   = require('wot')
local rpc   = require('app/rpc')

local Promise = require('wot/promise')
local shell = require('./shell')
local tunnel = require('./tunnel')

-- ----------------------------------------------------------------------------
-- WoT Cloud Client
-- WoT 云客户端

local exports = {}

-------------------------------------------------------------------------------
-- Device management

local management = {
    rebootTimer = nil,
    updateTimer = nil,
    firmware = nil,
    config = nil,
    errorCode = 0,
    unlock = true -- false
}

-- Execute action
-- @param actions {object} Actions table
-- @param input {object} Input parameter
-- @param webThing {object} WoT client
-- @return {any} Output parameter
function management.onActionExecute(actions, input, webThing)
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

function management.getDeviceProperties()
    local device = management.device
    if (not device) then
        device = shell.getDeviceProperties()
        management.device = device
    end

    device.currentTime  = os.time()
    device.errorCode    = management.errorCode or 0
    return device
end

function management.getNetworkProperties()
    local network = shell.getNetworkProperties()

    return network
end

function management.getFirmwareProperties()
    local base = app.get('base') or '';
    local did = app.get('did') or '';

    if (not base:endsWith('/')) then
        base = base .. '/'
    end
    local uri = base .. 'device/firmware/file?did=' .. did;

    local filename = path.join(os.tmpdir, 'update/status.json')
    local filedata = fs.readFileSync(filename)
    local status = {}
    if (filedata) then
        status = json.parse(filedata) or {}
    end

    local firmware = management.firmware or {}
    firmware.uri = uri
    firmware.state = status.state or 0
    firmware.result = status.result or 0
    firmware.protocol = 2 -- HTTP
    firmware.delivery = 0 -- PULL
    return firmware
end

function management.deviceActions(input, webThing)
    local actions = {}

    -- Read device information
    function actions.read(input, webThing)
        local device = management.getDeviceProperties()

        return device
    end

    -- Reboot the device
    -- @param input {object}
    --  - delay {number} 大于 0 表示延时重启，小于等于 0 表示取消重启
    function actions.reboot(input, webThing)
        local delay = tonumber(input and input.delay)

        local message = nil
        if (management.rebootTimer) then
            clearTimeout(management.rebootTimer)
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

            management.rebootTimer = setTimeout(1000 * delay, function()
                management.rebootTimer = nil;
                
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

        return { code = 0, delay = delay, message = message }
    end

    -- Factory Reset
    function actions.factoryReset(input, webThing)
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
            management.unlock = false
            return { code = -1, message = 'Unlock key is null' }
        end

        data = data:trim()

        -- local did = app.get('did')
        local did = 'wot'
        local hash = util.md5string(did .. ':' .. input)
        -- console.log(did, data, hash, input)
        if (hash ~= data) and (data ~= input) then
            management.unlock = false
            return { code = -1, message = 'Invalid unlock key' }
        end

        management.unlock = true
        return { code = 0, message = 'Device is unlocked' }
    end

    function actions.execute(input, webThing)
        -- console.log('onDeviceExecute', input);
        if (not management.unlock) then
            return { code = -1, message = 'Device is locked' }
        end

        local promise = Promise.new()

        if (input and input:startsWith('cd ')) then
            local dir = input:sub(4)
            shell.chdir(dir, function(result)
                promise:resolve(result)
            end)

        elseif (input and input:startsWith('exit')) then
            promise:resolve({ code = 0, error = 'exit' })
            setTimeout(1000, function()
                process:exit(1)
            end)

        elseif (input and input:startsWith('killall ')) then
            promise:resolve({ code = 0, error = 'killall' })
            setTimeout(500, function()
                os.execute(input)
            end)

        else
            shell.shellExecute(input, function(result)
                -- console.log('shellExecute', result)
                promise:resolve(result)
            end)
        end

        return promise
    end

    function actions.errorReset(input, webThing)
        management.errorCode = 0
    end

    -- Read log file
    function actions.log(input, webThing)
        local promise = Promise.new()
        local filename = '/tmp/log/wotc.log'
        fs.readFile(filename, function (err, data)

            if (data) then
                data = string.split(data, '\n')
            end

            promise:resolve(data)
        end)

        return promise
    end

    return management.onActionExecute(actions, input, webThing)
end

function management.firmwareActions(input, webThing)
    local actions = {}

    function actions.read(input, webThing)
        return management.getFirmwareProperties()
    end

    function actions.update(params, webThing)

        if (management.updateTimer) then
            clearTimeout(management.updateTimer)
        end

        management.updateTimer = setTimeout(1000 * 10, function()
            management.updateTimer = nil;
            console.warn('firmware.update');

            os.execute('lpm upgrade system> /tmp/upgrade.log &')
        end)

        return { code = 0 }
    end

    return management.onActionExecute(actions, input, webThing)
end

function management.configActions(input, webThing)
    local actions = {}

    function actions.read(input, webThing)
        management.config = app.get('gateway');
        local config = management.config or {}
        console.log(config)
        return config
    end

    function actions.write(config, webThing)
        if (not management.config) then
            management.config = {}
        end

        if (config) then
            local lastConfig = app.get('gateway');
            local lastUpdated = lastConfig and lastConfig.updated
            -- console.log('updated', lastUpdated == config.updated)

            if (lastUpdated ~= config.updated) then
                console.log('config.write', config);

                management.config = config
                app.set('gateway', config)
            end
        end

        return { code = 0 }
    end

    function actions.reload(input, webThing)
        if (not management.reloadTimer) then
            management.reloadTimer = setTimeout(1000, function()
                management.reloadTimer = nil
                management.readShadow()
            end)

            return { code = 0 }
        end

        return { code = 400 }
    end

    return management.onActionExecute(actions, input, webThing)
end

function management.bluetoothActions(input, webThing)
    local actions = {}

    -- Read bluetooth scan list
    function actions.scan(input, webThing)
        local promise = Promise.new()
        rpc.call('gateway', 'bluetoothScan', {}, function(err, result)
            promise:resolve(result)
        end)

        return promise
    end

    -- Read bluetooth status
    function actions.read(input, webThing)
        local promise = Promise.new()
        rpc.call('gateway', 'bluetooth', {}, function(err, result)
            promise:resolve(result)
        end)

        return promise
    end

    return management.onActionExecute(actions, input, webThing)
end

function management.tunnelActions(input, webThing)
    local actions = {}

    -- start tunnel client
    function actions.start(input, webThing)
        local promise = Promise.new()
        local localPort = input and input.port
        local localAddress = input and input.address
        tunnel.start(localPort, localAddress, function(port, token)
            promise:resolve({ port = port, token = token })
        end)

        return promise
    end

    -- stop tunnel client
    function actions.stop(input, webThing)
        tunnel.stop()
        return { code = 0 }
    end

    return management.onActionExecute(actions, input, webThing)
end

function management.mediaActions(input, webThing)
    local actions = {}

    -- Read media status
    function actions.read(input, webThing)
        local promise = Promise.new()
        rpc.call('gateway', 'media', {}, function(err, result)
            promise:resolve(result)
        end)

        return promise
    end

    return management.onActionExecute(actions, input, webThing)
end

function management.connectivityActions(input, webThing)
    local actions = {}

    -- Read connectivity
    function actions.read(input, webThing)
        return {}
    end

    -- Read connectivity status
    function actions.status(input, webThing)
        local promise = Promise.new()
        rpc.call('lci', 'network', {}, function(err, result)
            promise:resolve(result)
        end)

        return promise
    end

    return management.onActionExecute(actions, input, webThing)
end

-- Standard device management action interfaces:
-- device, firmware, config and log
function management.setActions(webThing)
    webThing:setActionHandler('device', function(input)
        return management.deviceActions(input, webThing)
    end)

    webThing:setActionHandler('connectivity', function(input)
        return management.connectivityActions(input, webThing)
    end)

    webThing:setActionHandler('firmware', function(input)
        return management.firmwareActions(input, webThing)
    end)

    webThing:setActionHandler('config', function(input)
        return management.configActions(input, webThing)
    end)

    webThing:setActionHandler('bluetooth', function(input)
        return management.bluetoothActions(input, webThing)
    end)

    webThing:setActionHandler('media', function(input)
        return management.mediaActions(input, webThing)
    end)

    webThing:setActionHandler('tunnel', function(input)
        return management.tunnelActions(input, webThing)
    end)
end

function management.readShadow()
    local shadow = exports.shadow;
    if (not shadow) then
        return
    end

    shadow:invokeAction('shadow', { read = {} })
end

-------------------------------------------------------------------------------
-- Gateway thing

local function createShadowThing(did)
    local instance = {
        id = did
    }

    local shadowThing = wot.consume(instance)
    exports.shadow = shadowThing

    shadowThing:on('result', function (message)
        -- console.log('result', message)

        local result = message.result

        -- 主动读取配置参数结果
        local shadow = result and result.shadow
        if (shadow) then
            shadowThing.shadow = shadow
            local config = shadow.read and shadow.read.config
            if (config) then
                local input = {
                    write = config
                }

                management.configActions(input, shadow)
            end
        end
    end)

    return shadowThing
end

function exports.onRegisterDone(webThing)
    console.warn('Gateway service start.')
end

function exports.getStatus()
    local webThing = exports.gateway
    if (not webThing) then
        return {}
    end

    local result = {
        connectivity = webThing.connectivity,
        data = webThing.data,
        device = webThing.device,
        events = webThing.events,
        id = webThing.id,
        register = webThing.register,
        tags = webThing.tags,
        updated = webThing.updated
    }

    return result
end

-- Create and expose the WoT gateway thing
-- @param options {object} options
--  - mqtt {string} MQTT server URL (ex: mqtt://iot.text.com)
--  - did {string} Device ID
--  - secret {string} Device secret
function exports.createThing(options)
    if (not options) then
        return nil, 'need options'

    elseif (not options.mqtt) then
        return nil, 'need MQTT url option'

    elseif (not options.did) then
        return nil, 'need did option'
    end

    -- Gateway thing description
    local gatewayDescription = {
        id = options.did,
        clientId = options.clientId,
        url = options.mqtt,
        name = 'gateway',
        actions = {},
        properties = {},
        events = {},
        register = {
            nodes = options.nodes
        },
        version = {
            instance = '1.0',
            software = process.version
        }
    }

    gatewayDescription['@context'] = 'http://iot.beaconice.cn/schemas'
    gatewayDescription['@type'] = 'Gateway'

    local webThing = wot.produce(gatewayDescription)
    management.setActions(webThing)

    -- register

    -- register options
    webThing.secret = options.secret
    webThing:expose()
    webThing:on('register', function(response)
        local result = response and response.result
        if (result and result.code and result.error) then
            console.error('register error: ' .. (response.did or ''), result.code, result.error)

        elseif (result.token) then
            -- access token
            webThing.token = result.token
            console.log('register', response.did, result.token)
        end

        if (not webThing.started) then
            webThing.started = true;
            exports.onRegisterDone(webThing)
        end

        createShadowThing(options.did)
    end)

    exports.gateway = webThing
    shell.gateway = webThing

    function webThing:isRegisterd()
        local register = self.register
        local state = register and register.state
        return state == 1
    end

    shell.sendTimer = setInterval(1000 * 5, function()
        exports.checkDeviceStatus()
        exports.checkNetworkStatus()
    end)

    exports.checkNetworkStatus()

    return webThing
end

function exports.checkNetworkStatus()
    shell.getNetworkStatus(function(err, result)
    end)
end

function exports.checkDeviceStatus()
    local webThing = exports.gateway
    if (not webThing) or (not webThing:isRegisterd()) then
        return
    end

    -- device status
    local status = shell.getDeviceStatus()
    if (not status) then
        return
    end

    exports.sendStream(status)

    -- connectivity status
    local connectivity = management.getNetworkProperties()
    local diff, sub = util.diff(webThing.connectivity, connectivity)
    if (not webThing.device) or (diff or sub) then
        -- console.log('diff', diff, sub)
        local device = management.getDeviceProperties()

        local data = { device = device, connectivity = connectivity }
        exports.sendTelemetryMessage(data)
    end
end

function exports.sendEvent(name, data)
    local webThing = exports.gateway
    if (webThing and name and data) then
        local events = webThing.events or {}
        events[name] = data
        events.updated = Date.now()

        -- console.log('sendEvent', name, data)
        webThing:emitEvent(name, data)
    end
end

function exports.sendStream(data, options)
    local webThing = exports.gateway
    if (webThing and data) then
        webThing.updated = data.at
        webThing.data = data

        -- console.log('sendStream', data)
        webThing:sendStream(data, options)
    end
end

function exports.sendTelemetryMessage(data)
    local webThing = exports.gateway
    if (webThing and data) then
        webThing.device = data.device
        webThing.connectivity = data.connectivity

        -- console.log('sendTelemetryMessage', data)
        webThing:sendStream(data, { stream = 'telemetry' })
    end
end

function exports.sendTagMessage(data)
    local webThing = exports.gateway
    if (webThing and data) then
        webThing.tags = data

        -- console.log('sendTagMessage', data)
        webThing:sendStream(data, { stream = 'tag' })
    end
end

function exports.test()
    console.log('test')
    shell.shellExecute("top", function(...)
        console.log(...)
    end)

    setTimeout(1000, function()
        print('exit')
        process:exit(1)
    end)

    setTimeout(5000, function()
    end)
end

exports.getMacAddress = shell.getMacAddress
exports.getDeviceProperties = management.getDeviceProperties
exports.getFirmwareProperties = management.getFirmwareProperties
exports.getNetworkProperties = management.getNetworkProperties

return exports
