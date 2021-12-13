local utils = require('util')
local assert = require('assert')
local Object = require('core').Object

local tap = require('util/tap')
local test = tap.test

test("test utils.dirname", function(expect)
	local ret = utils.dirname()
	--assert.equal(ret, 'ABCDEF012345')
	print("utils.dirname", ret)
end)

test("test utils.filename", function(expect)
	local path = require('path')
	local ret = utils.filename()
	assert.equal(path.basename(ret), "test-util.lua")
	print("utils.filename", ret)

	print("utils.filename(0)", utils.filename(0))
	print("utils.filename(1)", utils.filename(1))
	print("utils.filename(2)", utils.filename(2))
	print("utils.filename(3)", utils.filename(3))
	print("utils.filename(4)", utils.filename(4))
	print("utils.filename(5)", utils.filename(5))
	print("utils.filename(6)", utils.filename(6))
end)

test("test utils.base64Encode", function(expect)
	local ret = utils.base64Encode("ABCDEF012345")
	assert.equal(ret, "QUJDREVGMDEyMzQ1")
end)

test("test utils.base64Decode", function(expect)
	local ret = utils.base64Decode("QUJDREVGMDEyMzQ1")
	assert.equal(ret, "ABCDEF012345")
end)

test("test utils.hexEncode", function(expect)
	local ret = utils.hexEncode("\0\2\10\16\32ABC123")
	assert.equal(ret, "00020a1020414243313233")
end)

test("test utils.hex2bin", function(expect)
	local ret = utils.hex2bin("00020a1020414243313233")
	assert.equal(ret, "\0\2\10\16\32ABC123")
end)

test("test utils.crc32", function(expect)
	local ret = utils.crc32("test.com")
	assert.equal(string.format("%x", ret), '3dab4b68')
end)

test("test utils.md5", function(expect)
	local ret = utils.md5("test.com")
	assert.equal(utils.hexEncode(ret), "c97c1b3671fef2055e175ca2154d217a")
end)

test("test utils.sha1", function(expect)
	local ret = utils.sha1("test.com")
	assert.equal(utils.hexEncode(ret), "5f543afdb6ba8aeef955c6c951d3bd70c1de8361")
end)

test("utils.bind", function(expect)
	local BindHelper = Object:extend()

	function BindHelper:test(a, b, c)
		console.log(self, a, b, c)
	end

	function test(arg, callback)
		callback(arg)
	end

	local object = BindHelper:new()
	test(100, object.test)

	local object = BindHelper:new()
	test(100, utils.bind(object.test, object, "a"))
end)

test("utils.bind", function(expect)
	local BindHelper = Object:extend()

	function BindHelper:func1(arg1, callback, ...)
		assert(self ~= nil)
		callback(arg1)
	end

	function BindHelper:func2(arg1, arg2, callback)
		assert(self ~= nil)
		callback(arg1, arg2)
	end

	function BindHelper:func3(arg1, arg2, arg3, callback)
		assert(self ~= nil)
		callback(arg1, arg2, arg3)
	end

	local testObj = BindHelper:new()
	local bound

	bound = utils.bind(BindHelper.func1, testObj)
	bound(
		"hello world",
		function(arg1)
			assert(arg1 == "hello world")
		end
	)
	bound(
		"hello world1",
		function(arg1)
			assert(arg1 == "hello world1")
		end
	)

	bound = utils.bind(BindHelper.func1, testObj, "hello world")
	bound(
		function(arg1)
			assert(arg1 == "hello world")
		end
	)
	bound(
		function(arg1)
			assert(arg1 == "hello world")
		end
	)
	bound(
		function(arg1)
			assert(arg1 == "hello world")
		end
	)

	bound = utils.bind(BindHelper.func2, testObj)
	bound(
		"hello",
		"world",
		function(arg1, arg2)
			assert(arg1 == "hello")
			assert(arg2 == "world")
		end
	)
	bound(
		"hello",
		"world",
		function(arg1, arg2)
			assert(arg1 == "hello")
			assert(arg2 == "world")
		end
	)

	bound = utils.bind(BindHelper.func2, testObj, "hello")
	bound(
		"world",
		function(arg1, arg2)
			assert(arg1 == "hello")
			assert(arg2 == "world")
		end
	)

	bound = utils.bind(BindHelper.func3, testObj)
	bound(
		"hello",
		"world",
		"!",
		function(arg1, arg2, arg3)
			assert(arg1 == "hello")
			assert(arg2 == "world")
			assert(arg3 == "!")
		end
	)

	bound = utils.bind(BindHelper.func3, testObj)
	bound(
		"hello",
		nil,
		"!",
		function(arg1, arg2, arg3)
			assert(arg1 == "hello")
			assert(arg2 == nil)
			assert(arg3 == "!")
		end
	)

	bound = utils.bind(BindHelper.func3, testObj, "hello", "world")
	bound(
		"!",
		function(arg1, arg2, arg3)
			assert(arg1 == "hello")
			assert(arg2 == "world")
			assert(arg3 == "!")
		end
	)

	bound = utils.bind(BindHelper.func3, testObj, "hello", nil)
	bound(
		"!",
		function(arg1, arg2, arg3)
			assert(arg1 == "hello")
			assert(arg2 == nil)
			assert(arg3 == "!")
		end
	)

	bound = utils.bind(BindHelper.func3, testObj, nil, "world")
	bound(
		"!",
		function(arg1, arg2, arg3)
			assert(arg1 == nil)
			assert(arg2 == "world")
			assert(arg3 == "!")
		end
	)

	local tblA = {1, 2, 3}
	local tblB = {tblA, "test1", "test2", {tblA}}
	local s = console.dump(tblB, true, true)
	--assert(s == "{ { 1, 2, 3 }, 'test1', 'test2', { { 1, 2, 3 } } }")

	local Error = require('core').Error
	local MyError = Error:extend()
	assert(pcall(console.dump, MyError))
end)

test("test formatBytes", function ()
	assert.equal(utils.formatBytes(0), '0')
	assert.equal(utils.formatBytes(nil), nil)
	assert.equal(utils.formatBytes('test'), nil)
	assert.equal(utils.formatBytes(true), nil)

	assert.equal(utils.formatBytes(1024), '1K')
	assert.equal(utils.formatBytes(1024 * 1024), '1M')
	assert.equal(utils.formatBytes(1024 * 1024 * 1024), '1G')

	console.log(utils.formatBytes(1024 * 1024))
end)

test("test formatFloat", function ()
	assert.equal(utils.formatFloat(0), '0.0')
	assert.equal(utils.formatFloat(nil), nil)
	assert.equal(utils.formatFloat('test'), nil)
	assert.equal(utils.formatFloat(true), nil)

	assert.equal(utils.formatFloat(3.1415), '3.1')
	assert.equal(utils.formatFloat(3.1415, 3), '3.142')
end)

test("test formatNumber", function ()
	print(utils.formatNumber(10))
	print(utils.formatNumber(100 / 10))
end)

test("test formatTable", function ()
	local data = {
		{ a = 'object', b = 4653, c = 33.21 },
		{ a = 'boolean', b = 4653343, c = 4.3444 },
		{ a = 'function', b = 23, c = 233434.4 },
		{ a = 'table', b = 77, c = 88.01 },
		{ a = 'string', b = 345500, d = 34500.003 },
		{ a = 'number', b = 440, c = 2222.022 }
	}

	print(utils.formatTable(data, {'a', 'b', 'c'}))
end)

test("test clone", function ()
	local data = {
		a = 'test',
		b = 100,
		c = {
			d = 99,
			e = 'end'
		}
	}

	local result = utils.clone(data)
	console.printr(result)

	result.a = 'next'
	result.b = 111

	console.printr(data)
	console.printr(utils.keys(data))
end)


test("test diff", function ()
	local data1 = {
		a = 'test',
		b = 100,
		c = false,
		e = '100',
		f = 99,
		g = 'test'
	}

	local data2 = {
		b = 101,
		c = true,
		d = 'test',
		e = 100,
		f = 99,
		g = 'test'
	}

	local add, sub = utils.diff(data1, data2)
	console.printr(add, sub)

	add, sub = utils.diff(data2, add)
	console.printr(add, sub)

	add, sub = utils.diff(data1, data1)
	console.printr(add, sub)

	add, sub = utils.diff(nil, data1)
	console.printr(add, sub)

	add, sub = utils.diff(data1, nil)
	console.printr(add, sub)
end)

test("test random", function ()
	console.log(utils.random(32))
	console.log(utils.randomString(32))
end)

tap.run()


