local tap 	    = require("ext/tap")
local utils     = require('util')
local assert    = require('assert')
local Buffer    = require('buffer').Buffer

tap(function(test)
    test("assert true", function()
    	assert(true)
    	assert(0)
    	assert('')
    end)

    test("assert not true", function()
    	assert(not (false))
    	assert(not (nil))
    end)

    test("assert equal", function()
    	assert.equal(0, tonumber('0'))
    	assert.equal('abc', 'abc')
    	assert.equal(1.1, 1.1)
    	assert.equal(1.0, 1)
    	assert.equal(true, true)
    	assert.equal(test, test)
    	assert.equal(assert, assert)

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
    	assert.notEqual(0, '0')
    	assert.notEqual(nil, false)
    	assert.notEqual(false, '')
    	assert.notEqual(' ', '')

        assert.equal(false, pcall(assert.notEqual, 1, 1))
    end)

    test("assert deep equal", function() 
        local a = { name = "9", list = { 1, 2, '3', true, {4, 5}}}
        local b = { list = { 1, 2, '3', true, {4, 5}}, name = "9"}
        assert.deepEqual(a, b) name = "9"
    end)

    test("assert not deep equal", function() 
        local a = { name = "9", list = { 1, 2, 3 }}
        local b = { list = { 1, 2, 3, 4 }, name = "9"}
        assert.notDeepEqual(a, b) name = "9"
    end)   

    test("assert ok", function()
    	assert.ok(true)
    	assert.ok(0)
    	assert.ok('')
    end)

    test("assert not ok", function()
    	assert.ok(not (false))
    	assert.ok(not (nil))
    end)
   
end)

