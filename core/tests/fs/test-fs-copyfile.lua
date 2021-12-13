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
local uv = require('luv')
local path = require('path')
local util = require('util')

local dirname = util.dirname()
local tmp = os.tmpdir

test('fs.copyfile', function(expect)
	local src = path.join(dirname, 'run.lua')
	local dest1 = path.join(tmp, 'run1.test')

	console.log(src, dest1);

	-- async
	fs.copyfile(src, dest1, expect(function(err, y)
		assert(not err)
		assert(y)

		local fileData = fs.readFileSync(dest1, 'a')
		--console.log(#fileData)
		assert(#fileData > 1)

		os.remove(dest1)
		--  assert(y)
	end))

	-- sync
	local dest2 = path.join(tmp, 'run2.test')
	assert(fs.copyfileSync(src, dest2))

	local fileData = fs.readFileSync(dest2, 'a')
	--console.log(#fileData)
	assert(#fileData > 1)

	os.remove(dest2)
end)

tap.run()