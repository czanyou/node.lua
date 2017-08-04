local utils  = require('utils')
local assert = require('assert')
local Object = require('core').Object

require('ext/tap')(function(test)

  test('test utils.dirname', function(expect)
    local ret = utils.dirname()
    --assert.equal(ret, 'ABCDEF012345')
    print('utils.dirname', ret)
  end)

  test('test utils.filename', function(expect)
    local path = require('path')
    local ret = utils.filename()
    assert.equal(path.basename(ret), 'test-utils.lua')
    print('utils.filename', ret)

    print('utils.filename', utils.filename(0))
    print('utils.filename', utils.filename(1))
    print('utils.filename', utils.filename(2))
    print('utils.filename', utils.filename(4))
    print('utils.filename', utils.filename(5))
    print('utils.filename', utils.filename(6))
    print('utils.filename', utils.filename(7))

  end)  

  test('test utils.base64Encode', function(expect)
    local ret = utils.base64Encode('ABCDEF012345')
    assert.equal(ret, 'QUJDREVGMDEyMzQ1')
  end)

  test('test utils.base64Decode', function(expect)
    local ret = utils.base64Decode('QUJDREVGMDEyMzQ1')
    assert.equal(ret, 'ABCDEF012345')
  end)

  test('test utils.bin2hex', function(expect)
    local ret = utils.bin2hex('\0\2\10\16\32ABC123')
    assert.equal(ret, '00020a1020414243313233')
  end)

  test('test utils.hex2bin', function(expect)
    local ret = utils.hex2bin('00020a1020414243313233')
    assert.equal(ret, '\0\2\10\16\32ABC123')
  end)

  test('test utils.md5', function(expect)
    local ret = utils.md5('test.com')
    assert.equal(utils.bin2hex(ret), 'c97c1b3671fef2055e175ca2154d217a')
  end)  

  test('utils.bind', function(expect)

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
    test(100, utils.bind(object.test, object, 'a'))   


  end)

  test('utils.bind', function(expect)

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
    bound('hello world', function(arg1)
      assert(arg1 == 'hello world')
    end)
    bound('hello world1', function(arg1)
      assert(arg1 == 'hello world1')
    end)

    bound = utils.bind(BindHelper.func1, testObj, 'hello world')
    bound(function(arg1)
      assert(arg1 == 'hello world')
    end)
    bound(function(arg1)
      assert(arg1 == 'hello world')
    end)
    bound(function(arg1)
      assert(arg1 == 'hello world')
    end)

    bound = utils.bind(BindHelper.func2, testObj)
    bound('hello', 'world', function(arg1, arg2)
      assert(arg1 == 'hello')
      assert(arg2 == 'world')
    end)
    bound('hello', 'world', function(arg1, arg2)
      assert(arg1 == 'hello')
      assert(arg2 == 'world')
    end)

    bound = utils.bind(BindHelper.func2, testObj, 'hello')
    bound('world', function(arg1, arg2)
      assert(arg1 == 'hello')
      assert(arg2 == 'world')
    end)

    bound = utils.bind(BindHelper.func3, testObj)
    bound('hello', 'world', '!', function(arg1, arg2, arg3)
      assert(arg1 == 'hello')
      assert(arg2 == 'world')
      assert(arg3 == '!')
    end)

    bound = utils.bind(BindHelper.func3, testObj)
    bound('hello', nil, '!', function(arg1, arg2, arg3)
      assert(arg1 == 'hello')
      assert(arg2 == nil)
      assert(arg3 == '!')
    end)

    bound = utils.bind(BindHelper.func3, testObj, 'hello', 'world')
    bound('!', function(arg1, arg2, arg3)
      assert(arg1 == 'hello')
      assert(arg2 == 'world')
      assert(arg3 == '!')
    end)

    bound = utils.bind(BindHelper.func3, testObj, 'hello', nil)
    bound('!', function(arg1, arg2, arg3)
      assert(arg1 == 'hello')
      assert(arg2 == nil)
      assert(arg3 == '!')
    end)

    bound = utils.bind(BindHelper.func3, testObj, nil, 'world')
    bound('!', function(arg1, arg2, arg3)
      assert(arg1 == nil)
      assert(arg2 == 'world')
      assert(arg3 == '!')
    end)

    local tblA = { 1, 2, 3 }
    local tblB = { tblA, 'test1', 'test2', { tblA } }
    local s = console.dump(tblB, true, true)
    --assert(s == "{ { 1, 2, 3 }, 'test1', 'test2', { { 1, 2, 3 } } }")

    local Error = require('core').Error
    local MyError = Error:extend()
    assert(pcall(console.dump, MyError))
  end)
end)
