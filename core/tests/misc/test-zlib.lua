local tap = require('util/tap')
local miniz = require('miniz')
local fs = require('fs')
local test = tap.test

test("zlib", function(expect)
    local data = string.rep('n', 1024 * 64)
    local writer = miniz.createWriter()
    writer:add('data', data, 9)
    local output = writer:finalize()
    writer:close()

    local reader, err = miniz.read(output)

    reader:close()
    reader:close()
    reader:close()
end)

test("zlib", function(expect)
    local data = string.rep('n', 1024 * 64)
    local flags = 0x01000
    local writer = miniz.createWriter()
    writer:add('data', data, 9)
    local output = writer:finalize()
    writer:close()

    fs.writeFileSync('/tmp/core.zip', output)

    console.log(#data, #output, output)
    local reader, err = miniz.read(output)
    collectgarbage()
    console.log(reader, err)

    setTimeout(100, function()
        collectgarbage()
        local raw = reader:extract(1)
        collectgarbage()
        console.log(#raw, miniz)
        reader:close()
        print(reader:getFilename(1))

        setTimeout(100, function()
            reader:close()
        end)
    end)

    local ret = miniz.deflate(data)
    data = nil
    collectgarbage()
    console.log(#ret)

    local raw = miniz.inflate(ret)
    collectgarbage()
    console.log(#raw)
end)

tap.run()
