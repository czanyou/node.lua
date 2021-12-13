--[[

Copyright 2016-2020 The Node.lua Authors. All Rights Reserved.

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

local uv      = require('luv')

local colorize  = console.colorize

-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --

local exports = {}

local tests = {};
local prefix = nil

exports.index = 1

local function _runTests()
	local passed = 0

	if #tests < 1 then
		error("!!! No tests specified!")
		return
	end

	print(colorize("success", ">>> Test suite with " .. #tests .. " Tests >>>"))

	for i = 1, #tests do
		local test = tests[i]

		print(colorize("highlight", "### " .. i .. "/" .. #tests .. " " .. test.name .. " ### "))

		local cwd = uv.cwd()
		local pass, err = xpcall(function ()
			local expected = 0

			local function expect(func, count)
				expected = expected + (count or 1)
				return function (...)
					expected = expected - 1
					local ret = func(...)
					collectgarbage()
					return ret
				end
			end

			test.func(expect, uv)

			collectgarbage()
			uv.run()
			collectgarbage()

			if expected > 0 then
				error("Missing " .. expected .. " expected call" .. (expected == 1 and "" or "s"))

			elseif expected < 0 then
				error("Found " .. -expected .. " unexpected call" .. (expected == -1 and "" or "s"))
			end

			local errorInfo = exports.errorInfo
			exports.errorInfo = nil
			if (errorInfo) then
				print(errorInfo)
				error(errorInfo)
			end

			collectgarbage()

			if uv.cwd() ~= cwd then
				error("Test moved cwd from " .. cwd .. " to " .. uv.cwd())
			end

			collectgarbage()
		end, debug.traceback)

		-- Flush out any more opened handles
		uv.stop()
		uv.walk(function (handle)
			if handle == _G.stdout then return end
			--if not uv.is_closing(handle) then uv.close(handle) end
		end)
		uv.run()
		uv.chdir(cwd)

		if pass then
			print("--- Finish --> " .. test.name .. ".\n")
			passed = passed + 1

		else
			print(err)
			print(colorize("err", "!!! Failed '" .. test.name .. "'. !!!\n"))
		end
	end -- end for i = 1, #tests do

	-- failed count
	local failed = #tests - passed
	if failed == 0 then
		print(colorize("success", "### All tests passed ###"))
	else
		print(colorize("err", "### " .. failed .. " failed tests ###"))
	end

	-- Close all then handles, including stdout
	--uv.walk(uv.close)
	uv.run()
	os.exit(-failed)

	return passed, failed, #tests
end

-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --

exports.nextTimer = function()
	if (exports.timer) then
		return
	end

	exports.timer = setTimeout(200, function()
		exports.timer = nil;

		local now = process.now();
		-- console.log('tap.nextTimer', now)

		if (now - (exports.updated or 0) < 200) then
			exports.nextTimer()

		elseif (not exports.started) then
			exports.started = true
			_runTests()
		end
	end)
end

-- 添加测试用例
---@param name string 测试用例名称
---@param func function 测试用例
exports.test = function (name, func) -- test function
	if prefix then
		name = prefix .. '.' .. exports.index .. ' -> ' .. name
		exports.index = (exports.index or 1) + 1
	end

	table.insert(tests, { name = name, func = func })

	exports.updated = process.now()
	exports.nextTimer()
end

--[[
-- Sample Usage

local passed, failed, total = tap(function (test)

  test("add 1 to 2", function(expect)
	print("Adding 1 to 2")
	assert(1 + 2 == 3)
  end)

  test("close handle", function (expect, uv)
	local handle = uv.new_timer()
	uv.close(handle, expect(function (self)
	  assert(self == handle)
	end))
  end)

  test("simulate failure", function ()
	error("Oopsie!")
  end)

end)
]]

--return tap
---@param name string 测试套件名
function exports.suite(name)
	prefix = name

	exports.index = 1
end

-- 执行指定目录下所有测试用例
---@param dirname string 目录名
function exports.testAll(dirname)
	package.path = package.path .. ';' .. dirname .. '/?.lua'

	local cwd = process.cwd()
	uv.chdir(dirname)
	local req = uv.fs_scandir(dirname)

	repeat
		local name = uv.fs_scandir_next(req)
		if not name then
			-- run the tests!
			break
		end

		--- test-xxx-.lua
		local match = string.match(name, "^test%-(.*).lua$")
		if match then
			local path = dirname .. "/test-" .. match .. ".lua"
			exports.suite(match)

			local script = loadfile(path)
			script()
		end
	until not name

	uv.chdir(cwd)
end

-- 开始运行所有测试用例
exports.run = function() end

---@param error string
exports.error = function(error)
	exports.errorInfo = error
end

exports.assert = function(value, message)
	if (not value) then
		message = message or ('Expected is [true], but is [' .. tostring(value) .. ']')
		exports.errorInfo = message
		error(message)
	end
end

-- test
_G.p = console.log
_G.describe = exports.test

return exports
