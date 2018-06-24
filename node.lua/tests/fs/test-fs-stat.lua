--[[

Copyright 2012 The Luvit Authors. All Rights Reserved.

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
local json = require('json')

test('fs.stat', function()
	fs.stat('.', function(err, stats)
		assert(not err)
		--console.log(stats)
		assert(type(stats.mtime.sec) == 'number')
	end)
end)

test('fs.lstat', function()
	fs.lstat('.', function(err, stats)
		assert(not err)
		--console.log(stats)
		assert(type(stats.mtime.sec) == 'number')
	end)
end)

  -- fstat
test('fs.open', function()
	fs.open('.', 'r', function(err, fd)
		assert(not err)
		assert(fd)
		fs.fstat(fd, function(err, stats)
			assert(not err)
			--console.log(json.stringify(stats))
			assert(type(stats.mtime.sec) == 'number')
			fs.close(fd)
		end)
	end)
end)

  -- fstatSync
test('fstatSync', function()
	fs.open('.', 'r', function(err, fd)
		local ok, stats
		ok, stats = pcall(fs.fstatSync, fd)
		assert(ok)
		if stats then
			--console.log(json.stringify(stats))
			assert(type(stats.mtime.sec) == 'number')
		end
		fs.close(fd)
	end)
end)

test('stat', function()
	local dirname = require('util').dirname()

	local path = dirname .. "/fixtures/x.txt"
	console.log('stating: ' .. path)
	fs.stat(path, function(err, s)
		assert(not err)
		--console.log(json.stringify(s))
		assert(s.type == 'file')
		assert(type(s.mtime.sec) == 'number')
	end)
end)

tap.run()


