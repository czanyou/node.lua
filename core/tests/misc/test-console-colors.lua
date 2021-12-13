--[[

Copyright 2012 The Luvit Authors. All Rights Reserved.

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

local dump = console.dump
local strip = console.strip

local tap = require('util/tap')
local test = tap.test

test("Recursive values", function()
	console.loadColors(0)

	local data = {a = "value"}
	data.data = data
	local out = dump(data)
	local stripped = strip(out)
	print("recursive", out, stripped)

	console.loadColors()
	-- assert(string.match(stripped, "{ a = 'value', data = table: 0x%x+ }"))
end)

test("string escapes", function()
	local tests = {
		"\000\001\002\003\004\005\006\a\b\t\n\v\f\r\014\015",
		".......\\a\\b\\t\\n\\v\\f\\r..",
		"\016\017\018\019\020\021\022\023\024\025\026\027\028\029\030\031",
		"................",
		' !"#$%&\'()*+,-./',
		' !"#$%&\'()*+,-./',
		"0123456789:;<=>?",
		"0123456789:;<=>?",
		"@ABCDEFGHIJKLMNO",
		"@ABCDEFGHIJKLMNO",
		"PQRSTUVWXYZ[\\]^_",
		"PQRSTUVWXYZ[\\]^_", -- "'PQRSTUVWXYZ[\\\\]^_",
		"`abcdefghijklmno",
		"`abcdefghijklmno",
		"pqrstuvwxyz{|}",
		"pqrstuvwxyz{|}"
	}

	for i = 1, 16, 2 do
		local out = dump(tests[i])
		local stripped = strip(out)
		print('out      ', out)
		print('stripped ', stripped, tests[i + 1])
		assert(stripped == tests[i + 1], stripped)
	end
end)

test("Smart quotes in string escapes", function()
	local tests = {
		"It's a wonderful life",
		'It\'s a wonderful life',
		'To "quote" or not to "quote"...',
		'To "quote" or not to "quote"...',
		'I\'ve always liked "quotes".',
		'I\'ve always liked "quotes".'
	}

	for i = 1, 6, 2 do
		local out = dump(tests[i])
		local stripped = strip(out)
		print('out      ', out)
		print('stripped ', stripped)
		assert(stripped == tests[i + 1])
	end
end)

test("Color mode switching", function()
	local data = {42, true, "A\nstring"}

	-- none
	console.loadColors(0)
	local plain = dump(data)
	console.loadColors()
	print("plain colors:", plain)

	-- 16 colors
	console.loadColors(16)
	local colored = dump(data)
	console.loadColors()
	print("16 colors:", colored)

	-- 256 colors
	console.loadColors(256)
	local super = dump(data)
	console.loadColors()
	print("256 colors:", super)
end)

test("Color", function()
	local text = dump(tap)
	print('tap', text)
end)

tap.run()
