# 断言 (Assertion Testing)

[TOC]

该模块提供一些简单的断言测试方法可用于编写单元测试用例，通过 `require('assert')` 调用。

## assert

    assert(actual, [message])

测试 actual 的值是不是为 true，等同于 `assert.ok()`。

## assert.deepEqual

    assert.deepEqual(actual, expected, [message])

深度匹配测试。

## assert.equal

    assert.equal(actual, expected, [message])

浅测试，等同于使用 '==' 进行相等判断。

## assert.fail

    assert.fail(actual, expected, message, operator)

显示一个异常，显示用例的实际值 (actual) 和期望值 (expected)，通过分隔符 (operator) 隔开。

- actual {Any} 实际值
- expected {Any} 期望的值
- message {String} 要显示的额外消息
- operator {String} 实际值和期望的值之间的分隔符

## assert.ifError

    assert.ifError(value)

如果指定的值为 true, 则产生一个错误

- value {Any} 要检查的值


## assert.notDeepEqual

    assert.notDeepEqual(actual, expected, [message])

深度匹配测试。

## assert.notEqual

    assert.notEqual(actual, expected, [message])

浅测试，等同于使用 '!=' 进行不相等判断。

## assert.ok

    assert.ok(actual, [message])

测试 actual 的值是不是为 true。
