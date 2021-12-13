local app   = require('app')
local util  = require('util')
local fs 	= require('fs')
local path 	= require('path')
local thread = require('thread')
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

local function loadConfigFile(name)
    local config = nil
    local filename = app.nodePath .. '/conf/'.. name .. '.conf'
    local filedata = fs.readFileSync(filename)
    if (filedata) then
        config = json.parse(filedata)
    end

    return config or {}
end

-- 改变当前目录
---@param dir string 目录名
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
        if (callback) then callback(result) end
    end)
end

--
---@return number CPU 使用率
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

function exports.getDeviceProperties()
    local properties = {}

    local device = loadConfigFile('device')
    local default = loadConfigFile('default')
    -- console.log('config', filename, config)

    properties.currentTime  = os.time()
    properties.deviceType  = device.deviceType or 'Gateway'
    properties.firmwareVersion = device.firmwareVersion or '1.0'
    properties.hardwareVersion = device.hardwareVersion or '1.0'
    properties.manufacturer = device.manufacturer
    properties.memoryTotal  = math.floor(os.totalmem() / 1024)
    properties.modelNumber  = device.modelNumber or nil -- 'DT02'
    properties.powerSources = device.powerSources or nil -- 0
    properties.powerVoltage = device.powerVoltage or nil -- 12000
    properties.serialNumber = default.serialNumber or device.serialNumber or exports.getMacAddress()
    properties.softwareVersion = process.version

    return properties
end

-- 当前设备 CPU 使用率等动态信息
function exports.getDeviceStatus()
    local deviceStatus = exports.lastStatus
    local now = Date.now()

    -- cpu
    local cpuUsage = exports.getCpuUsage()
    deviceStatus.updated = now
    deviceStatus.cpuUsage = cpuUsage

    -- memory
    local memoryInfo = exports.getMemoryStatus()
    if (memoryInfo) then
        deviceStatus.memoryFree = memoryInfo.free
        deviceStatus.memoryUsage = memoryInfo.usage
    end

    -- network
    local networkInfo = exports.getNetworkStatus()
    if (networkInfo) then
        deviceStatus.bearer = networkInfo.bearer
        deviceStatus.signalStrength = networkInfo.signalStrength

        if (networkInfo.txBytes) then
            deviceStatus.txBytes = math.floor(networkInfo.txBytes / 1024)
        else
            deviceStatus.txBytes = nil
        end

        if (networkInfo.rxBytes) then
            deviceStatus.rxBytes = math.floor(networkInfo.rxBytes / 1024)
        else
            deviceStatus.rxBytes = nil
        end
    end

    -- storage
    local storageInfo = exports.getStorageStatus()
    if (storageInfo) then
        deviceStatus.storageFree = storageInfo.free
        deviceStatus.storageUsage = storageInfo.usage
    end

    if (now > 1569335729809) then
        deviceStatus.at = now
    end

    return deviceStatus
end

function exports.getEnvironment()
    return { path = process.cwd() }
end

-- Get the MAC address of localhost
---@return string 16 进制字符编码的 MAC 地址
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

--
---@retrun { total: number, free: number, usage: number }
function exports.getMemoryStatus()
    local result = {}
    result.free = math.floor((os.freemem() or 0) / 1024)
    result.total = math.floor((os.totalmem() or 0) / 1024)

    if (result.total > 0) then
        result.usage = math.floor((result.total - result.free) * 100 / result.total + 0.5)
    end

    return result;
end

-- 当前设备网络属性
function exports.getNetworkProperties()
    local function getDomainServers()
        local result = {}
        local filedata = fs.readFileSync('/etc/resolv.conf')
        if (not filedata) then
            return
        end

        local lines = filedata:split('\n')
        for _, line in ipairs(lines) do
            local tokens = line:split(' ')
            local server = tokens and tokens[2]
            if (tokens[1]) and (tokens[1] == 'nameserver') and server then
                table.insert(result, server)
            end
        end
        return result
    end

    local interfaces = os.networkInterfaces() or {}
    local network = {}

    local networkConfig = loadConfigFile('network') or {}
    local lanConfig = networkConfig and networkConfig.lan

    local ppp0 = interfaces.ppp0 and interfaces.ppp0[1]
    local eth0 = interfaces.eth0 and interfaces.eth0[1]

    if (ppp0) then
        -- ppp
        local status = {}
        status.ifname = 'ppp0'
        status.ip = ppp0.ip
        status.netmask = ppp0.netmask

        local filedata = fs.readFileSync('/tmp/run/wan.json')
        local data = json.parse(filedata or '')
        if (data) then
            status.imsi = data.imsi
            status.iccid = data.iccid
            status.operater = data.operater
            status.updated = data.updated
        end

        status.dns = getDomainServers()
        network.wan = status
    end

    if (eth0) then
        -- eth
        local status = {}
        status.proto = lanConfig and lanConfig.proto
        status.name = 'eth0'
        status.ip = eth0.ip
        status.netmask = eth0.netmask

        if (status.proto == 'static') then
            status.router = lanConfig and lanConfig.router

        elseif (status.proto == 'dhcp') then
            local filedata = fs.readFileSync('/tmp/run/dhcp.json')
            local data = json.parse(filedata or '')
            if (data) then
                status.router = data.router
            end
        end

        status.mac = eth0 and eth0.mac and util.hexEncode(eth0.mac)
        status.dns = getDomainServers()

        network.lan = status
    end

    return network
end

-- 当前设备网络传输等动态信息
function exports.getNetworkStatus()
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

    -- console.log('getNetworkStatus', status)
    return status
end

--
---@retrun { type:number, total: number, free: number, usage: number }
function exports.getStorageStatus()
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

function exports.resetCpuUsage()
    exports.usedTime = 0;
    exports.totalTime = 0;
end

-- 执行远程命令并返回执行结果
---@param cmd string 要执行的 shell 命令
function exports.shellExecute(cmd, callback)
    callback = callback or function() end

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

return exports
