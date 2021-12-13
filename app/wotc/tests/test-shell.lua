local assert =  require('assert')
local tap =  require('util/tap')

local shell =  require('wotc/shell')

local test = tap.test

test('test shell - getDeviceStatus', function()
    local device = shell.getDeviceStatus()
    console.log('device', device)
    assert.ok(device ~= nil)
    assert.ok(device.at >= 0)
    assert.ok(device.cpuUsage >= 0)
    assert.ok(device.memoryFree >= 0)
    assert.ok(device.memoryUsage >= 0)
    assert.ok(device.storageFree >= 0)
    assert.ok(device.storageUsage >= 0)
    assert.ok(device.updated >= 0)
end)

test('test shell - getDeviceProperties', function()
    local device = shell.getDeviceProperties()
    console.log('device', device)
    assert.ok(device ~= nil)
    assert.ok(device.currentTime ~= nil)
    assert.ok(device.memoryTotal ~= nil)
    assert.ok(device.softwareVersion ~= nil)
    assert.ok(device.manufacturer ~= nil)
    assert.ok(device.deviceType ~= nil)
    assert.ok(device.hardwareVersion ~= nil)
end)

test('test shell - getNetworkProperties', function()
    local network = shell.getNetworkProperties()
    console.log('network', network)
    assert.ok(network ~= nil)
    --assert.ok(network.total >= network.free)
    --assert.ok(network.usage >= 0)
end)

--[[

test('test shell - getMemoryStatus', function()
    local memory = shell.getMemoryStatus()
    assert.ok(memory ~= nil)
    console.log('memory', memory)
    assert.ok(memory.total >= memory.free)
    assert.ok(memory.usage >= 0)
end)

test('test shell - getNetworkStatus', function()
    local network = shell.getNetworkStatus()
    --assert.ok(network ~= nil)
    console.log('network', network)
    --assert.ok(network.total >= network.free)
    --assert.ok(network.usage >= 0)
end)

test('test shell - getNetworkStatus', function()
    local network = shell.getNetworkStatus()
    --assert.ok(network ~= nil)
    console.log('storage', network)
    --assert.ok(network.total >= network.free)
    --assert.ok(network.usage >= 0)
end)

test('test shell - getStorageStatus', function()
    local storage = shell.getStorageStatus()
    assert.ok(storage ~= nil)
    console.log('storage', storage)

    assert.ok(storage.total >= storage.free)
    assert.ok(storage.usage >= 0)
end)

test('test shell - getCpuUsage', function()
    local cpuUsage = shell.getCpuUsage()
    assert.ok(cpuUsage ~= nil)
    assert.ok(cpuUsage >= 0)
    console.log('cpuUsage', cpuUsage)
end)

test('test shell - getEnvironment', function()
    local cwd = process.cwd()
    local environment = shell.getEnvironment()
    assert.ok(environment ~= nil)
    assert.equal(environment.path, cwd)
end)

test('test shell - getMacAddress', function()
    local address = shell.getMacAddress()
    assert.ok(address ~= nil)
    assert.equal(#address, 12)
    console.log('address', address)
end)

test('test shell - shellExecute', function()
    local cwd = process.cwd()
    console.log(cwd)
    local cmd = 'ls /bin/sh'
    shell.shellExecute(cmd, function(result)
        console.log(result)

        assert.ok(result.output ~= nil)
        assert.equal(result.cmd, cmd)
        assert.equal(result.environment.path, cwd)
    end)
end)

test('test shell - chdir', function()
    local cwd = process.cwd()
    console.log(cwd)
    shell.chdir('/', function(result)
        console.log(result)

        assert.equal(result.environment.path, '/')
        shell.chdir(cwd)
    end)
end)

--]]

tap.run()
