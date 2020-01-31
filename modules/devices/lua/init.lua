local conf      = require('app/conf')
local json      = require('json')
local fs        = require('fs')
local util      = require('util')
local path      = require('path')

local exports 	= {}

local deviceInfo

function exports.getRootPath()
    return conf.rootPath
end

function exports.getSystemInfo()
    local filename = exports.getRootPath() .. '/package.json'
    local packageInfo = json.parse(fs.readFileSync(filename)) or {}

    exports.systemInfo = packageInfo

    return packageInfo
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

local GPIO_IDS = {
    blue = "55",
    bluetooth = "12",
    green = "53",
    modbus = "24",
    modem = "30",
    reset = "62",
    uart = "63",
    yellow = "54"
}

local GPIO_NAMES = {
    bluetooth = "12",
    ec20 = "30",
    reset = "62",
    uart = "63"
}

local LED_GPIO_NAMES = {
    blue = "55",
    green = "53",
    yellow = "54"
}

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

-- 读取按键的状态
-- @param {string} type 按键的类型: reset
-- @return {number} 返回按键的状态: 1 表示松开，0 表示按下, nil 表示不存在或异常
function exports.getButtonState(type, callback)
    local name = GPIO_NAMES[type or 'reset']
    return exports.getGpioState(name, callback)
end

-- 读取开关的状态
-- @param {string} type 开关的类型: uart, bluetooth, reset, ec20
-- @return {number} 返回开关的状态: 1 表示关闭，0 表示打开, nil 表示不存在或发生异常
function exports.getSwitchState(type, callback)
    local name = GPIO_NAMES[type]
    return exports.getGpioState(name, callback)
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

function exports.checkDeviceConfig()
    local function loadProfile(name)
        local filename = path.join(conf.rootPath, 'conf', name)
        local data = fs.readFileSync(filename)
        return json.parse(data)
    end

    if (not exports.device) then
        local device = loadProfile('device.conf') or {}
        exports.device = device

        -- console.log('device', device)

        local data = device.gpio
        if (data) then
            for key, value in pairs(data) do
                GPIO_IDS[key] = value
            end
        end

        GPIO_NAMES.bluetooth = GPIO_IDS.bluetooth
        GPIO_NAMES.ec20 = GPIO_IDS.ec20
        GPIO_NAMES.reset = GPIO_IDS.reset
        GPIO_NAMES.uart = GPIO_IDS.uart

        LED_GPIO_NAMES.blue = GPIO_IDS.blue
        LED_GPIO_NAMES.green = GPIO_IDS.green
        LED_GPIO_NAMES.yellow = GPIO_IDS.yellow

        -- console.log(GPIO_IDS)
    end
end

function exports.setGpioState(name, value, callback)
    if (not name) then
        return
    end

    value = tostring(value or "0")

    local filename = "/sys/class/gpio/gpio" .. name .. "/value";
    fs.writeFile(filename, value, function(...)
        if (callback) then callback(...); end
    end)
end

function exports.getGpioState(name, callback)
    if (not name) then
        return
    end

    local filename = "/sys/class/gpio/gpio" .. name .. "/value";
    local filedata, err = fs.readFileSync(filename)
    if (not filedata) then
        return nil, err
    end

    return tonumber(filedata)
end

function exports.setUartMultiplex()
    os.execute("himm 0x120400c4 0x02")
    os.execute("himm 0x120400c8 0x02")
end

function exports.setSwitchMultiplex()
    os.execute("himm 0x12040064 0x00")
end

-- Indicate whether the current device supports leds
function exports.isSupport()
    local filename = '/sys/class/gpio/'
    return fs.existsSync(filename)
end

function exports.export(name, direction, value)
    fs.writeFileSync('/sys/class/gpio/export', name)
    fs.writeFileSync('/sys/class/gpio/gpio' .. name .. '/direction', direction)
    if (value ~= nil) then
        fs.writeFileSync('/sys/class/gpio/gpio' .. name .. '/value', value)
    end
end

function exports.init()
    exports.export(GPIO_IDS.reset, 'in') -- reset button
    exports.export(GPIO_IDS.modbus, 'out') -- rs485/modbus direction
    exports.export(GPIO_IDS.green, 'out', '0') -- green led
    exports.export(GPIO_IDS.yellow, 'out', '0') -- yellow led
    exports.export(GPIO_IDS.blue, 'out', '0') -- blue led
    exports.export(GPIO_IDS.uart, 'out', '1') -- uart 备用 power
    exports.export(GPIO_IDS.bluetooth, 'out', '1') -- bluetooth power
    exports.export(GPIO_IDS.modem, 'out', '1') -- ec20 modem power
end

exports.checkDeviceConfig()

return exports
