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

local math = require('math')
local string = require('string')
local fs = require('fs')
local path = require('path')

local successes = 0

  -- make a path that will be at least 260 chars long.
local dirname = require('util').dirname()
local tmpDir = path.join(dirname, 'fixtures')

local fileNameLen = math.max(260 - #tmpDir - 1, 1)
local fileName = path.join(tmpDir, string.rep('x', fileNameLen))

test('fs longpoath', function(expect)
	console.log('fileName =', fileName)
	console.log('fileNameLength =', #fileName)

	fs.writeFile(fileName, 'ok', function(err)
		if err then
			return err
		end
		successes = successes + 1

		fs.stat(fileName, function(err, stats)
			if err then
				return err
			else
				successes = successes + 1
				assert(successes == 2)
				if successes > 0 then
					fs.unlinkSync(fileName)
				end
			end
		end)
	end)
end)

tap.run()
