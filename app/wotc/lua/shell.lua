local app   = require('app')
local util  = require('util')
local fs 	= require('fs')
local path 	= require('path')
local thread = require('thread')
local rpc   = require('app/rpc')
local json  = require('json')

local exec  = require('child_process').exec

-------------------------------------------------------------------------------
-- Device shell

local SHELL_RUN_TIMEOUT = 2000

local exports = {
    usedTime = 0,
    totalTime = 0,
    lastStatus = {}
}

function exports.getDeviceStatus()
    local PUSH_INTERVAL = 60 * 1000

    local lastStatus = exports.lastStatus
    local updated = lastStatus.updated or 0
    local now = math.floor(Date.now())
    local span = now - updated
    if (span < PUSH_INTERVAL) then
        return
    end

    local cpuUsage = exports.getCpuUsage()
    local memoryInfo = exports.getMemoryInfo()
    local storageInfo = exports.getStorageInfo()
    local networkInfo = exports.getNetworkInfo()

    -- console.log('cpu', cpuUsage, 'mem', memoryInfo, 'storage', storageInfo)

    lastStatus.updated = now
    lastStatus.cpuUsage = cpuUsage
    lastStatus.memoryFree = memoryInfo.free
    lastStatus.memoryUsage = memoryInfo.usage

    if (networkInfo) then
        lastStatus.bearer = networkInfo.bearer
        lastStatus.signalStrength = networkInfo.signalStrength

        if (networkInfo.txBytes) then
            lastStatus.txBytes = math.floor(networkInfo.txBytes / 1024)
        else
            lastStatus.txBytes = nil
        end

        if (networkInfo.rxBytes) then
            lastStatus.rxBytes = math.floor(networkInfo.rxBytes / 1024)
        else
            lastStatus.rxBytes = nil
        end
    end

    if (now > 1569335729809) then
        lastStatus.at = now
        -- console.log('now', now)
    end

    if (storageInfo) then
        lastStatus.storageFree = storageInfo.free
        lastStatus.storageUsage = storageInfo.usage
    end

    return lastStatus
end

function exports.resetCpuUsage()
    exports.usedTime = 0;
    exports.totalTime = 0;
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
    
        return config or {}
    end

    local device = loadConfigFile('device')
    local default = loadConfigFile('default')

    -- console.log('config', filename, config)

    properties.deviceType  = device.deviceType or 'Gateway'
    properties.firmwareVersion = device.firmwareVersion or '1.0'
    properties.hardwareVersion = device.hardwareVersion or '1.0'
    properties.softwareVersion = process.version
    properties.manufacturer = device.manufacturer or 'CD3'
    properties.modelNumber  = device.modelNumber or nil -- 'DT02'
    properties.powerSources = device.powerSources or nil -- 0
    properties.powerVoltage = device.powerVoltage or nil -- 12000
    properties.serialNumber = default.serialNumber or exports.getMacAddress()
    properties.currentTime  = os.time()
    properties.memoryTotal  = math.floor(os.totalmem() / 1024)

    return properties
end

function exports.getNetworkProperties()
    local network = {}

    local status = exports.networkStatus
    if (status) then
        network = status.wan
        if (not network) or (not network.ip) then
            network = status.ethernet
        end
    end

    return network
end

function exports.getMemoryInfo()
    local result = {}
    result.free = math.floor((os.freemem() or 0) / 1024)
    result.total = math.floor((os.totalmem() or 0) / 1024)

    if (result.total > 0) then
        result.usage = math.floor((result.total - result.free) * 100 / result.total + 0.5)
    end

    return result;
end

function exports.getNetworkInfo()
    local status = {}

    local basePath = '/sys/class/net/ppp0/statistics/'
    if (not fs.existsSync(basePath)) then
        basePath = '/sys/class/net/eth0/statistics/'
        if (not fs.existsSync(basePath)) then
            return nil
        end

    else
        status.signalStrength = exports.signalStrength
        status.bearer = 5
    end

    local function readNumber(filename)
        local fileData = fs.readFileSync(basePath .. filename)
        return tonumber(fileData)
    end

    status.rxBytes = readNumber('rx_bytes')
    status.rxPackets = readNumber('rx_packets')
    status.txBytes = readNumber('tx_bytes')
    status.txPackets = readNumber('tx_packets')

    -- console.log('getNetworkInfo', status)
    return status
end

function exports.getNetworkStatus(callback)
    rpc.call('lci', 'network', {}, function(err, result)
        if (err ~= nil) then
            console.log(err)
        end

        if (callback) then
            callback(err, result)
        end

        if (not result) then
            exports.signalStrength = nil
            return
        end

        exports.networkStatus = result

        local wan = result and result.wan
        exports.signalStrength = wan and wan.signalStrength

        -- console.log('signalStrength', exports.signalStrength)
    end)
end

function exports.getStorageInfo()
    local stat = fs.statfs(app.rootPath)
    if (stat == nil) then
        return
    end

    local result = {}
    result.type = stat.type
    result.total = stat.blocks * math.floor(stat.bsize / 1024)
    result.free = stat.bfree * math.floor(stat.bsize / 1024)

    if (result.total > 0) then
        result.usage = math.floor((result.total - result.free) * 100 / result.total + 0.5)
    end

    return result
end

function exports.getCpuUsage()
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

    local cpuUsedTime = totalCpuUsedTime - exports.usedTime
    local cpuTotalTime = totalCpuTime - exports.totalTime

    exports.usedTime = math.floor(totalCpuUsedTime) --record
    exports.totalTime = math.floor(totalCpuTime) --record

    if (cpuTotalTime == 0) then
        return 0
    end

    return math.floor(cpuUsedTime / cpuTotalTime * 100)
end

function exports.getEnvironment()
    return { path = process.cwd() }
end

-- Get the MAC address of localhost
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

function exports.shellExecute(cmd, callback)
    local usePopen = false
    if (usePopen) then
        local work = thread.work(function (cmdline)
            local file = io.popen(cmdline, 'r')
            if (file) then
                local content = file:read("*a")
                file:close()
                return content
            end
        end,
        function (output)
            local result = {}
            result.output = output
            result.environment = exports.getEnvironment()
            callback(result)
        end)

        thread.queue(work, cmd)

    else
        local options = {
            timeout = SHELL_RUN_TIMEOUT,
            env = process.env
        }

        exec(cmd, options, function(err, stdout, stderr)
            -- console.log(cmd, err, stdout, stderr)

            -- error
            if (err) then
                if (err.message) then
                    err = err.message
                end

                stderr = err .. ': \n\n' .. stderr
            end

            if (stdout) then
                stdout = string.split(stdout, '\n')
            end

            -- console.log('stdout', stdout)

            local result = {}
            result.cmd = cmd
            result.output = stdout
            result.error = stderr
            result.environment = exports.getEnvironment()

            callback(result)
        end)
    end
end

function exports.chdir(dir, callback)
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

    result.environment = exports.getEnvironment()

    setImmediate(function()
        callback(result)
    end)
end

return exports
