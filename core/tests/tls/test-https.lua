
--]]
local test_url = 'https://www.baidu.com/'

local tap = require('util/tap')
local test = tap.test

local http = require('http')

test("http-client", function(expect)
    http.get(test_url, expect(function(res)
        print(res.statusCode)
        assert(res.statusCode == 200)
        assert(res.httpVersion == '1.1')
        res:on('data', function(chunk)
            console.log("ondata", {chunk = #chunk}, chunk)
        end)

        res:once('end', expect(function()
            console.log('stream ended')
        end))
    end))
end)

tap.run()
