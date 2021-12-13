local tap = require('util/tap')
local net = require('net')

local HOST = "127.0.0.1"
local PORT = process.env.PORT or 10083

local test = tap.test

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
    local count = 0x8
    local body = string.rep("Hello", 16 * 1024)

	-- server
	local server
	local function onServerConnection(connection)
		console.log("server: connection")
		local onData

		function onData(chunk)
			local onWrite

			function onWrite(err)
				console.log("server: write")
				assert(err == nil)

				-- close socket
				connection:close()
			end

			console.log('server: data', #chunk)
			connection:write("pong", onWrite)
		end

		connection:on("data", onData)
	end

	server = net.createServer(onServerConnection)
	server:listen(PORT, HOST)

    server:listen(PORT, HOST, function() end)

    console.log(server._handle._handle)
    server._handle._handle:unref()

    -- client
    local client

    -- [[
    bench(uv, p, count, function()
        -- client
        local timeoutTimer;
        local function onConnect()
            console.log('client: connect')

            local function onWrite(err)
                console.log("client: write")
            end

            local data = string.rep('hello', 1024 * 16)
            client:write(data, onWrite)
        end

        client = net.Socket:new()
        client:connect(PORT, HOST, onConnect)
        -- console.log('connect')

        local function onData(data)
            -- console.log('client: data', data)
            client:close()
        end

        client:on("data", onData)

        timeoutTimer = setTimeout(100, function()
            timeoutTimer = nil
        end)
        uv.run()
    end)
    --]]

    uv.run()
    server:close()
end)
