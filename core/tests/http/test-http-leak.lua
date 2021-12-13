local tap = require('util/tap')
local http = require('http')

local HOST = "127.0.0.1"
local PORT = process.env.PORT or 10082

local test = tap.test

--[[

local function bench(uv, p, count, fn)
    collectgarbage()
    local before
    local notify = count / 8
    for i = 1, count do
        fn()

        if (i % notify) == 0 then
            uv.run()
            collectgarbage()
            local now = uv.resident_set_memory()
            if not before then
                before = now
            end

            -- console.log({ index = i, memory = now })
        end
    end

    uv.run()
    collectgarbage()
    local after = uv.resident_set_memory()
    console.log({ before = before, after = after - before })
    assert(after < before * 1.5)
end

test("stream writing with string and array", function(expect, uv)
    local count = 0x1
    local body = string.rep("Hello", 16 * 1024)

    -- server
    local server = nil
    local client = nil
    
    server = http.createServer(function(request, response)
        --console.log('server:onConnection req', request)
        assert(request.method == "POST")
        assert(request.url == "/foo")
        -- Fixed because header parsing is not busted anymore
        assert(request.headers.bar == "cats")
        --console.log('server:onConnection bare resp', response)
        response:setHeader("Content-Type", "text/plain")
        response:setHeader("Content-Length", #body)
        response:finish(body)
    end)

    console.log(server)
    server:listen(PORT, HOST, function() end)

    console.log(server._handle._handle)
    server._handle._handle:unref()

    -- client
    -- [[
    bench(uv, p, count, function()
        -- connect

        local options = { host = HOST, port = PORT, path = "/foo", headers = {{"bar", "cats"}, {"Content-Length", #body}}, method = 'POST' }
        local req = http.request(options, expect(function(response)
            -- console.log('client:onResponse', response.statusCode)
            assert(response.statusCode == 200)
            assert(response.httpVersion == '1.1')
        end))

        req:on('error', function(...)
            print('error', ...)
        end)

        req:finish(body)

        uv.run()
    end)
    -- ] ]

    uv.run()
    server:close()
end)

--]]