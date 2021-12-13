local net = require('net')

local function start(port)
    local server
	local function onServerConnection(connection)
		console.log("server: connection", connection)

        local function onData(chunk)
            if (chunk) then
                connection:write(chunk)
            end
		end

		connection:on("data", onData)
	end

	server = net.createServer(onServerConnection)
	server:listen(port)
	
	server:on("listening", function(error)
		console.log("server: listening", port, error)
	end)

	server:on("close", function(error)
		console.log("server: close", error)
	end)

	server:on("error", function(error)
		console.log("server: error", error)
    end)
end

start(10088)
