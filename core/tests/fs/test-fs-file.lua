local util = require('util')
local tap = require('util/tap')
local test = tap.test

local fs = require('fs')

local dirname = require('util').dirname()

test('fs.file', function(expect)
    local foo = {}
    foo.test = function(input, callback)
        console.log('input', input)
        setTimeout(1000, function()
            callback('ok', input)
        end)
    end

    local function wrap(fs)
        local proxy = {}
        setmetatable(proxy, {
            __index = function(self, name)
                console.log('name', name)
                return function(...)
                    return util.await(fs[name], ...)
                end
            end
        })

        return proxy
    end

    local thread, ret = coroutine.running()
    console.log(thread, ret)

    util.async(function()
        local thread, ret = coroutine.running()
        console.log(thread, ret)

        local bar = wrap(foo)
        local result = bar.test('test')
        console.log('result', result)
    end)
end)

test("readfile helper coroutine", function (expect)

    coroutine.wrap(expect(function ()
        fs = fs.wrap()
		local thread = coroutine.running()
        local path = dirname .. "/fixtures/x.txt"
        --local err, data = util.await(fs.readFile, path)
        local data, err = fs.readFile(path, thread)
        console.log(data, err)
		assert(#data > 0)
	end))()
end)

tap.run()