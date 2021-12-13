--[[

Copyright 2014 The Luvit Authors. All Rights Reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS-IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

--]]
local net = require('net')
local tap = require('util/tap')
local test = tap.test

local HOST = "127.0.0.1"
local PORT = 10089

test("net - tcp socket", function(expect)
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
				connection:finish()
			end

			console.log('server: data', chunk)
			assert(chunk == "ping")
			connection:write("pong", onWrite)
		end

		connection:on("data", expect(onData))
	end

	server = net.createServer(onServerConnection)
	server:listen(PORT, HOST)

	server:on("listening", function(error)
		console.log("server: listening", error)
	end)

	server:on("close", function(error)
		console.log("server: close", error)
	end)

	server:on("error", function(error)
		console.log("server: error", error)
	end)

	-- client
	local client
	local function onConnect()
		console.log('client: connect')
		local onData, onWrite

		function onData(data)
			console.log('client: data', data)
			assert(data == "pong")
			client:finish()

			-- close server
			server:close()
		end

		function onWrite(err)
			console.log("client: write")
			assert(err == nil)
		end

		client:on("data", expect(onData))
		client:write("ping", expect(onWrite))
	end

	client = net.Socket:new()
	client:connect(PORT, HOST, onConnect)

	client:on("close", expect(function(error)
		console.log("client: close", error)
	end))

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
end)
