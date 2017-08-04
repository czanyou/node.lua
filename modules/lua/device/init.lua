local conf      = require('ext/conf')
local json      = require('json')
local fs        = require('fs')
local utils     = require('utils')

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

function exports.getSystemTarget()
    local platform = os.platform()
    local arch = os.arch()

    local packageInfo = exports.getSystemInfo() or {}
    local target = packageInfo.target or (arch .. '-' .. platform)
    target = target:trim()
    return target
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

    return utils.bin2hex(item.mac)
end

function exports.getInterfaces(family)
    family = family or 'inet'

    local list = {}
    local faces = os.networkInterfaces()
    for name, faceInfos in pairs(faces) do
        if (name == 'lo') then
            goto continue
        end

        for _, item in ipairs(faceInfos) do
            --console.printBuffer(item.mac)

            if (item.family == family) then
                list[#list + 1] = item
                item.mac = utils.bin2hex(item.mac)
                item.name = name
            end
        end

        ::continue::
    end

    return list
end

function exports.getDeviceInfo()
    if (deviceInfo) then
        return deviceInfo
    end

    deviceInfo = {}
    local target = exports.getSystemTarget()

    local profile = exports.getSystemInfo()
    deviceInfo.model        = profile.deviceModel or target
    deviceInfo.type         = profile.deviceType or target
    deviceInfo.serialNumber = profile.deviceId
    deviceInfo.manufacturer = profile.manufacturer or 'CMPP'

    if (not deviceInfo.serialNumber) or (deviceInfo.serialNumber == '') then
    	deviceInfo.serialNumber = exports.getMacAddress() or ''
    end

    if (deviceInfo.serialNumber) and (#deviceInfo.serialNumber > 0) then
        deviceInfo.udn          = 'uuid:' .. deviceInfo.serialNumber
    end

    deviceInfo.target       = target
    deviceInfo.version      = process.version
    deviceInfo.arch         = os.arch()

    return deviceInfo
end

return exports
