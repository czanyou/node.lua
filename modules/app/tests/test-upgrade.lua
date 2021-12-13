local upgrade  = require('app/upgrade')
local tap    = require('util/tap')
local assert = require('assert')
local fs = require('fs')
local util = require('util')
local path = require('path')

describe('test upgrade - isDevelopmentPath', function()
    local pathname = path.join(util.dirname())
    local ret = upgrade.isDevelopmentPath(pathname)
    console.log(ret, pathname)
    assert(not ret)

    pathname = path.join(util.dirname(), '../../../build/sdk/x64-linux/')
    ret = upgrade.isDevelopmentPath(pathname)
    console.log(ret, pathname)
    assert(not ret)

    pathname = path.join(util.dirname(), '../../../')
    ret = upgrade.isDevelopmentPath(pathname)
    console.log(ret, pathname)
    assert(ret)

    pathname = '/usr/local/lnode/'
    ret = upgrade.isDevelopmentPath(pathname)
    console.log(ret, pathname)
    assert(ret)
end)

describe('test upgrade - getFreeFlashSize', function()
    local ret = upgrade.getFreeFlashSize()
    console.log(ret)
    assert(ret > 1024)
end)

describe('test upgrade - nodePath', function()
    console.log(upgrade.nodePath)
    assert.equal(upgrade.nodePath, '/usr/local/lnode')
end)

describe('test upgrade - openUpdater', function()
    local options = nil

    ---@type BundleUpdater
    local updater = upgrade.openUpdater(options)
    assert(not updater)

    local filename = path.join(util.dirname(), '../../../build/sdk/x64-linux/app/lpm.zip')
    local rootPath = path.join(util.dirname(), '../../../build/test/')

    options = {
        filename = filename,
        rootPath = rootPath
    }

    -- openUpdater
    updater = upgrade.openUpdater(options)
    assert(updater)

    -- checkFile
    local ret, err = updater:checkFile()
    console.log(ret)
    assert.equal(ret, 0)

    updater:printUpdateResult()
    updater:checkAllFiles()
    updater:updateFile()
    updater:updateFile(1)
    updater:parsePackageInfo()
    updater:upgradeSystemPackage(function(err, filename)
        console.log(err, filename)

        updater:printUpdateResult()
        ret, err = updater:getUpgradeResult()
        console.log(ret, err)
    end)
end)