local qs        = require('querystring')
local assert    = require('assert')
local deepEqual = assert.isDeepEqual

require('ext/tap')(function(test)
  -- Basic code coverage
  -- format: { arbitraryQS, canonicalQS, parsedQS, sep, eq }
  local tests = {
    {'foo=1&bar=2', 'foo=1&bar=2', {['foo'] = '1', ['bar'] = '2'}},
    {'%25 %20+=foo%25%00%41bar&a=%26%3db', '%25%20%20%20=foo%25%00Abar&a=%26%3Db', {['%   '] = 'foo%\000Abar', a = '&=b'}},
    {'%25 %20+=foo%25%00%41bar&a=%26%3db', '=foo%25%00Abar%26a%3D%26%3Db+%25%20%20=', {['%  '] = '', ['']='foo%\000Abar&a=&=b'}, '+'},
    {'f', 'f=', {f=''}},
    {'f>u+u>f', 'f>u+u>f', {u='f', f='u'}, '+', '>'},
  }

  test('escape', function(expect)
      local ret = qs.escape("test我的")
      --console.log(ret)
      assert.equal(ret, "test%E6%88%91%E7%9A%84")
  end) 

  test('parse', function(expect)
    for num, test in ipairs(tests) do
      local input = test[1]
      local output = test[3]
      local tokens = qs.parse(input, test[4], test[5])
      deepEqual(output, tokens)
    end
  end)

  test('stringify', function(expect)
    for num, test in ipairs(tests) do
      local input  = test[3]
      local output = test[2]
      local str = qs.stringify(input, test[4], test[5])
      deepEqual(qs.parse(output, test[4]), qs.parse(str, test[4]))
    end
  end)

  test('unescape', function(expect)
      local ret = qs.unescape("test+%30%E6%88%91%E7%9A%84")
      --console.log(ret)
      assert.equal(ret, "test 0我的")
  end) 
end)
