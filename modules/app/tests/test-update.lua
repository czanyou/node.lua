local update  = require('app/update')
local tap    = require('util/tap')
local assert = require('assert')
local fs = require('fs')
local util = require('util')

describe('test update - getUpdateResultString', function()
    local updater = update.updater
    console.log(updater)

    local ret = updater.getUpdateResultString()
    console.log(ret)

    ret = updater.getUpdateResultString({})
    console.log(ret)

    ret = updater.getUpdateResultString(100)
    console.log(ret)

    ret = updater.getUpdateResultString(0)
    console.log(ret)
    assert.equal(ret, 'init')
end)

describe('test update - getUpdateStateString', function()
    local updater = update.updater
    console.log(updater)

    local ret = updater.getUpdateStateString()
    console.log(ret)

    ret = updater.getUpdateStateString({})
    console.log(ret)

    ret = updater.getUpdateStateString(100)
    console.log(ret)

    ret = updater.getUpdateStateString(0)
    console.log(ret)
    assert.equal(ret, 'init')
end)

describe('test update - saveUpdateStatus', function()
    local updater = update.updater
    console.log(updater)

    updater.printInfo('test')

    local ret = updater.saveUpdateStatus()
    console.log(ret)

    ret = updater.saveUpdateStatus('')
    console.log(ret)

    ret = updater.saveUpdateStatus({ state = 1, result = 3 })
    console.log(ret)

    ret = updater.readUpdateStatus()
    console.log(ret)
end)

--[[

describe('test update - getFirmwareFilename', function()
    local updater = update.updater
    console.log(updater)

    updater.printInfo('test')

    local filename = updater.getFirmwareFilename()
    console.log(filename)
    assert.equal(filename, '/tmp/update/update.zip')
end)

describe('test update - isFileChanged', function()
    local updater = update.updater
    local ret = updater.isFileChanged()
    assert(ret)

    ret = updater.isFileChanged(nil, {})
    assert(ret)

    local filename = '/tmp/update/update.zip'
    ret = updater.isFileChanged(filename)
    assert(ret)

    local data = string.rep('n', 1024)
    fs.writeFileSync(filename, data)

    local md5sum = util.md5string(data)
    ret = updater.isFileChanged(filename, { size = 1024 })
    assert(ret)

    ret = updater.isFileChanged(filename, { md5sum = md5sum })
    assert(ret)

    ret = updater.isFileChanged(filename, { size = 1024, md5sum = md5sum })
    assert(not ret)
end)

describe('test update - saveFirmwareFile', function()
    local updater = update.updater

    local data = string.rep('n', 1024)
    local md5sum = util.md5string(data)
    local filename = '/tmp/update/update.zip'

    updater.saveFirmwareFile(filename, data, { md5sum = md5sum, version = '1.0' }, function(err, filename)
        console.log(err, filename)
        assert(not err)
        assert.equal(filename, '/tmp/update/update.zip')
    end)

    updater.saveFirmwareFile(filename, data, { md5sum = md5sum .. '1', version = '1.0' }, function(err, filename)
        console.log(err, filename)
        assert(err)
    end)
end)

describe('test update - parseVersion', function()
    local updater = update.updater

    local ret = updater.parseVersion()
    assert.equal(ret, 0)

    ret = updater.parseVersion('')
    assert.equal(ret, 0)

    ret = updater.parseVersion({})
    assert.equal(ret, 0)

    ret = updater.parseVersion(1)
    assert.equal(ret, 100000000)

    ret = updater.parseVersion(2.1)
    assert.equal(ret, 200010000)

    ret = updater.parseVersion('1')
    assert.equal(ret, 1 * 10000 * 10000)

    ret = updater.parseVersion('2.1')
    assert.equal(ret, 200010000)

    ret = updater.parseVersion('2.11.1024')
    assert.equal(ret, 200111024)
end)

describe('test update - printFirmwareInfo', function()
    local updater = update.updater

    updater.printFirmwareInfo()
    updater.printFirmwareInfo('')
    updater.printFirmwareInfo({})
    updater.printFirmwareInfo({ version = {} })
end)

describe('test update - saveFirmwareInfo', function()
    local updater = update.updater

    updater.saveFirmwareInfo()
    updater.saveFirmwareInfo('', {})

    local data = string.rep('N', 1024)
    updater.saveFirmwareInfo(data, {}, function(err, info)
        console.log(err, info)
    end)
end)

describe('test update - checkFirmwareFile', function()
    local updater = update.updater

    updater.checkFirmwareFile()
    updater.checkFirmwareFile('')

    local filename = '/tmp/update/update.zip'
    updater.checkFirmwareFile(filename, function(err, info)
        console.log(err, info)
    end)
end)

describe('test update - printUpdateResult', function()
    local updater = update.updater

    updater.printUpdateResult()
    updater.printUpdateResult('')
    updater.printUpdateResult(nil, {})
end)

--]]
