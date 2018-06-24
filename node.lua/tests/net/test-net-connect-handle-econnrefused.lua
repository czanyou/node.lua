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
local PORT = 10088

local tap = require("ext/tap")
local test = tap.test

test("net-connect-handle-econnerefuesed", function(expected)
	local client, err = net.createConnection(PORT)
	client:on("connect", function()
		print("error: connnected, please shutdown whatever is running on " .. PORT)
		assert(false)
	end)

	client:on("error", function(err)
		console.log(err)
		assert("ECONNREFUSED" == err or "EADDRNOTAVAIL" == err)
		expected = {gotError = true}
		client:destroy()
	end)
end)

tap.run()
