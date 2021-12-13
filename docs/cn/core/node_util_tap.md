# 单元测试模块

一个简单的单元测试模块.

通过 `require('util/tap')` 调用。

## describe

> describe(name, func)

添加测试用例

- name `{string}` 测试名称
- func `{function(expect, uv)}`

## 示例

```lua

local tap = require('util/tap')

describe("add 1 to 2", function(expect)
    print("Adding 1 to 2")
    assert(1 + 2 == 3)
end)

describe("close handle", function (expect, uv)
    local handle = uv.new_timer()
    uv.close(handle, expect(function (self)
      assert(self == handle)
    end))
end)

describe("simulate failure", function ()
    error("Oopsie!")
end)

```

## tap.test

> tap.test(name, func)

同 describe

- name `{string}` 测试用例名称
- func `{function(expect:function)}` 测试用例

添加测试用例

## tap.testAll

> tap.testAll(dirname)

运行测试套件

- dirname `{string}` 测试套件目录

## tap.error

> tap.error(error)

- error `{string}` 测试错误

指定测试错误
