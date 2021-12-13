local bundle  = require('app/bundle')
local tap    = require('util/tap')
local assert = require('assert')
local fs = require('fs')
local util = require('util')
local path = require('path')

describe('test bundle - openBundle', function()
    local reader, err = bundle.openBundle()
    assert(reader == nil)

    reader = bundle.openBundle('')
    assert(reader == nil)

    reader = bundle.openBundle({})
    assert(reader == nil)

    -- openBundle
    local dirname = path.join(util.dirname(), '../../../app/lpm/')
    reader, err = bundle.openBundle(dirname)
    if (err) then
        console.log(dirname, reader, err)
    end
    assert(reader)

    -- getFileCount
    local fileCount = reader:getFileCount()
    console.log('fileCount', fileCount)
    assert(fileCount > 1)

    -- getFilename
    local filename = reader:getFilename()
    assert(filename == nil)

    filename = reader:getFilename(0)
    assert(filename == nil)

    filename = reader:getFilename(1)
    assert.equal(filename, 'bin/lpm')

    -- stat
    local fileStat = reader:stat()
    assert(fileStat == nil)

    fileStat = reader:stat(0)
    assert(fileStat == nil)

    fileStat = reader:stat(1)
    -- console.log('fileStat', fileStat)
    assert.equal(fileStat.type, 'file')

    -- isDirectory
    local isDirectory = reader:isDirectory()
    assert(not isDirectory)

    isDirectory = reader:isDirectory(0)
    assert(not isDirectory)

    isDirectory = reader:isDirectory(1)
    assert(not isDirectory)

    isDirectory = reader:isDirectory(2)
    assert(not isDirectory)

    -- getIndex
    local index = reader:getIndex()
    assert(index == nil)

    index = reader:getIndex('')
    assert(index == nil)

    index = reader:getIndex({})
    assert(index == nil)

    index = reader:getIndex(1)
    assert(index == nil)

    index = reader:getIndex('bin')
    assert(index == nil)

    index = reader:getIndex('bin/lpm')
    assert.equal(index, 1)

    index = reader:getIndex('lua/init.lua')
    assert.equal(index, 4)

    -- extract
    local data = reader:extract(0)
    assert.equal(data, '')

    data = reader:extract(1)
    assert.equal(#data, 59)

    -- close
    reader:close()
end)

describe('test bundle - openBundle (zip)', function()
    local reader, err = bundle.openBundle()
    assert(reader == nil)

    reader = bundle.openBundle('')
    assert(reader == nil)

    reader = bundle.openBundle({})
    assert(reader == nil)

    -- openBundle
    local dirname = path.join(util.dirname(), '../../../build/sdk/x64-linux/app/lpm.zip')
    reader, err = bundle.openBundle(dirname)
    if (err) then
        console.log(dirname, reader, err)
    end
    assert(reader)

    -- getFileCount
    local fileCount = reader:getFileCount()
    console.log('fileCount', fileCount)
    assert(fileCount > 1)

    for i = 1, fileCount do
        console.log(reader:getFilename(i))
    end

    -- getFilename
    local filename = reader:getFilename(-1)
    assert(filename == nil)

    filename = reader:getFilename(0)
    assert(filename == nil)

    filename = reader:getFilename(1)
    assert.equal(filename, 'bin/lpm')

    -- stat
    local fileStat = reader:stat(-1)
    assert(fileStat == nil)

    fileStat = reader:stat(0)
    assert(fileStat == nil)

    fileStat = reader:stat(1)
    console.log('fileStat', fileStat)
    assert.equal(fileStat.filename, 'bin/lpm')

    -- isDirectory
    local isDirectory = reader:isDirectory(-1)
    assert(not isDirectory)

    isDirectory = reader:isDirectory(0)
    assert(not isDirectory)

    isDirectory = reader:isDirectory(1)
    assert(not isDirectory)

    isDirectory = reader:isDirectory(2)
    assert(not isDirectory)

    -- getIndex
    local index = reader:getIndex(-1)
    assert(index == nil)

    index = reader:getIndex('')
    assert(index == nil)

    index = reader:getIndex(1)
    assert(index == nil)

    index = reader:getIndex('bin')
    assert(index == nil)

    index = reader:getIndex('bin/lpm')
    assert.equal(index, 1)

    index = reader:getIndex('lua/init.lua')
    assert.equal(index, 4)

    -- extract
    local data = reader:extract(0)
    console.log('data', data)
    assert.equal(data, '')

    data = reader:extract(1)
    assert.equal(#data, 59)

    -- close
    reader:close()
end)