local app       = require('app')
local fs        = require('fs')
local express   = require('express')
local request   = require('http/request')
local server    = require('ssdp/server')
local utils     = require('utils')
local path      = require('path')
local json      = require('json')
local conf      = require('ext/conf')
local device    = require('device')

local exec      = require('child_process').exec

local WEB_PORT  = 9100

local ssdpServer = nil

local exports = {}

local function getRootPath()
    return conf.rootPath
end


-------------------------------------------------------------------------------
-- exports

local function getDeviceServiceList()
    local serviceList = {}

    --local service = {}
    --serviceList[1] = service

    --service.type = 'Hygrothermograph:1'
    --service.url  = 'hygrothermograph.json'

    return serviceList
end

local function getDeviceDescribe()
    local deviceInfo = device.getDeviceInfo()

    local host = "0.0.0.0"
    if (exports.ssdpServer) then
        host = exports.ssdpServer:getLocalAddress() or "0.0.0.0"
    end

    local describe = {}
    describe.version    = 1

    local info = {}
    describe.device   = info
    info.manufacturer = deviceInfo.manufacturer
    info.model        = deviceInfo.model
    info.name         = deviceInfo.model
    info.serialNumber = deviceInfo.serialNumber
    info.type         = deviceInfo.type
    info.udn          = deviceInfo.udn
    info.target       = deviceInfo.target
    info.version      = deviceInfo.version
    info.url          = 'http://' .. host .. ':80'
    info.arch         = deviceInfo.arch

    info.serviceList = getDeviceServiceList()
    return describe
end

local function onConnect(request, response)
    local result = { ret = 0 }
    -- TODO: connect
    response:json(result)
end

local function onDisconnect(request, response)
    local result = { ret = 0 }
    -- TODO: disconnect
    response:json(result)
end

local function onShell(request, response)
    local query     = request.query or {}
    local cmd       = query.cmd or ''
    local id        = query.id or 1
    local token     = query.token or ''
    local params    = ''

    local result    = { ret = 0 }

    -- restart
    if (cmd == 'restart') then
        setTimeout(500, function()
            os.execute("killall lnode; lpm start lhost &")
        end)

        result.ret = 0
        response:json(result)
        return 
    end

    local isWindows = (os.platform() == 'win32')
    if (not isWindows) then
        -- 重定向 stderr(2) 输出到 stdout(1)
        cmd = cmd .. " 2>&1"
    end

    -- [[
    local options = { timeout = 3000, env = process.env }
    exec(cmd, options, function(err, stdout, stderr)
        --console.log(err, stdout, stderr)
        if (not stdout) or (stdout == '') then
            stdout = stderr
        end

        if (err and err.message) then
            stdout = err.message .. ': \n\n' .. stdout
        end

        result.output = stdout
        result.cmd = cmd
        result.err = err

        response:json(result)
    end)
    --]]
end

-- /device
local function onGetDevice(request, response)
    response:json(getDeviceDescribe())
end

-- default root index.html
local function onGetRoot(request, response)
    local html = "<h1>SSDP Server</h1>" ..
        "<hr/>" ..
        "Node.lua SSDP Server " .. process.version
    response:send(html)
end

local function onInstall(request, response)
    print('Upload complete.')

    local upgrade = require('ext/upgrade')
    upgrade.handleInstallPost(request.body, request.query, function(result)
        response:json(result)
    end)
end

local function onRestart(request, response)
    print('Upload complete.')

    setTimeout(500, function()
        print("test")
    end)

    local result = { ret = 0 }
    response:json(result)
end

local function onRegister(request, response)
    local result = { ret = 0 }
    -- TODO: disconnect
    response:json(result)
end

local function onRemove(request, response)
    local result = { ret = 0 }
    -- TODO: disconnect
    response:json(result)
end

local function onUpgrade(request, response)
    print('Upload complete.')

    local upgrade = require('ext/upgrade')
    upgrade.handleUpgradePost(request.body, request.query, function(result)
        response:json(result)
    end)
end

local function startHttpServer()
    local app = express({ })

    app:on('error', function(err) 
        print('SSDP WEB Server', err)
        process:exit()
    end)

    app:get("/",            onGetRoot)
    app:get("/connect",     onConnect)
    app:get("/device",      onGetDevice)
    app:get("/disconnect",  onDisconnect)
    app:get("/restart",     onRestart)
    app:get("/shell",       onShell)

    app:post("/install",    onInstall)
    app:post("/register",   onRegister)
    app:post("/remove",     onRemove)
    app:post("/upgrade",    onUpgrade)

    app:listen(WEB_PORT)
end

-------------------------------------------------------------------------------
-- exports

function exports.help()
    app.usage(utils.dirname())

    print([[
Available command:

- scan          Scan all SSDP device or services
- start         Start SSDP server
- view [ip]     View SSDP device information
]])

end

function exports.scan(serviceType, timeout)
    local client = require('ssdp/client')
    local list = {}

    local grid = app.table({20, 24, 24})

    print("Start scaning...")

    grid.line()
    grid.cell("IP", "UID", "Model")
    grid.line('=')


    local ssdpClient = client({}, function(response, rinfo)
        if (list[rinfo.ip]) then
            return
        end

        local headers   = response.headers
        local item      = {}
        item.remote     = rinfo
        item.usn        = headers["usn"] or ''

        list[rinfo.ip] = item

        --console.log(headers)

        local model = headers['X-DeviceModel']
        local name = rinfo.ip .. ' ' .. item.usn
        if (model) then
            name = name .. ' ' .. model
        end

        console.write('\r')  -- clear current line
        grid.cell(rinfo.ip, item.usn, model)
    end)

    -- search for a service type 
    serviceType = serviceType or 'urn:schemas-upnp-org:service:cmpp-iot'
    ssdpClient:search(serviceType)

    local scanCount = 0
    local scanTimer = nil
    local scanMaxCount = timeout or 10

    scanTimer = setInterval(500, function()
        ssdpClient:search(serviceType)
        console.write("\r " .. string.rep('.', scanCount))

        scanCount = scanCount + 1
        if (scanCount >= scanMaxCount) then
            clearInterval(scanTimer)
            scanTimer = nil
            
            ssdpClient:stop()

            console.write('\r') -- clear current line
            grid.line()
            print("End scaning...")
        end
    end)
end

function exports.start()
    local deviceInfo = device.getDeviceInfo()
    
    local server = require('ssdp/server')

    local ssdpSig = "Node.lua/" .. process.version .. ", UPnP/1.0, ssdp/" .. server.version
    local model = deviceInfo.model .. '/' .. process.version
    local options = { 
        udn = deviceInfo.udn, 
        ssdpSig = ssdpSig, 
        deviceModel = model 
    }
    exports.ssdpServer = server(options)

    local localAddress = exports.ssdpServer:getLocalAddress() or '0.0.0.0'
    local localtion = "http://" .. localAddress .. ':' .. WEB_PORT .. '/device'
    exports.ssdpServer.location = localtion

    local timerId = nil
    timerId = setInterval(2000, function()
        --print(exports.ssdpServer.deviceId)

        if (not exports.ssdpServer.deviceId) then
            local mac = device.getMacAddress()
            if (mac) then
                exports.ssdpServer.deviceId = 'uuid:' .. mac
            end
            return
        end

        clearInterval(timerId)
    end)

    startHttpServer()
    print('SSDP server started.')
end

function exports.view(host)
    if (not host) then
        print('ssdp: Not enough arguments provided!')
        print('ssdp: Try `lpm ssdp help` for more information!')
        return
    end

    local url = "http://" .. host .. ":" .. WEB_PORT .. "/device"
    request(url, function(err, response, data)
        --console.log(err, data)

        if (err) then
            print(err)
            return
        end

        data = json.parse(data) or {}
        console.log(data)
    end)
end

function exports.info()
    print('Device info: \n======')

    local info = device.getDeviceInfo()
    for k, v in pairs(info) do
        print(" " .. string.padRight(k, 10), v)
    end

    print('\nInterfaces: \n======')
    local interfaces = device.getInterfaces()
    for _, item in ipairs(interfaces) do
        for k, v in pairs(item) do
            print(" " .. string.padRight(k, 10), v)
        end
        print('------')
    end
end

app(exports)
