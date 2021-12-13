local util  = require('util')
local wot   = require('wot')

local shell = require('./shell')
local gateway = require('./gateway')

-- ----------------------------------------------------------------------------
-- WoT Cloud Client
-- WoT 云客户端

local exports = {}

exports.gateway = nil
exports.statusTimer = nil

-------------------------------------------------------------------------------
-- Gateway thing

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

    -- console.log('wotc.options: ', options)

    -- Gateway thing description
    local gatewayDescription = exports.getThingDescription(options)
    local webThing = wot.produce(gatewayDescription) ---@type ExposedThing
    gateway.setActions(webThing)

    -- register options
    webThing.status = {}
    webThing.secret = options.secret
    webThing:expose()
    webThing:on('register', function(result)
        if (result and result.code and result.error) then
            console.error('wotc register error: ', result.code, result.error)

        elseif (result) then
            console.info('wotc.registered: ' .. tostring(result.token))
        end

        if (not webThing.status.registered) then
            webThing.status.registered = true;
            exports.onRegisterDone(webThing, result)
        end
    end)

    exports.gateway = webThing
    shell.gateway = webThing

    local interval = options.interval or 60
    exports.statusTimer = setInterval(1000 * interval, function()
        exports.onDeviceStatusTimer()
    end)

    return webThing
end

function exports.getPeripheralThingIds(gateway)
    local things = {}
    local list = nil
    if (not gateway) then
        return things
    end

    -- bluetooth
    list = gateway and gateway.bluetooth
    if (list) then
        for _, device in ipairs(list) do
            table.insert(things, device.did)
        end
    end

    -- peripherals
    list = gateway and gateway.peripherals
    if (list) then
        for _, device in ipairs(list) do
            table.insert(things, device.did)
        end
    end

    -- modbus
    list = gateway and gateway.modbus
    if (list) then
        for _, device in ipairs(list) do
            table.insert(things, device.did)
        end
    end

    -- cameras
    list = gateway and gateway.cameras
    if (list) then
        for _, device in ipairs(list) do
            table.insert(things, device.did)
        end
    end

    -- console.log('things', things)
    return things
end

function exports.getStatus()
    local webThing = exports.gateway
    if (not webThing) then
        return {}
    end

    local client = wot.client()
    local server = client and client.mqtt and client.mqtt.server
    server = server and server.host

    local result = {
        events = webThing.events,
        id = webThing.id,
        isConnected = wot.isConnected(),
        register = webThing.register,
        status = webThing.status,
        server = server,
        options = client.options
    }

    return result
end

---@return ThingDescription
function exports.getThingDescription(options)
    local gatewayDescription = {
        id = options.did,
        name = 'gateway',
        actions = {},
        properties = {},
        events = {},
        register = {
            things = options.things
        },
        version = {
            instance = '1.0',
            software = process.version
        }
    }

    gatewayDescription['@context'] = 'https://iot.wotcloud.cn/schemas'
    gatewayDescription['@type'] = 'Gateway'

    return gatewayDescription
end

function exports.onDeviceStatusTimer()
    local webThing = exports.gateway
    if (not webThing) or (not webThing:isRegistered()) then
        -- 只有当注册之后才上报设备状态
        return
    end

    local status = webThing.status
    if (not status) then
        return
    end

    local statusUpdated = webThing.statusUpdated or 0
    -- console.log(status)

    local PUSH_INTERVAL = 60 * 1000
    local now = Date.now()
    if (now - statusUpdated) <= PUSH_INTERVAL then
        return
    end

    -- device status (cpu, memory, storage...)
    local deviceStatus = shell.getDeviceStatus()
    if (not deviceStatus) then
        return
    end

    webThing.statusUpdated = now

    exports.sendStream(deviceStatus, { options = { qos = 1 }})

    -- device & connectivity & firmware status
    local connectivity = gateway.getNetworkProperties()
    local device = gateway.getDeviceProperties()
    local firmware = gateway.getFirmwareProperties()

    local lastStatus = webThing.status or {}
    local diff, sub = util.diff(lastStatus.connectivity, connectivity)
    if (not lastStatus.device) or (diff or sub) then
        -- console.log('diff', diff, sub)
        local data = { device = device, connectivity = connectivity, firmware = firmware }
        exports.sendTelemetryMessage(data)
    end
end

function exports.onRegisterDone(webThing)
    console.warn('wotc.started')

    setImmediate(function()
        exports.onDeviceStatusTimer()
    end)
end

-- 设备事件
---@param name string 事件名
---@param data table 事件数据
function exports.sendEvent(name, data)
    local webThing = exports.gateway
    if (webThing and name and data) then
        local events = webThing.status.events or {}
        events[name] = data
        events.updated = Date.now()
        webThing.status.events = events

        -- console.log('sendEvent', name, data)
        webThing:emitEvent(name, data)
    end
end

-- 发送数据流
function exports.sendStream(data, options)
    local webThing = exports.gateway
    if (webThing and data) then
        webThing.status.updated = data.at
        webThing.status.data = data

        -- console.log('sendStream', data)
        webThing:sendStream(data, options)
    end
end

-- 发送定位数据
function exports.sendTagMessage(data)
    local webThing = exports.gateway
    if (webThing and data) then
        webThing.status.tags = data

        -- console.log('sendTagMessage', data)
        webThing:sendStream(data, { stream = 'tag' })
    end
end

-- 发送遥测数据
function exports.sendTelemetryMessage(data)
    local webThing = exports.gateway
    if (webThing and data) then
        webThing.status.device = data.device
        webThing.status.connectivity = data.connectivity

        -- console.log('sendTelemetryMessage', data)
        webThing:sendStream(data, { stream = 'telemetry' })
    end
end

-- 自检测试
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

return exports
