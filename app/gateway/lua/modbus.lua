local wot   = require('wot')
local modbus = require('lmodbus')
local thread = require("thread")
local fs = require("fs")
local util = require("util")
local cjson = require("cjson")

local exports = {}
local timer
local dataReady = 0
exports.services = {}

local modbusHandle ={}

modbusHandle.readFlag = 0




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

local list = {}

local beginTime = 0
local finishTime = 0

local openCount = 1
local closeCount = 1

function readRegister(modbusWebThing,openC,closeC,cb)
    local work =
        thread.work(
        function(modbusInfo,openC,closeC)
            console.log("thread work")
            local thread = require("thread")
            local cjson = require("cjson")
            local modbus = require('lmodbus')

            local function getModbusDevice(options)
                local deviceName = "/dev/ttyAMA1"
                local baudrate = options.baudrate 
                openC = openC+1
                local dev = modbus.new(deviceName, baudrate)
                if (dev) then

                    dev:connect()
                    dev:slave(options.slave or 1)
                end
                return dev
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

            local count = 0
            local result = {}
           
            local modbusOptions = cjson.decode(modbusInfo)
            if(modbusOptions) then

                local modbusDevice = getModbusDevice(modbusOptions)
                console.log(modbusDevice)
                -- if(modbusDevice ~= nil) then

                    local  properties = modbusOptions.properties
                
                    for name, property in pairs(properties) do
                        local register = property.register
                        local quantity = property.quantity

                            if (property.code == 0x03 and register >= 0 and quantity >= 1) then
                               
                                if(modbusOptions.type == 0x01) then
                                    register = register * 256 + modbusOptions.switch -1
                                end
                                data = modbusDevice:mread(register, quantity)
                                if(data ~= nil) then
                                    local value = getPropertyValue(property, data)
                                    if (value ~= nil) then
                                        property.value = value
                                        result[name] = value
                                        count = count + 1
                                    end
                                end
                            elseif (property.code == 0x01) then

                                data = modbusDevice:read_bits(register, quantity)
                                if(data ~= nil) then
                                    console.log(data)
                                    local value = string.byte(data)
                                    if (value== 0x01) then
                                        property.value = ture
                                        result[name] = true
                                    else
                                        property.value = false
                                        result[name] = false
                                    end
                                    count = count + 1
                                end
                            elseif (property.code == 0x05) then
                                data = modbusDevice:write_bit(register, quantity)
                                -- if(data ~= nil) then
                                --     local value = data[1] & 0x01
                                --     if (value == 1) then
                                --         property.value = "on"
                                --         result[name] = "on"
                                --         count = count + 1
                                --     end
                                -- end
                            end

                    end
                  
                    modbusDevice:close()
                    closeC = closeC+1

                    console.log(openC, closeC)
                -- end
            end
            -- console.log(result)
            local resultString = cjson.encode(result)
            return count, resultString,openC, closeC
        end,

        function (count,result,openC, closeC)
            openCount = openC
            closeCount = closeC
            cb(count,result,modbusWebThing)
        end
    )
    local modbusInfo = cjson.encode(modbusWebThing.modbus)
    
    thread.queue(work, modbusInfo,openC,closeC)
end

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

local function onDeviceActions(input, webThing)
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

local function initModbusProperties(options, webThing)

    local function classifyProperties(webThing)
        local modbusInfos = {}
        modbusInfos.webThing = webThing
        modbusInfos.modbus = {}
        modbusInfos.modbus.properties = {}
        modbusInfos.modbus.type = webThing.modbus.type
        modbusInfos.modbus.switch = webThing.modbus.switch
  
        local interval = webThing.modbus.interval * 1000
        for name, value in pairs(webThing.modbus.properties or {}) do

            if(value.flag and  value.flag == 1) then
                local modbusInfo = {} 
                modbusInfo.webThing = webThing
                modbusInfo.modbus = {}
                modbusInfo.modbus.slave = webThing.modbus.slave
                modbusInfo.modbus.device = webThing.modbus.device 
                modbusInfo.modbus.baudrate =webThing.modbus.baudrate
                modbusInfo.modbus.interval =value.interval
                modbusInfo.modbus.properties = {}
                modbusInfo.modbus.properties[name] = value
                modbusInfos.modbus.switch = webThing.modbus.switch

                setInterval(modbusInfo.modbus.interval*1000, function()
                    console.log("push")
                    List.pushright(list, modbusInfo)
                    
                    -- setImmediate(modbusHandle.read)
                    -- modbusHandle.read()
                    setTimeout(10,modbusHandle.read)

                end)
            else
                modbusInfos.modbus.properties[name] = value
            end
        end
        modbusInfos.modbus.device = webThing.modbus.device 
        modbusInfos.modbus.slave = webThing.modbus.slave 
        modbusInfos.modbus.baudrate =webThing.modbus.baudrate
        modbusInfos.modbus.interval =webThing.modbus.interval

        setInterval(interval, function()
            console.log("push")
            List.pushright(list, modbusInfos)
            -- -- console.log("push")
            -- setImmediate(modbusHandle.read)
            -- modbusHandle.read()
            setTimeout(10,modbusHandle.read)

        end)

    end


    local common = options.modbus or {}

    webThing.modbus = {}
    -- webThing.modbus.device = options.device
    webThing.modbus.device = common.n 
    webThing.modbus.slave = common.d or 2
    webThing.modbus.type = common.type or 0
 
    webThing.modbus.switch = common.switch or 2
    webThing.modbus.baudrate = common.b or 9600
    webThing.modbus.interval = common.i or 1
    webThing.modbus.properties = {}
    local properties = webThing.modbus.properties;

    for name, value in pairs(options.properties or {}) do
        local property = {}
      
        property.address = value.d or common.d or 0
        property.interval = value.i or common.i or 60
        property.timeout = value.t or common.t or 500
        property.register = value.a or 0
        property.quantity = value.q or 1
        property.scale = value.s or 1
        property.offset = value.o or 0
        property.code = value.code or 0x03
        property.type = value.y or 0
        property.flags = value.f or 0
        property.fixed = value.x or 0
        property.value = 0

        if (value.code ~= nil or (value.i ~= nil and value.i ~= webThing.modbus.interval)) then
            property.flag = 1
        end
        properties[name] = property
    end

    webThing.modbus.properties = properties
    if(next(webThing.modbus.properties) ~= nil) then
        classifyProperties(webThing)
    end
end

function modbusHandle.read()
    if (modbusHandle.readFlag ~= 0) then
        return
    end
 
    console.time("read") 
    if(list[list.first] == nil) then
        -- console.log("empty list")
        return
    end
    local function readRegCallback(count,resultString,modbusWebThing)
        if(resultString ~= nil) then 
            local result = cjson.decode(resultString)
            modbusHandle.readFlag = 0
            -- setImmediate(modbusHandle.read)
            setTimeout(10,modbusHandle.read)
            modbusHandle.read()
            modbusWebThing.webThing:sendStream(result)
            console.timeEnd("read")
            console.log(result)
        end
    end
    console.time("read") 
    modbusHandle.readFlag = 1
    local modbusWebThing = List.popright(list)
    print("read slave  " ..modbusWebThing.modbus.slave)
    readRegister(modbusWebThing,openCount,closeCount,readRegCallback)
        
 
end



local function onSetOnActions(input, webThing)
    local modbusInfo = {} 
    local property = {}

    modbusInfo.webThing = webThing
    modbusInfo.modbus = {}
    modbusInfo.modbus.slave = webThing.modbus.slave
    modbusInfo.modbus.device = webThing.modbus.device 
    modbusInfo.modbus.baudrate =webThing.modbus.baudrate
    modbusInfo.modbus.properties = {}
    modbusInfo.modbus.properties["on"] = property

    property.timeout = 500
    property.register = webThing.modbus.switch - 1
    property.quantity = 1
    property.code = 0x05

    List.pushright(list, modbusInfo)
    setImmediate(modbusHandle.read)

    return { code = 0}
end


local function onSetOffActions(input, webThing)
    console.log(input)
    if (not input) then
        return { code = 400, error = 'Unsupported methods' }
    else
            console.log("special property")
            local modbusInfo = {} 
            local property = {}

            modbusInfo.webThing = webThing
            modbusInfo.modbus = {}
            modbusInfo.modbus.slave = webThing.modbus.slave
            modbusInfo.modbus.device = webThing.modbus.device 
            modbusInfo.modbus.baudrate =webThing.modbus.baudrate
            modbusInfo.modbus.properties = {}
            modbusInfo.modbus.properties["on"] = property
            
            property.timeout = 500
            property.register = webThing.modbus.switch - 1
            property.quantity = 0
            property.code = 0x05

            List.pushright(list, modbusInfo)
            setImmediate(modbusHandle.read)

        return { code = 0}
    end
end


-- Create a Modbus thing
-- @param {object} options
-- - options.mqtt
-- - options.did
-- - options.name
-- - options.secret
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
        url = options.mqtt,
        name = options.name or 'modbus',
        actions = {},
        
        properties = {},
        events = {}
    }
    if(next(list) == nil) then
        list = List.new()
    end
    
    local webThing = wot.produce(gateway)
    webThing.secret = options.secret

    initModbusProperties(options, webThing)

    setInterval(100,function()
        modbusHandle.read()
    end)
    -- device actions
    webThing:setActionHandler('device', function(input)
        return onDeviceActions(input, webThing)
    end)

    -- config actions
    webThing:setActionHandler('config', function(input)
        console.log(input)
        return onConfigActions(input, webThing)
    end)


    webThing:setActionHandler('setOn', function(input)
        console.log(input)
        return onSetOnActions(input, webThing)
    end)


    webThing:setActionHandler('setOff', function(input)
        console.log(input)
        return onSetOffActions(input, webThing)
    end)

    -- register
    webThing:expose()
    console.log('modbus register')
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


























exports.createModbus = createModbusThing


function exports.dataStatus()
    return dataReady
end

return exports