--[[

Copyright 2015 The Luvit Authors. All Rights Reserved.

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
--local json = require('json')
local deepEqual = require("assert").isDeepEqual

local json = require("json")
local cjson = require("cjson")

local tap = require("ext/tap")
local test = tap.test

test(
	"smoke",
	function()
		assert(json.stringify({a = "a"}) == '{"a":"a"}')
		deepEqual({a = "a"}, json.parse('{"a":"a"}'))
	end
)
test(
	"parse invalid json",
	function()
		for _, x in ipairs({"", " ", "{", "[", '{"f":', '{"f":1', '{"f":1'}) do
			local status, _, result = pcall(json.parse, x)
			assert(status)
			assert(result)
		end
		for _, x in ipairs({"{]", "[}"}) do
			local status, _, result = pcall(json.parse, x)
			assert(status)
			assert(result)
		end
	end
)
test(
	"parse valid json",
	function()
		for _, x in ipairs({"[]", "{}"}) do
			local _, result = pcall(json.parse, x)
			assert(type(result) == "table")
		end
	end
)
test(
	"stringify",
	function()
		assert(json.stringify() == "null")
		for _, x in ipairs({{}, {1, 2, 3}, {a = "a"}, "string", 0, 0.1, 3.1415926, true, false}) do
			local status, result = pcall(json.stringify, x)
			assert(status)
			assert(type(result) == "string")
		end
	end
)
test(
	"edge cases",
	function()
		print("json.stringify({})", json.stringify({}))

		assert(json.stringify({}) == "[]")

		-- escaped strings
		assert(json.stringify('a"b\tc\nd') == '"a\\"b\\tc\\nd"')
		assert(json.parse('"a\\"b\\tc\\nd"') == 'a"b\tc\nd')

		-- booleans
		assert(json.stringify(true) == "true")
		assert(json.stringify(false) == "false")
		assert(json.parse("true") == true)
		assert(json.parse("false") == false)
	end
)
test(
	"strict",
	function()
		for _, x in ipairs({"{f:1}", "{'f':1}"}) do
			local status, _, _ = pcall(json.parse, x)
			assert(status)
		end
	end
)
test(
	"unicode",
	function()
		local s = '{"f":"����ˤ��� ����"}'
		local obj = json.parse(s)
		assert(obj.f and obj.f == "����ˤ��� ����")
	end
)
test(
	"null",
	function()
		--console.log(cjson)
		--console.log(json)

		local null = json.null
		--console.log(json.null == cjson.null)

		local array = {null, null, null, null, null}
		--console.log(array)

		local text = json.stringify(array)
		console.log(text)

		console.log(json.parse(text))
	end
)

test(
	"number",
	function()
		local text = '{"value":100}'
		console.log(json.parse(text))
	end
)

tap.run()
