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
local path = require('path')
local dirname = require('util').dirname()

test('fs.read and fs.readSync', function()
	local filepath = path.join(dirname, 'fixtures', 'x.txt')
	print(filepath)

	local fd = fs.openSync(filepath, 'r')
	local expected = 'xyz\n'
	local readCalled = 0

	fs.read(fd, #expected, 0, function(err, fileData, bytesRead)
		readCalled = readCalled + 1
		assert(not err)
		assert(fileData == expected)
		assert(#fileData == #expected)
	end)

	local fileData, e = fs.readSync(fd, #expected, 0)
	assert(fileData == expected)
	assert(#fileData == #expected)
end)

tap.run()

