local assert    = require('assert')
local Promise   = require('promise')
local util      = require('util')

local tap = require('util/tap')
local test = tap.test

test("test promise.new", function()
    local promise = Promise.new();
    console.log(promise)
    
    assert.equal(type(promise.resolve), 'function')
    assert.equal(type(promise.reject), 'function')
    assert.equal(type(promise.next), 'function')
    assert.equal(type(promise.catch), 'function')
end)

test("test promise.resolve", function()
    local promise = Promise.new();
    promise:resolve('ok')
    console.log(promise.state)
    assert.equal(promise.state, 'fulfilled')

    promise = Promise.new();
    promise:reject('bad')
    console.log(promise.state)
    assert.equal(promise.state, 'rejected')
    assert.equal(promise.value, 'bad')
end)

test("test promise.reject", function()
    local promise = Promise.new();
    promise:resolve('ok')
    console.log(promise.state)
    console.log(promise.value)
    assert.equal(promise.state, 'fulfilled')
    assert.equal(promise.value, 'ok')

    promise:reject('bad')
    console.log(promise.state)
    console.log(promise.values)
    assert.equal(promise.state, 'fulfilled')
end)

test("test promise.next", function()
    local promise = Promise.new();
    local ret = promise:next();
    console.log(ret, ret.next)
    assert.equal(type(ret and ret.next), 'function')
end)

test("test promise.next 2", function()
    local promise = Promise.new();
    promise:next(function(value)
        console.log('value', value)
        return 'test'
    end);

    promise:resolve('ok')

    console.log(promise.state, promise.value)
end)

test("test promise.callback", function()
    local promise = Promise.new(function (resolve, reject)
        resolve('ok')
        reject('bad')
    end);

    promise:next(function(value)
        console.log('value', value)
        return 'test'
    end);

    console.log(promise.state, promise.value)
end)

test("test promise.next x", function()
    local promise = Promise.new();
    promise:next(function(value)
        console.log('value1', value)
        return 'test1'
    end):next(function(value)
        console.log('value2', value)
        return 2
    end):next(function(value)
        console.log('value3', value)
        return function() end
    end):next(function(value)
        console.log('value4', value)
        return 'test4'
    end);

    promise:resolve('ok')

    console.log(promise.state, promise.value)
end)

test("test promise.next x2", function()
    local promise = Promise.new();
    local promise2 = nil;
    promise:next(function(value)
        console.log('value', value)
        
        promise2 = Promise.new();

        setTimeout(10, function()
            promise2:resolve('ok2')
        end)

        return promise2

    end):next(function(value)
        console.log('value4', value)
        return 'test4'
    end);

    promise:resolve('ok')

    console.log(promise.state, promise.value)
end)

test("test promise.next 2", function()
    local promise1 = Promise.new();
    local promise2 = Promise.new();
    local promise3 = Promise.new();
    local promise = Promise.all(promise1, promise2, promise3)

    promise:next(function(value)
        console.log('value', value)

    end, function(error)
        console.log('error', error)
    end);

    promise1:resolve('ok1')
    promise2:reject('bad2')
    promise3:resolve('ok3')

    console.log(promise.state, promise.value)
end)

test("test promise.next 3", function()
    local promise1 = Promise.new();
    local promise2 = Promise.new();
    local promise3 = Promise.new();
    local promise = Promise.race(promise1, promise2, promise3)

    promise:next(function(value)
        console.log('value', value)

    end, function(error)
        console.log('error', error)
    end);

    promise1:resolve('ok1')
    promise2:resolve('bad2')
    promise3:resolve('ok3')

    console.log(promise.state, promise.value)
end)

test("test promise.next 4", function()
    local promise = Promise.new(function(resolve, reject)
        resolve('ok')
    end)

    promise:next(function(value)
        console.log('value1', value)
        error('bad')
    end):catch(function(error)
        console.log('error', error)
    end):next(function(value)
        console.log('value2', value)
    end, function(error)
        console.log('error2', error)
    end)
end)

test("test util.promisify - fulfill", function(expect, ...)
    local function testfunc(input, callback)
        setTimeout(0, function()
            callback(nil, input .. 'test')
        end)
    end

    local func = util.promisify(testfunc)
    func(100):next(expect(function(value)
        console.log('result', value)
        assert(false)
    end)):catch(expect(function(error)
        console.log('error', error)
        -- setImmediate(function() assert(false) end)
    end))
end)

test("test util.promisify - reject with error result", function()
    local function testfunc(input, callback)
        setTimeout(0, function()
            callback('bad')
        end)
    end

    local func = util.promisify(testfunc)
    func(100):next(function(value)
        console.log('result', value)
        assert(false)
    end, function(error)
        console.log('error', error)
        assert(error ~= nil)
    end)
end)

test("test util.promisify - reject with error()", function()
    local function testfunc(input, callback)
        error('bad')
    end

    local func = util.promisify(testfunc)
    func(100):next(function(value)
        console.log('result', value)
        assert(false)
    end, function(error)
        console.log('error', error)
        assert(error ~= nil)
    end)
end)

tap.run()