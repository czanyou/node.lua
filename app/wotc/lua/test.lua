local app = require('app')
local fs = require('fs')

local exports = {}
local failds = 0
local total = 0

local function assert(value, message)
    total = total + 1
    if (not value) then
        print(message)
        failds = failds + 1
    end
end

exports.start = function()
    local did = app.get('did')
    assert(did, '没有设置 did 参数')

    local base = app.get('base')
    assert(base, '没有设置 base 参数')

    local mqtt = app.get('mqtt')
    assert(mqtt, '没有设置 mqtt 参数')

    local filename = '/usr/local/lnode/conf/default.conf'
    assert(fs.existsSync(filename), '"default.conf" 文件不存在')

    filename = '/usr/local/lnode/conf/lnode.key'
    assert(fs.existsSync(filename), '"lnode.key" 文件不存在')

    print('total: ' .. total)
    print('failds: ' .. failds)
end

return exports
