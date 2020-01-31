local util  = require('util')
local app   = require('app')
local wot   = require('wot')
local json  = require('json')
local fs    = require('fs')
local exec  = require('child_process').exec
local rpc   = require('app/rpc')
local log   = require('app/log')
local ssdp  = require('ssdp')

local request = require('http/request')
local devices = require('devices')

local client = require('./client')
local shell  = require('./shell')

local exports = {}

local isWotConnected = false
local DEVICE_NAME = 'DT02'

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
        isWotConnected = wot.isConnected()
        if isWotConnected then
            devices.setLEDStatus("yellow", "on")
        else
            devices.setLEDStatus("yellow", "off")
        end
    end)
end

-- SSDP service
function exports.ssdp()
    local version = process.version
    local did = app.get('did') or client.getMacAddress();
    local model = DEVICE_NAME .. '/' .. version
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

-- Gateway service
function exports.wotc()
    local function getNodes(gateway)
        local nodes = {}
        local list = nil
        if (not gateway) then
            return nodes
        end

        -- bluetooth
        list = gateway and gateway.bluetooth
        if (list) then
            for _, device in ipairs(list) do
                table.insert(nodes, device.did)
            end
        end

        -- peripherals
        list = gateway and gateway.peripherals
        if (list) then
            for _, device in ipairs(list) do
                table.insert(nodes, device.did)
            end
        end

        -- modbus
        list = gateway and gateway.modbus
        if (list) then
            for _, device in ipairs(list) do
                table.insert(nodes, device.did)
            end
        end

        -- cameras
        list = gateway and gateway.cameras
        if (list) then
            for _, device in ipairs(list) do
                table.insert(nodes, device.did)
            end
        end

        -- console.log('nodes', nodes)
        return nodes
    end

    local options = {}
    options.did = app.get('did')
    options.mqtt = app.get('mqtt')
    options.secret = app.get('secret')
    options.clientId = 'wotc_' .. options.did
    options.nodes = getNodes(app.get('gateway'))

    local webThing, error = client.createThing(options)
    if (error) then
        print('Create thing error:', error)
        return
    end

    -- console.log(webThing)

    webThing.options = options
    app.gateway = webThing
end

-- RPC service
function exports.rpc()
    local handler = {}
    local name = 'wotc'

    handler.firmware = function(handler, data, qos)
        -- console.log('firmware', data)
        client.sendEvent('firmware', data)
    end

    handler.log = function(handler, ...)
        log.log(...)
        return 0
    end

    handler.status = function(handler)
        return client.getStatus()
    end

    handler.network = function(handler)
        return isWotConnected
    end

    rpc.server(name, handler, function(event, ...)
        print('rpc', event, ...)
    end)
end

function exports.view(type, ...)
    local params = { ... }
    rpc.call('wotc', type or 'test', params, function(err, result)
        console.printr(type, result or '-', err or '')
    end)
end

-- 定时发送定位标签扫描状态
function exports.tag()
    local gateway = app.get('gateway')
    local locator = gateway and gateway.locator
    if (not locator) then
        return
    end

    local interval = locator.interval or (60 * 1000)
    local function publishTags()
        rpc.call('gateway', 'tag', { interval }, function(err, result)
            if (result and next(result)) then
                client.sendTagMessage(result)
            end
        end)
    end

    setInterval(interval, publishTags)
end

function exports.test2()
    local test = {
        read = 100,
        write = 100
    }

    console.log(test)
    console.log('type', type(test))
    console.log('next', next(test))
    console.log('next write', next(test, "write"))
    console.log('next read', next(test, "read"))

    log.init()
    console.log(os.date("%Y-%m-%dT%H:%M:%S"))
    console.info('test1', test, 100, 10.5, true, false);
end

function exports.test()
    client.test()
end

function exports.config()
    console.printr('gateway', app.get('gateway'))
end

function exports.device()
    console.printr(client.getDeviceProperties())
end

function exports.firmware()
    console.printr(client.getFirmwareProperties())
end

function exports.network()
    console.printr(client.getNetworkProperties())
end

function exports.key(key, did)
    did = did or app.get('did')
    key = key or '123456'
    local hash = did .. ':' .. key
    print(hash, util.md5string(hash))
end

function exports.watchdog()
    local filename = '/dev/watchdog'

    -- (-T) Timeout is 60S
    -- (-t) Feed (reset) interval is 20s
    -- (-F) Run in foreground
    local cmdline = 'watchdog -F -T 60 -t 20 /dev/watchdog'
    local name = 'watchdog'

    print("Start " .. name .. '...')

    local interval = 1000
    local maxLimit = 1000 * 60
    local startTime = 0
    local isRunning = false

    local function shellExecute(name, cmdline)
        if (not fs.existsSync(filename)) then
            return
        end

        startTime = Date.now()
        os.execute('killall ' .. name)

        isRunning = true
        console.log('execute', interval, cmdline)
        exec(cmdline, {}, function(err, stdout, stderr)
            console.log('exec', err, stdout, stderr)
            isRunning = false

            local span = Date.now() - startTime
            if (span > maxLimit) then
                interval = 1000
            else
                interval = math.min(maxLimit, interval * 2)
            end
        end)
    end

    setInterval(1000, function()
        if (isRunning) then
            return
        end

        local span = Date.now() - startTime
        if (span > interval) then
            shellExecute(name, cmdline)
        end
    end)
end

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

function exports.tunnel(port, address)
    local tunnel = require('./tunnel')
    tunnel.start(port, address, function(port, token)
        console.log('create a tunnel (port, key)', port, token);
    end)
end

function exports.init()
    print("Usage: ")
    print("  lpm wotc start")
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

        exports.watchdog()
        exports.led()
        exports.ssdp()
        exports.rpc()
        exports.wotc()
        exports.tag()
    end
end

app(exports)
