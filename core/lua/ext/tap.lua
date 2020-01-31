--[[

Copyright 2016 The Node.lua Authors. All Rights Reserved.

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

-- test
_G.module       = {}
_G.module.dir   = uv.cwd()
_G.module.path  = uv.cwd()
_G.p            = console.log

-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --

local tests = {};
local single = true
local prefix = nil

local function _run_tests()
	local passed = 0

	if #tests < 1 then
		error("!!! No tests specified!")
		return
	end

	print(colorize("success", "<<<< Test Suite with " .. #tests .. " Tests >>>>"))

	for i = 1, #tests do
		local test = tests[i]

		print(colorize("highlight", "#### Runing Test " .. i .. "/" .. #tests .. " '" .. test.name .. "' #### "))

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
			print("---- Finish '" .. test.name .. "'.\n")
			passed = passed + 1

		else
			print(err)
			print(colorize("err", "!!!! Failed '" .. test.name .. "'. !!!!\n"))
		end
	end -- end for i = 1, #tests do

	-- failed count
	local failed = #tests - passed
	if failed == 0 then
		print(colorize("success", "### All tests passed ###"))
	else
		print(colorize("err", "### " .. failed .. " failed test" .. (failed == 1 and "" or "s") .. " ###"))
	end

	-- Close all then handles, including stdout
	--uv.walk(uv.close)
	uv.run()
	os.exit(-failed)

	return passed, failed, #tests
end

-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --

-- 添加测试用例
---@param name string 测试用例名称
---@param func function 测试用例
local test = function (name, func) -- test function
	if prefix then
		name = prefix .. ' - ' .. name
	end

	table.insert(tests, { name = name, func = func })
end

-- 测试
local function tap(suite)
	if (type(suite) == "function") then
		-- 执行测试套件
		suite(test)
		prefix = nil

	elseif (type(suite) == "string") then
		-- 执行测试套件
		prefix = suite
		single = false

	else
		-- Or pass in false to collect several runs of tests
		-- And then pass in true in a later call to flush tests queue.
		single = suite
	end

	if single then
		_run_tests()
	end
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

local exports = {}

function exports.suite(name)
	prefix = name
	single = false
end

-- 执行指定目录下所有测试用例
---@param dirname string 目录名
function exports.testAll(dirname)
	package.path = package.path .. ';' .. dirname .. '/?.lua'

	local req = uv.fs_scandir(dirname)

	repeat
		local name = uv.fs_scandir_next(req)
		if not name then
			-- run the tests!
			exports.run(true)
		end

		local match = string.match(name, "^test%-(.*).lua$")
		if match then
			local path = dirname .. "/test-" .. match .. ".lua"
			exports.suite(match)

			local script = loadfile(path)
			script()
		end
	until not name
end

exports.test = test

-- 开始运行所有测试用例
exports.run = function(runAll)
	if single or runAll then
		return _run_tests()
	end
end

setmetatable(exports, {
	__call = function(self, ...)
		return tap(...)
	end
})

return exports
