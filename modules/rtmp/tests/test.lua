local url = require('url')

local null = {}

console.log(null)
console.log(null == null)
console.log(null == nil)
console.log(null == {})

local urlString = 'rtmp://iot.wotcloud.cn:1935/live/test?v=1234'

local result = url.parse(urlString, true, true)
console.log(result)

local pathname = result.pathname or ''
local tokens = pathname:split('/')
console.log(tokens)
