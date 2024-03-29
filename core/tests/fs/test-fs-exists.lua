--[[

Copyright 2012-2015 The Luvit Authors. All Rights Reserved.

Licensed under the Apache License, Version 2.0 (the "License")
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

	http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS-IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

--]]

local tap = require('util/tap')
local test = tap.test

local fs = require('fs')

local dirname = require('util').dirname()

test('fs.exists', function(expect)
	-- TODO: Is it OK that this callback signature is different from node.js,
	--       which is function(exists)?
	fs.exists(dirname, function(err, y)
		assert(y)
	end)

	fs.exists(dirname .. '-NO', function(err, y)
		assert(not y)
	end)

	assert(fs.existsSync(dirname))
	assert(not fs.existsSync(dirname .. '-NO'))
end)

tap.run()