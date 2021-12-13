local http = require('http')

local tap = require('util/tap')
local test = tap.test

test('http stream end #1', function(expect)
    local server
    server = http.createServer(function(req, res)
        local body = "Hello world\n"
        res:on("finish", expect(function()
            console.log('response: finish - sending resp finished')
        end))

        res:writeHead(200, {
            ["Content-Type"] = "text/plain",
            ["Content-Length"] = #body
        })
        res:finish(body)
    end):listen(8080)

    http.get('http://127.0.0.1:8080', expect(function(resp)
        resp:on('data', p)
        resp:on('end', expect(function()
            console.log('Get response ended')
            server:close()
        end))
    end))
end)

tap.run()
