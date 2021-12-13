local conf      = require('app/conf')
local json      = require('json')
local fs        = require('fs')
local util      = require('util')
local path      = require('path')
local app       = require('app')
local lnode     = require('lnode')
local luv       = require('luv')

local exports 	= {}

local deviceInfo

local GPIO_DT02B_IDS = {
    blue = "14",
    bluetooth = "4",
    green = "12",
    modbus = "24",
    modem = "11",
    relay = "10", -- GPIO1_2
    reset = "42",
    uart = "8",
    yellow = "13"
}

local GPIO_DT02_IDS = {
    blue = "55",
    bluetooth = "12",
    green = "53",
    modbus = "24",
    modem = "30",
    reset = "62",
    uart = "63",
    yellow = "54",
    relay = "66" -- GPIO8_2
}

local GPIO_PI3B_IDS = {
    blue = "2",
    green = "3",
    pir = "17", 
    yellow = "4"
}

local GPIO_IDS = {}
local GPIO_NAMES = {}
local LED_GPIO_NAMES = {}

-- ------------------------------------------------------------
-- device

function exports.getDeviceInfo()
    if (deviceInfo) then
        return deviceInfo
    end

    deviceInfo = {}

    local profile = exports.getSystemInfo()
    local device = profile.device or {}
    deviceInfo.name         = profile.name
    deviceInfo.description  = profile.description
    deviceInfo.model        = device.model
    deviceInfo.type         = device.type
    deviceInfo.serialNumber = device.id
    deviceInfo.manufacturer = device.manufacturer

    if (not deviceInfo.serialNumber) or (deviceInfo.serialNumber == '') then
    	deviceInfo.serialNumber = exports.getMacAddress() or ''
    end

    if (deviceInfo.serialNumber) and (#deviceInfo.serialNumber > 0) then
        deviceInfo.udn          = 'uuid:' .. deviceInfo.serialNumber
    end

    deviceInfo.version      = process.version
    deviceInfo.arch         = os.arch()

    return deviceInfo
end

function exports.getDeviceProperties()
    local properties = {}

    local function loadConfigFile(name)
        local config = nil
        local filename = app.nodePath .. '/conf/'.. name .. '.conf'
        local filedata = fs.readFileSync(filename)
        if (filedata) then
            config = json.parse(filedata)
        end

        -- console.log('filename', filename, filedata, config)
        return config or {}
    end

    local device = loadConfigFile('device')
    local default = loadConfigFile('default')
    local board = lnode.board
    -- console.log('config', board, device, default)

    properties.deviceType  = device.deviceType or 'Gateway'
    properties.firmwareVersion = device.firmwareVersion or '1.0'
    properties.hardwareVersion = device.hardwareVersion or '1.0'
    properties.softwareVersion = process.version
    properties.manufacturer = device.manufacturer or 'CD3'
    properties.modelNumber  = device.modelNumber or board or nil -- 'DT02'
    properties.powerSources = device.powerSources or nil -- 0
    properties.powerVoltage = device.powerVoltage or nil -- 12000
    properties.serialNumber = default.serialNumber or exports.getMacAddress()
    properties.currentTime  = os.time()
    properties.memoryTotal  = math.floor(os.totalmem() / 1024)

    return properties
end

function exports.getMacAddress()
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

    return util.hexEncode(item.mac)
end

function exports.getRootPath()
    return conf.rootPath
end

function exports.getSystemInfo()
    local filename = exports.getRootPath() .. '/package.json'
    local packageInfo = json.parse(fs.readFileSync(filename)) or {}

    exports.systemInfo = packageInfo

    return packageInfo
end

-- ------------------------------------------------------------
-- GPIO

function exports.checkDeviceConfig()
    local function loadProfile(name)
        local filename = path.join(conf.rootPath, 'conf', name)
        local data = fs.readFileSync(filename)
        return data and json.parse(data)
    end

    local board = lnode.board
    if (exports.device) then
        return
    end

    local device = loadProfile('device.conf') or {}
    exports.device = device
    exports.board = board
    
    -- console.log('device', device, board)

    local data = device.gpio
    if (not data) then
        -- print('board', board)

        if (board == 'dt02b') then
            data = GPIO_DT02B_IDS

        elseif (board == 'dt02') then
            data = GPIO_DT02_IDS

        elseif (board == 'linux') then
            data = GPIO_PI3B_IDS
        else
            data = GPIO_PI3B_IDS
        end
    end

    if (data) then
        for key, value in pairs(data) do
            GPIO_IDS[key] = value
        end
    end

    -- GPIO
    GPIO_NAMES.bluetooth = GPIO_IDS.bluetooth
    GPIO_NAMES.ec20 = GPIO_IDS.ec20
    GPIO_NAMES.reset = GPIO_IDS.reset
    GPIO_NAMES.uart = GPIO_IDS.uart
    GPIO_NAMES.relay = GPIO_IDS.relay

    -- LED
    LED_GPIO_NAMES.blue = GPIO_IDS.blue
    LED_GPIO_NAMES.green = GPIO_IDS.green
    LED_GPIO_NAMES.yellow = GPIO_IDS.yellow

    -- console.log('GPIO_IDS', GPIO_IDS, GPIO_NAMES, LED_GPIO_NAMES)
    --console.log(GPIO_IDS)
end

function exports.export(name, direction, value)
    if (not name) then
        return
    end

    local basename = '/sys/class/gpio/'
    local ret, err = fs.writeFileSync(basename .. 'export', name)
    --console.log(ret, err)

    basename =  basename .. 'gpio' .. name
    ret, err = fs.writeFileSync(basename .. '/direction', direction)
    --console.log(ret, err)
    if ret and (value ~= nil) then
        ret, err = fs.writeFileSync(basename .. '/value', value)
        --console.log(ret, err)
    end

    if (not ret) then
        print('export error: ' .. tostring(err))
    end

    return ret, err
end

-- 读取按键的状态
-- @param {string} type 按键的类型: reset
-- @return {number} 返回按键的状态: 1 表示松开，0 表示按下, nil 表示不存在或异常
function exports.getButtonState(type, callback)
    local name = GPIO_NAMES[type or 'reset']
    return exports.getGpioState(name, callback)
end

function exports.getGpioName(type)
    return GPIO_IDS[type]
end

function exports.getGpioState(name, callback)
    if (not name) then
        if (callback) then callback(); end
        return
    end

    local filename = "/sys/class/gpio/gpio" .. name .. "/value";
    local filedata, err = fs.readFileSync(filename)
    if (not filedata) then
        return nil, err
    end

    if (callback) then callback(nil, tonumber(filedata)); end
    return tonumber(filedata)
end

function exports.getSwitchNames()
    return util.keys(GPIO_IDS)
end

-- 读取开关的状态
-- @param {string} type 开关的类型: uart, bluetooth, reset, ec20
-- @return {number} 返回开关的状态: 1 表示关闭，0 表示打开, nil 表示不存在或发生异常
function exports.getSwitchState(type, callback)
    local name = GPIO_NAMES[type]
    return exports.getGpioState(name, callback)
end

-- Indicate whether the current device supports leds
function exports.isSupport()
    local filename = '/sys/class/gpio/'
    return fs.existsSync(filename)
end

function exports.setGpioState(name, value, callback)
    if (not name) then
        if (callback) then callback(); end
        return
    end

    value = tostring(value or "0")

    local filename = "/sys/class/gpio/gpio" .. name .. "/value";
    fs.writeFile(filename, value, function(...)
        if (callback) then callback(...); end
    end)
end

-- 设置 LED 状态
-- @param {string} color 灯的名称: green, blue, yellow
-- @param {string} state 要设置的状态: on, off, toggle
function exports.setLEDStatus(color, state)
    local value
    local name = LED_GPIO_NAMES[color]
    if (not name) then
        return
    end

    if state == "on" then
        value = '0'

    elseif state == "off" then
        value = '1'

    elseif state == "toggle" then
        local result = exports.getGpioState(name)
        if (result == 1) then
            value = '0'
        else
            value = '1'
        end
    else
        return
    end

    exports.setGpioState(name, value)
end

function exports.setSwitchMultiplex()
    os.execute("himm 0x12040064 0x00")
end

-- 设置开关的状态
-- @param {string} type 开关的类型: uart, bluetooth, reset, ec20
-- @param {number} state 开关状态, 'on', 'off'
function exports.setSwitchState(type, state, callback)
    local name = GPIO_NAMES[type]

    if state == "on" then
        state = '0'

    elseif state == "off" then
        state = '1'
    end

    return exports.setGpioState(name, state, callback)
end

function exports.setUartMultiplex()
    os.execute("himm 0x120400c4 0x02")
    os.execute("himm 0x120400c8 0x02")
end

function exports.init()
    exports.checkDeviceConfig()

    exports.export(GPIO_IDS.reset, 'in') -- reset button
    exports.export(GPIO_IDS.pir, 'in') -- pir input

    print('devices: init gpio ports: ' .. tostring(GPIO_IDS.reset))
    exports.export(GPIO_IDS.blue, 'out', '0') -- blue led
    exports.export(GPIO_IDS.bluetooth, 'out', '1') -- bluetooth power
    exports.export(GPIO_IDS.green, 'out', '0') -- green led
    exports.export(GPIO_IDS.modbus, 'out') -- rs485/modbus direction
    exports.export(GPIO_IDS.modem, 'out', '1') -- ec20 modem power
    exports.export(GPIO_IDS.relay, 'out', '1') -- 继电器
    exports.export(GPIO_IDS.uart, 'out', '1') -- uart 备用 power
    exports.export(GPIO_IDS.yellow, 'out', '0') -- yellow led
end

exports.checkDeviceConfig()

return exports
