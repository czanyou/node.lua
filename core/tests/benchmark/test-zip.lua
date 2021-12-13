local tap = require('util/tap')
local util = require('util')
local path = require('path')
local miniz = require('miniz')
local fs = require('fs')
local test = tap.test

test("zlib", function(expect)
    local filename = util.dirname()
    filename = path.join(filename, '../../../build/packages.zip')

    if (1) then
        console.time('test1')
        for i = 1, 100 do
            local filedata = fs.readFileSync(filename)
            -- console.log('filename', filename, #filedata)
        
            local reader, err = miniz.read(filedata)
            -- print(reader:getFilename(1))
            local index = reader:getIndex('init.lua')
            local raw = reader:extract(index)
            reader:close()
        end
        console.timeEnd('test1')
    end

    if (2) then
        local filedata = fs.readFileSync(filename)
        console.log('filename', filename, #filedata)
    
        console.time('test2')
        local reader, err = miniz.read(filedata)
        --print(reader:getFilename(1))
        for i = 1, 100 do
            local index = reader:getIndex('init.lua')
            local raw = reader:extract(index)
        end
        reader:close()
        console.timeEnd('test2')
    end
end)

