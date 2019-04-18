local tap 	    = require("ext/tap")
local utils     = require('util')
local assert    = require('assert')

local test = tap.test

test("assert true", function()
	assert(true)
	assert(0)
	assert('')
end)

test("assert equal", function()
	assert.equal(0, tonumber('0'))
	assert.equal('abc', 'abc')
	assert.equal(1.1, 1.1)
	assert.equal(1.0, 1)
	assert.equal(nil, nil)
	assert.equal(true, true)
	assert.equal(test, test)
	assert.equal(assert, assert)

	assert.equal(1, '1')
	assert.equal(1.1, '1.1')

	assert.equal(false, pcall(assert.equal, true, 'true'))
	assert.equal(false, pcall(assert.equal, nil, 'error'))
	assert.equal(false, pcall(assert.equal, 'error', ' error'))
end)

test("assert ifError", function()
	assert.ifError(false)
	assert.ifError(nil)
	assert.equal(false, pcall(assert.ifError, 'error'))
	assert.equal(false, pcall(assert.ifError, 0))
end)

test("assert not equal", function()   
	assert.notEqual(1.1, 1)
	assert.notEqual(nil, false)
	assert.notEqual(true, 'true')
	assert.notEqual(false, '')
	assert.notEqual(' ', '')
	assert.notEqual({}, {})

	assert.equal(false, pcall(assert.notEqual, 1, '1'))
	assert.equal(false, pcall(assert.notEqual, 1, 1))
	assert.equal(false, pcall(assert.notEqual, nil, nil))
	assert.equal(false, pcall(assert.notEqual, '1', '1'))
	assert.equal(false, pcall(assert.notEqual, true, true))
end)

test("assert deep equal", function() 
	local a = { name = "9", list = { 1, 2, '3', true, {4, 5}}}
	local b = { list = { 1, 2, '3', true, {4, 5}}, name = "9"}
	assert.deepEqual(a, b)

	assert.deepEqual(0, 0)
	assert.deepEqual({}, {})
	assert.deepEqual({-1, 0, 1, true, 1.1, '1', ''}, {-1, 0, 1, true, 1.1, '1', ''})
end)

test("assert not deep equal", function() 
	local a = { name = "9", list = { 1, 2, 3 }}
	local b = { list = { 1, 2, 3, 4 }, name = "9"}
	assert.notDeepEqual(a, b)
end)

test("assert ok", function()
	assert.ok(true)
	assert.ok(0)
	assert.ok('')
	
	assert.equal(false, pcall(assert.ok, false))
	assert.equal(false, pcall(assert.ok, nil))
end)

tap.run()

