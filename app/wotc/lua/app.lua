local util  = require('util')
local app   = require('app')
local wot   = require('wot')
local json  = require('json')
local rpc   = require('app/rpc')
local log   = require('app/log')
local ssdp  = require('ssdp')
local url   = require('url')

local request = require('http/request')
local devices = require('devices')

local client = require('./client')
local gateway = require('./gateway')
local shell = require('./shell')

local exports = {}

exports.isWotConnected = false

-- 访问 bootstrap 服务器，获取服务器信息
function exports.bootstrap()
    local did = app.get('did');
    local base = app.get('base')

    console.log(did, base);
    local url = base .. '/device/device/bootstrap?did=' .. did
    request.get(url, function(err, res, body)
        local result = nil;
        if (body) then
            result = json.parse(body);
        end
        console.log(err, result);
    end)
end

function exports.check()
    exports.lastConnected = process.now()
    setInterval(1000, function()
        exports.isWotConnected = wot.isConnected()

        local now = process.now()
        if (exports.isWotConnected) then
            exports.lastConnected = now
        end

        local span = now - (exports.lastConnected or 0)
        -- console.log('check', span);

        local timeout = 3600 * 1000
        if (span >= timeout) then
            console.error('MQTT connect timeout')
            process:exit(0)
        end
    end)
end

function exports.config()
    console.printr('gateway', app.get('gateway'))
end

function exports.info()
    console.printr('device:', gateway.getDeviceProperties())
    console.printr('firmware:', gateway.getFirmwareProperties())
    console.printr('network:', gateway.getNetworkProperties())
end

function exports.init()
    print("Usage: ")
    print("  lpm wotc start")
end

function exports.key(key, did)
    did = did or app.get('did')
    key = key or '123456'
    local hash = did .. ':' .. key
    print(hash, util.md5string(hash))
end

-- LED service
function exports.led()
    if (not devices.isSupport()) then
        print('Warn: Current device not support LED')
        return
    end

    devices.setLEDStatus("yellow", "off")
    devices.setLEDStatus("green", "off")
    setInterval(500, function()
        -- Work status LED
        devices.setLEDStatus("green", "toggle")

        -- Network status LED
        if exports.isWotConnected then
            devices.setLEDStatus("yellow", "on")
        else
            devices.setLEDStatus("yellow", "off")
        end
    end)
end

-- RPC service
function exports.rpc()
    local handler = {}
    local name = 'wotc'

    handler.firmware = function(handler, data, qos)
        -- console.log('firmware', data)
        client.sendEvent('firmware', data)
        return 0
    end

    handler.tags = function(handler, tags, qos)
        if (tags and next(tags)) then
            client.sendTagMessage(tags)
        end
        return 0
    end

    handler.log = function(handler, ...)
        log.log(...)
        return 0
    end

    handler.status = function(handler)
        return client.getStatus()
    end

    handler.network = function(handler)
        return exports.isWotConnected
    end

    rpc.server(name, handler, function(event, ...)
        print('rpc', event, ...)
    end)
end

-- SSDP service
function exports.ssdp()
    local device = gateway.getDeviceProperties()
    local version = process.version
    local did = app.get('did') or shell.getMacAddress();
    local model = device.deviceType .. '/' .. version
    local ssdpSig = "lnode/" .. version .. ", ssdp/" .. ssdp.version

    local options = {
        udn = 'uuid:' .. did,
        ssdpSig = ssdpSig,
        deviceModel = model
    }

    -- console.log(options, did)
    local server, error = ssdp.server(options)
    if (error) then
        print('Start sddp error:', error)
        return
    end

    print('start ssdp: ', ssdpSig, model)
    exports.ssdpServer = server
end

function exports.start()
    -- 当 MQTT 参数发生改变，重新连接 MQTT 服务器
    local function onMqttChange(client, url)
        if (client.options) then
            client.options.url = url
        end

        console.log('onMqttChange', url)

        client:close()
        client:start()
    end

    -- 当配置参数发生改变
    local function onConfigChange(profile)
        local gateway = app.gateway
        local client = gateway and gateway.client
        local mqtt = app.get('mqtt')

        if (client and mqtt) then
            local options = gateway.options;
            if (options and options.mqtt ~= mqtt) then
                options.mqtt = mqtt
                onMqttChange(client, mqtt)
            end
        end
    end

    local lock = app.lock()
    if (lock) then
        app.watchProfile(onConfigChange)
        log.init()

        exports.check()
        exports.led()
        exports.rpc()
        exports.ssdp()
        exports.watchdog()
        exports.wot()
        exports.wotc()
    end
end

function exports.test()
    client.test()
end

---@param localPort number Local server port
---@param localAddress string Local server address
---@param remotePort number Remote server port
---@param remoteAddress string Remote server address
function exports.tunnel(localPort, localAddress, remotePort, remoteAddress)
    print('tunnel <localPort> <localAddress> <remotePort> <remoteAddress>', localPort, localAddress)

    local tunnel = require('./tunnel')
    local options = {
        localAddress = localAddress,
        localPort = localPort,
        remoteAddress = remoteAddress,
        remotePort = remotePort
    }

    tunnel.start(options, function(port, token)
        console.log('create a tunnel (port, key)', port, token);
    end)
end

function exports.view(type, ...)
    local params = { ... }
    rpc.call('wotc', type or 'test', params, function(err, result)
        console.printr(type, result or '-', err or '')
    end)
end

function exports.watchdog()
    local filename = '/dev/watchdog'

    -- (-T) Timeout is 60S
    -- (-t) Feed (reset) interval is 20s
    -- (-F) Run in foreground
    local cmdline = 'watchdog -F -T 60 -t 20 /dev/watchdog'
    local name = 'watchdog'
    local lutils = require('lutils')
    local lnode = require('lnode')
    local fs = require('fs')
    local watchdog = nil

    local board = lnode.board
    if (not board) then
        return
    elseif (board ~= 'dt02') and (board ~= 'dt02b') then
        return
    end

    console.log('lnode', board)
    setInterval(5000, function()
        if (not watchdog) then
            watchdog = fs.openSync(filename)
            if (watchdog) then
                lutils.watchdog_timeout(watchdog, 60) -- 60s
            end
        end

        local status = client.getStatus()
        local register = status and status.register
        local tryTimes = (register and register.tryTimes) or 0
        if (tryTimes >= 10) then
            console.log('watchdog: register try times ', tryTimes)
            return
        end

        local timeout = watchdog and lutils.watchdog_timeout(watchdog)
        local ret = watchdog and lutils.watchdog_feed(watchdog)
        -- console.log(ret, timeout, tryTimes)
    end)
end

function exports.wot()
    local did = app.get('did') or ''
    local secret = app.get('secret')

    local mqtt = app.get('mqtt')
    local server = app.get('server')
    local clientId = 'wotc_' .. did

    local function getServerUri(uriString)
        local uri = url.parse(uriString)
        if (not uri) then
            return uriString
        end

        -- console.log(uri)
        if (uri.host) then
            return url.format(uri)
        end

        return 'mqtt://' .. uri.href
    end

    local servers = {}
    local security = { username = did, password = secret }
    if (server) then
        table.insert(servers, getServerUri(server.server))
        security.username = server.username
        security.password = server.password
    end

    if (mqtt) then
        table.insert(servers, getServerUri(mqtt))
    end

    console.log('wotc.servers: ' .. table.concat(servers, ', '))

    local forms = {
        id = did,
        href = mqtt,
        servers = servers,
        clientId = clientId,
        security = security
    }

    local wotClient, err = wot.getClient(forms, true)
    if (err) then
        console.log('getClient:', err)
    end

    wotClient:on('timeout', function()
        process:exit(101)
    end)
end

-- Gateway service
function exports.wotc()
    ---@type ThingOptions
    local options = {}
    options.did = app.get('did')
    options.secret = app.get('secret')
    options.server = app.get('server')
    options.mqtt = app.get('mqtt')
    options.interval = tonumber(app.get('interval'))

    local webThing, error = client.createThing(options)
    if (error) then
        print('Create thing error:', error)
        return
    end

    -- console.log(webThing)
    webThing.options = options
    app.gateway = webThing
end

app(exports)
