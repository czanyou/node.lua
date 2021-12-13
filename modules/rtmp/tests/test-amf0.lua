local assert = require('assert')
local tap = require('util/tap')
local util = require('util')
local rtmp = require("rtmp")
local amf0 = rtmp.amf0

console.log(amf0)

print(amf0.null)

describe('test amf0', function()
    local data = {
        123,
        123.5,
        true,
        false,
        amf0.null,
        'test',
        {
            int = 123,
            float = 123.5,
            t = true,
            f = false,
            null = amf0.null,
            text = 'test'
        }
    }

    local array = amf0.encodeArray(data)
    local output = amf0.parseArray(array)

    console.log('output', output)
    assert.equal(output[5], amf0.null)
    assert.equal(output[7].null, amf0.null)
    assert.equal(output[7].text, 'test')
    assert.equal(output[7].int, 123)
    assert.equal(output[7].float, 123.5)
    assert.equal(output[7].t, true)
    assert.equal(output[7].f, false)
end)
