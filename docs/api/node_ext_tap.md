# 单元测试模块

[TOC]

一个简单的单元测试模块.

通过 `require('ext/tap')` 调用。

## tap(callback)

添加测试用例

- callback {Function} - function(test)
  - test {Function} - function("title", callback)
    - callback {Function} - function(print, p, expect, uv)

## 示例

```lua

local passed, failed, total = tap(function (test)

  test("add 1 to 2", function(print)
    print("Adding 1 to 2")
    assert(1 + 2 == 3)
  end)

  test("close handle", function (print, p, expect, uv)
    local handle = uv.new_timer()
    uv.close(handle, expect(function (self)
      assert(self == handle)
    end))
  end)

  test("simulate failure", function ()
    error("Oopsie!")
  end)

end)

```

