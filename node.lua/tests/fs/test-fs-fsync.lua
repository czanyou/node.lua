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

local tap = require('ext/tap')
local test = tap.test

local fs = require('fs')
local path = require('path')
local dirname = require('util').dirname()

test('fs sync operation', function(expect)
	local file = path.join(dirname, 'fixtures', 'a.lua')

	console.log('open ' .. file)

	fs.open(file, 'a', '0777', function(err, fd)
		--print(err, fd)
		console.log('fd ' .. fd)
		assert(not err)

		assert(fs.fdatasyncSync(fd))
		--console.log('fdatasync SYNC: ok')

		assert(fs.fsyncSync(fd))
		--console.log('fsync SYNC: ok')

		fs.fdatasync(fd, function(err)
			assert(not err)
			--console.log('fdatasync ASYNC: ok')
			fs.fsync(fd, function(err)
				assert(not err)
				--console.log('fsync ASYNC: ok')
			end)
		end)
	end)

end)

tap.run()
