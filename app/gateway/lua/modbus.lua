local wot    = require('wot')
local thread = require("thread")
local rpc    = require('app/rpc')

local exports = {}

local dataReady = 0
exports.services = {}

local modbusThreadId = nil

-- ----------------------------------------------------------------------------
-- list

List = {}
function List.new ()
    return {first = 0, last = -1}
end

function List.pushleft (list, value)
    local first = list.first - 1
    list.first = first
    list[first] = value
end

function List.pushright (list, value)
    local last = list.last + 1
    list.last = last
    list[last] = value
end

function List.popleft (list)
    local first = list.first
    -- if first > list.last then error("list is empty") end
    if first > list.last then
        return nil
    end

    local value = list[first]
    list[first] = nil -- to allow garbage collection
    list.first = first + 1

    return value
end

function List.popright (list)
    local last = list.last
    -- if list.first > last then error("list is empty") end
    if list.first > last then
        return nil
    end

    local value = list[last]
    list[last] = nil -- to allow garbage collection
    list.last = last - 1

    return value
end

-- ----------------------------------------------------------------------------
-- modbus

local function modbusThread()
    local modbus = require('lmodbus')
    local rpc = require('app/rpc')

    local function getModbusDevice(options)
        local deviceName = options.device or "/dev/ttyAMA1"
        local baudrate = options.baudrate

        console.log('getModbusDevice', deviceName, baudrate);

        local device = modbus.new(deviceName, baudrate)
        if (device) then
            device:connect()
            device:setSlave(options.slave or 1)
        end

        return device
    end

    local function getPropertyValue(property, buffer)
        local type = property.type or 0
        local flags = property.flags or 0
        local count = property.quantity or 1
        local value = 0

        if (type == 0) then
            local fmt = 'i2'
            if (count == 2) then -- int32
                fmt = 'i4'

            elseif (count == 4) then -- int64
                fmt = 'i8'
            end

            if ((flags & 0x01) ~= 0) then
                fmt = '>' .. fmt
            else
                fmt = '<' .. fmt
            end

            value = string.unpack(fmt, buffer)

        elseif (type == 1) then
            local fmt = 'I2'
            if (count == 2) then -- uint32
                fmt = 'I4'

            elseif (count == 4) then -- uint64
                fmt = 'I8'
            end

            if (flags & 0x01) ~= 0 then
                fmt = '>' .. fmt
            else
                fmt = '<' .. fmt
            end

            value = string.unpack(fmt, buffer)

        elseif (type == 2) then
            local fmt = 'I2'
            if (count == 2) then -- float
                fmt = 'f'

            elseif (count == 4) then -- double
                fmt = 'd'
            end

            if (flags & 0x01) ~= 0 then
                fmt = '>' .. fmt
            else
                fmt = '<' .. fmt
            end

            value = string.unpack(fmt, buffer)

        elseif (type == 3) then -- string
            return buffer

        elseif (type == 4) then -- boolean
            return string.unpack('<I2', buffer)

        elseif (type == 5) then -- raw
            return buffer

        else
            return 0
        end

        if (property.scale and property.scale ~= 1) then
            value = value * property.scale
        end

        if (property.offset and property.offset ~= 0) then
            value = value + property.offset
        end

        return value
    end

    local modbusDevice = nil;

    local function onModbusAction(modbusOptions)
        local count = 0
        local result = {}

        if (not modbusOptions) then
            return count, result
        end

        if (not modbusDevice) then
            modbusDevice = getModbusDevice(modbusOptions)
            if (not modbusDevice) then
                return
            end
        end

        -- properties
        local properties = modbusOptions.properties
        for name, property in pairs(properties) do
            local register = property.register
            local quantity = property.quantity

            modbusDevice:setSlave(property.address or modbusOptions.address or 1)

            if (property.code == 0x03 and register >= 0 and quantity >= 1) then
                if (modbusOptions.type == 0x01) then
                    register = register * 256 + modbusOptions.switch - 1
                end

                -- 读取寄存器
                local data = modbusDevice:readRegisters(register, quantity)
                -- console.log(register, quantity, data)

                if (data ~= nil) then
                    local value = getPropertyValue(property, data)
                    if (value ~= nil) then
                        property.value = value
                        result[name] = value
                        count = count + 1
                    end
                end

            elseif (property.code == 0x01) then

                -- 读取线圈 (位)
                local data = modbusDevice:readBits(register, quantity)
                if (data ~= nil) then
                    console.log(data)
                    local value = string.byte(data)
                    if (value == 0x01) then
                        property.value = true
                        result[name] = true
                    else
                        property.value = false
                        result[name] = false
                    end
                    count = count + 1
                end

            elseif (property.code == 0x05) then
                -- 写线圈 (位)
                local data = modbusDevice:writeBit(register, quantity)
                -- if (data ~= nil) then
                --     local value = data[1] & 0x01
                --     if (value == 1) then
                --         property.value = "on"
                --         result[name] = "on"
                --         count = count + 1
                --     end
                -- end
            end
        end

        return result
    end

    local name = 'modbus'

    local handler = {}
    function handler:send(params)
        return onModbusAction(params)
    end

    rpc.server(name, handler, function(event, ...)
        console.log(event, ...)
    end)

    runLoop()

    if (modbusDevice) then
        modbusDevice:close()
        modbusDevice = nil
    end
end

local function startModbusThread()
    if (modbusThreadId) then
        return
    end

    modbusThreadId = thread.start(modbusThread)
end

local function sendModbusAction(action, callback)
    local name = 'modbus'
    rpc.call(name, 'send', { action }, callback)
end

-- ----------------------------------------------------------------------------
-- actions

local function onDeviceActions(input, webThing)

    local function onDeviceRead(input, webThing)
        local device = {}
        device.deviceType = 'modbus'
        device.errorCode = 0
        device.firmwareVersion = '1.0'
        device.hardwareVersion = '1.0'
        device.manufacturer = 'MODBUS'
        device.modelNumber = 'MODBUS'
        return device
    end

    if (not input) then
        return { code = 400, error = 'Unsupported methods' }

    elseif (input.reset) then
        return { code = 0 }

    elseif (input.read) then
        return onDeviceRead(input.read, webThing)

    else
        return { code = 400, error = 'Unsupported methods' }
    end
end

local function onConfigActions(input, webThing)

    local function onConfigRead(input, webThing)
        local peripherals = exports.app.get('peripherals') or {}
        local config = peripherals[webThing.id] or {}

        return config
    end

    local function onConfigWrite(config, webThing)

        local peripherals = exports.app.get('peripherals') or {}

        if (config) then
            local newPeripherals ={}
            for key,value in pairs (peripherals) do
                newPeripherals[key] = value
            end

            newPeripherals[webThing.id] = config
            exports.app.set('peripherals', newPeripherals)
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

-- 打开
local function onSetOnActions(input, webThing)

    local property = {}
    property.timeout  = 500
    property.register = webThing.modbus.switch - 1
    property.quantity = 1
    property.code     = 0x05

    local params = {}
    params.slave = webThing.modbus.slave
    params.device = webThing.modbus.device
    params.baudrate = webThing.modbus.baudrate
    params.properties = {}
    params.properties.on = property

    sendModbusAction(params, function(error, result)

    end)

    return { code = 0}
end

-- 关闭
local function onSetOffActions(input, webThing)

    local property = {}
    property.timeout  = 500
    property.register = webThing.modbus.switch - 1
    property.quantity = 0
    property.code     = 0x05

    local params = {}
    params.slave = webThing.modbus.slave
    params.device = webThing.modbus.device
    params.baudrate = webThing.modbus.baudrate
    params.properties = {}
    params.properties.on = property

    sendModbusAction(params, function(error, result)
        
    end)

    return { code = 0}
end

local function setActionHandlers(webThing)
    webThing:setActionHandler('device', function(input)
        return onDeviceActions(input, webThing)
    end)

    webThing:setActionHandler('config', function(input)
        return onConfigActions(input, webThing)
    end)

    webThing:setActionHandler('setOn', function(input)
        return onSetOnActions(input, webThing)
    end)

    webThing:setActionHandler('setOff', function(input)
        return onSetOffActions(input, webThing)
    end)
end

-- ----------------------------------------------------------------------------
-- thing

local function initModbusProperties(options, webThing)

    local function onReadProperties1(name, property)
        local properties = {}
        properties[name] = property

        local params = {}
        params.baudrate = webThing.modbus.baudrate
        params.device   = webThing.modbus.device
        params.interval = property.interval
        params.properties = properties
        params.slave    = webThing.modbus.slave

        setInterval(params.interval * 1000, function()
            sendModbusAction(params, function(error, result)
                if (result and next(result)) then
                    webThing:sendStream(result)
                end
            end)
        end)
    end

    local function onReadProperties2(properties)
        local params = {}
        params.baudrate = webThing.modbus.baudrate
        params.device   = webThing.modbus.device
        params.interval = webThing.modbus.interval
        params.properties = properties
        params.slave    = webThing.modbus.slave
        params.switch   = webThing.modbus.switch
        params.type     = webThing.modbus.type

        setInterval(params.interval * 1000, function()
            sendModbusAction(params, function(error, result)
                if (result and next(result)) then
                    webThing:sendStream(result)
                end
            end)
        end)
    end

    local function startReadProperties(webThing)
        local properties = {}
        local common = webThing.modbus or {}

        for name, property in pairs(common.properties or {}) do
            if (property.interval ~= common.interval) then
                onReadProperties1(name, property)

            else
                properties[name] = property
            end
        end

        if (next(properties) ~= nil) then
            onReadProperties2(properties)
        end
    end

    local properties = {}

    -- Common options
    local common = options.forms or {}
    webThing.modbus = {}
    webThing.modbus.baudrate = common.baudrate or common.b or 9600
    webThing.modbus.device   = common.device or common.n
    webThing.modbus.interval = common.interval or common.i or 60
    webThing.modbus.slave    = common.address or common.d or 2
    webThing.modbus.switch   = common.switch or 2
    webThing.modbus.timeout  = common.timeout or common.t or 500
    webThing.modbus.type     = common.type or 0
    webThing.modbus.properties = properties

    -- Property options
    for name, value in pairs(options.properties or {}) do
        local property = {}

        property.address  = value.address  or value.d or webThing.modbus.slave
        property.code     = value.code     or value.c or 0x03
        property.fixed    = value.fixed    or value.x or 0
        property.flags    = value.flags    or value.f or 0
        property.interval = value.interval or value.i or webThing.modbus.interval
        property.offset   = value.offset   or value.o or 0
        property.quantity = value.quantity or value.q or 1
        property.register = value.register or value.a or 0
        property.scale    = value.scale    or value.s or 1
        property.timeout  = value.timeout  or value.t or webThing.modbus.timeout
        property.type     = value.type     or value.y or 0
        property.value    = 0

        properties[name] = property
    end

    webThing.modbus.properties = properties
    if (next(webThing.modbus.properties) ~= nil) then
        startReadProperties(webThing)
    end

    startModbusThread()
end

-- Create a Modbus thing
-- @param {object} options
-- - options.mqtt
-- - options.did
-- - options.name
-- - options.secret
function exports.createModbusThing(options)
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
        name = options.name or 'modbus',
        actions = {},

        properties = {},
        events = {}
    }

    local webThing = wot.produce(gateway)
    webThing.secret = options.secret

    initModbusProperties(options, webThing)

    setActionHandlers(webThing)

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

    return webThing
end

function exports.isDataReady()
    return dataReady
end

return exports