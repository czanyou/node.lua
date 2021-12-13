# 断言 (Assertion Testing)

该模块提供一些简单的断言测试方法, 可用于编写单元测试用例，通过 `require('assert')` 调用。

## assert

> `assert(actual, [message])`

测试 actual 的值是不是为 true，等同于 `assert.ok()`。

- actual `{any}` 实际值
- message `{string}` 要显示的额外消息

## assert.fail

> `assert.fail(actual, expected, message, operator)`

显示一个异常，显示用例的实际值 (actual) 和期望值 (expected)，通过分隔符 (operator) 隔开。

- actual `{any}` 实际值
- expected `{any}` 期望的值
- message `{string}` 要显示的额外消息
- operator `{string}` 实际值和期望的值之间的分隔符

## assert.ifError

> `assert.ifError(value)`

如果指定的值为 `true`, 则产生一个错误

- value `{any}` 要检查的值

## assert.ok

> `assert.ok(actual, [message])`

测试 actual 的值是不是为 `true`。

- actual `{any}` 实际值
- message `{string}` 要显示的额外消息

## 相等测试

### assert.deepEqual

> `assert.deepEqual(actual, expected, [message])`

深度匹配测试。

- actual `{any}` 实际值
- expected `{any}` 期望的值
- message `{string}` 要显示的额外消息

### assert.equal

> `assert.equal(actual, expected, [message])`

浅相等测试，等同于使用 '==' 进行相等判断。

- actual `{any}` 实际值
- expected `{any}` 期望的值
- message `{string}` 要显示的额外消息

### assert.notDeepEqual

> `assert.notDeepEqual(actual, expected, [message])`

深度匹配测试。

- actual `{any}` 实际值
- expected `{any}` 期望的值
- message `{string}` 要显示的额外消息

### assert.notEqual

> `assert.notEqual(actual, expected, [message])`

浅不相等测试，等同于使用 '!=' 进行不相等判断。

- actual `{any}` 实际值
- expected `{any}` 期望的值
- message `{string}` 要显示的额外消息
  