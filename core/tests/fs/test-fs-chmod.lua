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

local fs    = require('fs')
local path  = require('path')
local string = require('string')
local assert = require('assert')

local isWindows = os.platform() == 'win32'
local __dirname = require('util').dirname()

console.log('isWindows', isWindows)
console.log('__dirname', __dirname)

local mode_async
local mode_sync

-- On Windows chmod is only able to manipulate read-only bit
-- TODO: test on windows
if isWindows then
	mode_async = 256 --[[tonumber('0400', 8)]] -- read-only
	mode_sync  = 438  --[[tonumber('0600', 8)]] -- read-write
else
	mode_async = 511 --[[tonumber('0777', 8)]]
	mode_sync  = 420 --[[tonumber('0644', 8)]]
end

local file1 = path.join(__dirname, 'fixtures', 'a.lua')
local file2 = path.join(__dirname, 'fixtures', 'a1.lua')

local function maskMode(mode, mask)
	local ret = (mode & (mask or 511) --[[tonumber('0777',8)]])
	console.log(string.format("0x%X", mode), mask, ret)
	return ret
end

test('fs chmod 1', function(expect)

	console.log('file1', file1, mode_async, mode_sync)
	fs.chmod(file1, mode_async, expect(function(err)
		assert(not err)

		if isWindows then
			assert(maskMode(maskMode(fs.statSync(file1).mode), mode_async))
		else
			-- assert.equal( maskMode(fs.statSync(file1).mode), mode_sync)
		end

		-- TODO: accept mode in number
		assert(fs.chmodSync(file1, mode_sync))

		if isWindows then
			assert(maskMode(maskMode(fs.statSync(file1).mode), mode_sync))
		else
			--assert.equal(maskMode(fs.statSync(file1).mode), mode_sync)
		end
	end))

end)

test('fs chmod 2', function(expect)

	console.log('file2', file1, mode_async, mode_sync)
	fs.open(file2, 'a', tonumber('0666', 8), expect(function(err, fd)
		assert(not err, err)

		fs.fchmod(fd, mode_async, expect(function(err)
			assert(not err)

			if isWindows then
				assert(maskMode(maskMode(fs.fstatSync(fd).mode), mode_async))
			else
				assert.equal(maskMode(fs.fstatSync(fd).mode), mode_async)
			end

			-- TODO: accept mode in number
			assert(fs.fchmodSync(fd, mode_sync))
			if isWindows then
				assert(maskMode(maskMode(fs.fstatSync(fd).mode), mode_sync))
			else
				--assert.equal(maskMode(fs.fstatSync(fd).mode), mode_sync)
			end

			fs.close(fd)
		end))
	end))

end)

test('fs chmod 3', function(expect)

	-- lchmod
	if fs.lchmod then
		local link = path.join(__dirname, 'fixtures', 'symbolic-link')
		fs.unlinkSync(link)
		fs.symlinkSync(file2, link)

		fs.lchmod(link, mode_async, expect(function(err)
			assert(not err)
			console.log(fs.lstatSync(link).mode)
			assert(mode_async == maskMode(fs.lstatSync(link).mode))

			-- TODO: accept mode in number
			fs.lchmodSync(link, string.format('%o', mode_sync))
			assert(mode_sync == maskMode(fs.lstatSync(link).mode))
		end))
	end
end)

tap.run()

