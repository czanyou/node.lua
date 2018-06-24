--[[

Copyright 2012-2015 The Luvit Authors. All Rights Reserved.

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

local PORT = 10087
local HOST = "127.0.0.1"

local tap = require("ext/tap")
local test = tap.test

test("net-buffer-write-before-connect", function(expected)
	local server = net.createServer(function(client)
		console.log("accepted")
		client:on("data", function(chunk)
			console.log("server get data", chunk)
			client:write(chunk, function(err)
				assert(err == nil)
				client:destroy()
				console.log("server close client")
			end)
		end)
	end)

	local client
	local receivedMessage = false

	server:listen(PORT, HOST, function()
		console.log("server listening")
		local msg = "hello world"
		client = net.Socket:new()
		client:connect(PORT, HOST, function()
			console.log("client connected")
			client:on("data", function(data)
				receivedMessage = true
				server:close()
				assert(data == msg)
			end)

			client:on("end", function()
				assert(receivedMessage == true)
				client:destroy()
				console.log("client end")
			end)

			client:on("error", function(err)
				assert(err)
			end)

			client:write(msg, function()
				console.log("client write")
			end)
		end)
	end)

	server:on("error", function(err)
		assert(err)
	end)
end)

tap.run()
