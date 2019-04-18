local util = require("util")
local rtmp = require("rtmp")
local amf0 = rtmp.amf0

console.log(amf0)

print(amf0.null)

function test_parse()
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

    console.log(data, output)
    console.log(output[5] == amf0.null)
    console.log(output[7].null == amf0.null)
    console.log(output[7].text == 'test')
    console.log(output[7].int == 123)
    console.log(output[7].float == 123.5)
    console.log(output[7].t == true)
    console.log(output[7].f == false)
end

test_parse()

