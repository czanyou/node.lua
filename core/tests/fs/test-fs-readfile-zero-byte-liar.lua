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
local Path = require('path')

local string = require('string')
local filename = require('util').filename()

local dataExpected = fs.readFileSync(filename)

test('fs readfile zero byte liar', function()
	-- sometimes stat returns size=0, but it's a lie.
	local _fstat,_fstatSync = fs.fstat,fs.fstatSync
	fs._fstat = fs.fstat
	fs._fstatSync = fs.fstatSync

	fs.fstat = function(fd, cb)
	  fs._fstat(fd, function(er, st)
		if er then
		  	return cb(er)
		end
		st.size = 0
		return cb(er, st)
	  end)
	end

	fs.fstatSync = function(fd)
	  local st = fs._fstatSync
	  st.size = 0
	  return st
	end

	local d = fs.readFileSync(filename)
	assert(d == dataExpected)

	fs.readFile(filename, function (er, d)
		assert(d == dataExpected)
		fs.fstat, fs.fstatSync = _fstat, _fstatSync
	end)
end)

tap.run()
