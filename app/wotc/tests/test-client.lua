local assert =  require('assert')
local tap =  require('util/tap')

local client =  require('wotc/client')
local gateway = require('wotc/gateway')

local test = tap.test

test('test management - onActionExecute', function()
    local actions = {
        test = function(param, webThing)
            if (webThing.name) then
                return param * 2
            end
        end
    }

    local webThing = { name = 'test' }
    local input = { test = 10 }
    local result = gateway.onActionExecute(actions, input, webThing)
    console.log('result', result)
    assert.equal(result, 20)
end)

test('test gateway - getDeviceProperties', function()
    local device = gateway.getDeviceProperties()
    console.log('device', device)
    assert.ok(device ~= nil)
    assert.ok(device.currentTime ~= nil)
    assert.ok(device.errorCode ~= nil)
end)

test('test gateway - getNetworkProperties', function()
    local network = gateway.getNetworkProperties()
    console.log('network', network)
    assert.ok(network ~= nil)
    --assert.ok(network.total >= network.free)
    --assert.ok(network.usage >= 0)
end)

test('test gateway - getFirmwareProperties', function()
    local firmware = gateway.getFirmwareProperties()
    console.log('firmware', firmware)
    assert.ok(firmware ~= nil)
    assert.ok(firmware.delivery >= 0)
    assert.ok(firmware.protocol >= 0)
    assert.ok(firmware.result >= 0)
    assert.ok(firmware.state >= 0)
    assert.ok(firmware.uri ~= nil)
end)

test('test gateway - deviceActions', function()
    local webThing = { name = 'test' }
    local input = { read = 10 }
    local device = gateway.deviceActions(input, webThing)
    console.log('device', device)
    assert.ok(device ~= nil)
    assert.ok(device.currentTime ~= nil)
    assert.ok(device.errorCode ~= nil)
end)

test('test gateway - firmwareActions', function()
    local webThing = { name = 'test' }
    local input = { read = 10 }
    local firmware = gateway.firmwareActions(input, webThing)
    console.log('firmware', firmware)
    assert.ok(firmware ~= nil)
    assert.ok(firmware.delivery >= 0)
    assert.ok(firmware.protocol >= 0)
end)

test('test gateway - configActions', function()
    local webThing = { name = 'test' }
    local input = { read = 10 }
    local config = gateway.configActions(input, webThing)
    console.log('config', config)
    assert.ok(config ~= nil)
end)

test('test gateway - bluetoothActions', function()
    local webThing = { name = 'test' }
    local input = { read = 10 }
    local config = gateway.bluetoothActions(input, webThing)
    console.log('config', config)
    assert.ok(config ~= nil)
end)

test('test gateway - connectivityActions', function()
    local webThing = { name = 'test' }
    local input = { read = 10 }
    local config = gateway.connectivityActions(input, webThing)
    console.log('config', config)
    assert.ok(config ~= nil)
end)

test('test gateway - setActions', function()

end)

test('test gateway - readShadow', function()

end)

test('test client - getStatus', function()
    local status = client.getStatus()
    client.gateway = {}
    console.log('status', status)
end)

test('test client - getThingDescription', function()
    local description = client.getThingDescription({})
    console.log('description', description)
end)

test('test client - checkDeviceStatus', function()
    client.gateway = {
        isRegistered = function() return true end,
        sendStream = function(self, name, options)
            console.log(name, options)
        end
    }

    client.checkDeviceStatus()
end)

test('test client - sendEvent', function()
    client.gateway = {
        emitEvent = function(self, name, data)
            console.log(name, data)
        end
    }

    client.sendEvent('test', 'data')
end)

test('test client - sendStream', function()
    client.gateway = {
        sendStream = function(self, name, options)
            console.log(name, options)
        end
    }

    client.sendStream('test', 'data')
end)

test('test client - sendTelemetryMessage', function()
    client.gateway = {
        sendStream = function(self, name, options)
            console.log(name, options)
            assert(options.stream, 'telemetry')
        end
    }

    client.sendTelemetryMessage('test')
end)

test('test client - sendTagMessage', function()
    client.gateway = {
        sendStream = function(self, name, options)
            console.log(name, options)
            assert(options.stream, 'tag')
        end
    }

    client.sendTagMessage('test')
end)


test('test client - sendTagMessage', function()
    local log   = require('app/log')
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
end)


tap.run()