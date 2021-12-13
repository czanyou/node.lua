local net = require('net')

local function start(port, address)

    local count = 0
    console.time("send")

	-- client
	local client
	local function onConnect()
		console.log('client: connect')
        local onData, onWrite
        local message = string.rep('b', 1540)

		function onData(data)
			-- console.log('client: data', #data)
            count = count + 1

            if (count > 1024 * 10) then
                client:finish()
                console.timeEnd("send")
                return
            end

            client:write(message)
		end

		function onWrite(err)
			console.log("client: write")
			assert(err == nil)
		end

		client:on("data", onData)
		client:write(message, onWrite)
	end

	client = net.Socket:new()
	client:connect(port, address, onConnect)

	client:on("close", function(error)
		console.log("client: close", error)
	end)

	client:on("end", function(error)
		console.log("client: end", error)
		client:destroy()
	end)

	client:on("error", function(error)
		console.log("client: error", error)
	end)

	client:on("lookup", function(error)
		console.log("client: lookup", error)
	end)

	-- stream

	client:on("finish", function(error)
		console.log("client: finish", error)
	end)

	client:on("drain", function(error)
		console.log("client: drain", error)
	end)

	client:on("readable", function(error)
		console.log("client: readable", error)
	end)

	client:on("_socketEnd", function(error)
		console.log("client: _socketEnd", error)
	end)
end

local address = '192.168.1.135'
start(10088, address or '127.0.0.1')

