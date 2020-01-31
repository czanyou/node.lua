# 单元测试模块

一个简单的单元测试模块.

通过 `require('ext/tap')` 调用。

## tap

> tap(callback)

添加测试用例

- `callback` {function(test: function(name:string, callback))}
  - `callback` {function(expect, uv)}

## 示例

```lua

local test = tap.test

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

local passed, failed, total = tap.run()

```

## tap.test

> tap.test(name, func)

- `name` {string} 测试用例名称
- `func` {function(expect:function)} 测试用例

添加测试用例

## tap.run

> tap.run(runAll)

运行测试

- `runAll` {boolean} 是否立即执行所有测试用例

## tap.suite

> tap.suite(name)

- `name` {string} 测试套件名称

添加测试套件
