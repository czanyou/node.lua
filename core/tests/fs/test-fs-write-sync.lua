--[[

Copyright 2015 The Luvit Authors. All Rights Reserved.

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
local path = require('path')
local Buffer = require('buffer').Buffer
local dirname = require('util').dirname()

test('fs.writeSync', function()
	local fn = path.join(dirname, 'fixtures', 'write.txt')
	local foo = 'foo'

	local fd = fs.openSync(fn, 'w')
	local written = fs.writeSync(fd, -1, '')
	assert(written == 0)
	fs.writeSync(fd, -1, foo)
	local bar = 'bár'

	-- TODO: Support buffer argument
	written = fs.writeSync(fd, -1, Buffer:new(bar):toString())
	assert(written > 3)
	fs.closeSync(fd)
	
	assert(fs.readFileSync(fn) == 'foobár')
end)

tap.run()
