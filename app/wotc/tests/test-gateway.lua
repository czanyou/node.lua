local assert =  require('assert')
local tap =  require('util/tap')

local gateway = require('wotc/gateway')

local test = tap.test

test('test onActionExecute', function()
    local actions = { test = function(input) return input * 2 end }
    local input = { test = 100 }
    gateway.onActionExecute()
    gateway.onActionExecute(actions)
    gateway.onActionExecute(nil, input)

    local ret = gateway.onActionExecute(actions, input)
    console.log(ret)
    assert.equal(ret, 200)
end)

test('test getDeviceProperties', function()
    local ret = gateway.getDeviceProperties()
    console.log(ret)
end)

test('test getNetworkProperties', function()
    local ret = gateway.getNetworkProperties()
    console.log(ret)
end)

test('test getFirmwareProperties', function()
    local ret = gateway.getFirmwareProperties()
    console.log(ret)
end)

test('test deviceActions', function()
    local ret = gateway.deviceActions()
    console.log(ret)

    ret = gateway.deviceActions({ read = {}})
    console.log(ret)

    ret = gateway.deviceActions({ reboot = { delay = 100 }})
    console.log(ret)

    ret = gateway.deviceActions({ reboot = { delay = 0 }})
    console.log(ret)

    ret = gateway.deviceActions({ factoryReset = { type = 0 }})
    console.log(ret)

    ret = gateway.deviceActions({ errorReset = {}})
    console.log(ret)

    ret = gateway.deviceActions({ write = { test = 100 }})
    console.log(ret)

    ret = gateway.deviceActions({ log = {}})
    ret:next(function(logs)
        console.log('logs', logs and #logs)
    end)

    ret = gateway.deviceActions({ execute = 'echo "test"'})
    ret:next(function(result)
        console.log('execute', result)
    end)
end)

test('test firmwareActions', function()
    local ret = gateway.firmwareActions()
    console.log(ret)

    ret = gateway.firmwareActions({ read = {}})
    console.log(ret)

    ret = gateway.firmwareActions({ update = { delay = 0 }})
    console.log(ret)
end)

test('test configActions', function()
    local ret = gateway.configActions()
    console.log(ret)

    ret = gateway.configActions({ read = {}})
    console.log(ret)

    ret = gateway.configActions({ reload = { delay = 0 }})
    console.log(ret)

    ret = gateway.configActions({ write = nil })
    console.log(ret)
end)

test('test peripheralActions', function()
    local ret = gateway.peripheralActions()
    console.log(ret)

    ret = gateway.peripheralActions({ read = { did = '@all', config = {} }})
    console.log(ret)

    ret = gateway.peripheralActions({ write = { did = 'test', config = { test = 100 } }})
    console.log(ret)

    ret = gateway.peripheralActions({ read = { did = 'test', config = {} }})
    console.log(ret)
end)

test('test connectivityActions', function()
    local ret = gateway.connectivityActions()
    console.log(ret)

    ret = gateway.connectivityActions({ read = {}})
    console.log(ret)

    ret = gateway.connectivityActions({ status = { delay = 0 }})
    console.log(ret)
end)

tap.run()
