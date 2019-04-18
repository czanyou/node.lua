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
local net = require("net")

local HOST = "127.0.0.1"
local PORT = 10089

local isWindows = os.platform() == "win32"

local sockname = "/tmp/test.sock"
if (isWindows) then
	sockname = "\\\\?\\pipe\\uv-test"
end

local tap = require("ext/tap")
local test = tap.test

test("server", function(expect)
	local server, client, onServerConnection, onConnect
	function onServerConnection(client)
		local onData

		function onData(chunk)
			local onWrite

			function onWrite(err)
				console.log("server:client:write")
				assert(err == nil)
				client:destroy()
			end

			console.log('server:client:on("data")', chunk)
			assert(chunk == "ping")
			client:write("pong", onWrite)
		end

		client:on("data", expect(onData))
	end

	function onConnect()
		console.log('client:on("complete")')
		local onData, onWrite

		function onData(data)
			console.log('client:on("data")', data)
			assert(data == "pong")
			client:destroy()
			server:close()
		end

		function onWrite(err)
			console.log("client:write")
			assert(err == nil)
		end

		client:on("data", expect(onData))
		client:write("ping", expect(onWrite))
	end

	server = net.createServer(onServerConnection)
	server:listen(PORT, HOST)

	client = net.Socket:new()
	client:connect(PORT, HOST, onConnect)
end)

test("unix socket", function(expect)
	local server, client, onServerConnection, onConnect
	function onServerConnection(client)
		local onData

		function onData(chunk)
			local onWrite

			function onWrite(err)
				console.log("server:client:write")
				assert(err == nil)
				client:destroy()
			end

			console.log('server:client:on("data")', chunk)
			assert(chunk == "ping")
			client:write("pong", onWrite)
		end

		client:on("data", expect(onData))
	end

	function onConnect()
		console.log('client:on("complete")')
		local onData, onWrite

		function onData(data)
			console.log('client:on("data")', data)
			assert(data == "pong")
			client:destroy()
			server:close()
		end

		function onWrite(err)
			console.log("client:write")
			assert(err == nil)
		end

		client:on("data", expect(onData))
		client:write("ping", expect(onWrite))
	end

	server = net.createServer(onServerConnection)
	server:on(
		"error",
		function(error)
			console.log("server error", error)
		end
	)

	server:listen(sockname)

	client = net.Socket:new()
	client:on(
		"error",
		function(error)
			console.log("client error", error)
		end
	)

	client:connect(sockname, onConnect)
end)

tap.run()
