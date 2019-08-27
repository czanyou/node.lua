local app = require('app')
local fs = require('fs')

local exports = {}
local failures = 0
local total = 0

exports.start = function()
    local errors = {}

    local function assert(value, message)
        total = total + 1
        if (not value) then
            failures = failures + 1
            table.insert(errors, message)
        end
    end

    local function checkConfig(name)
        local value = app.get(name)
        if (value) then
            total = total + 1
            print(name .. ': ' .. value)
        else 
            failures = failures + 1
            table.insert(errors, '系统设置参数 ' .. name .. ' 为空')
        end
    end

    local function checkFile(basePath, name)
        local filename = basePath .. name

        print("");
        print('Check: ' .. filename .. '\n------')
        if (fs.existsSync(filename)) then
            total = total + 1
            local data = fs.readFileSync(filename)
            print(data)

        else
            failures = failures + 1
            table.insert(errors, '`' .. name .. '` 文件不存在')
        end
    end

    print("Check config: \n======")
    checkConfig('did')
    checkConfig('base')
    checkConfig('mqtt')
    checkConfig('secret')
    print("");

    print("Check files: \n======")
    checkFile('/usr/local/lnode/conf/', 'default.conf');
    checkFile('/usr/local/lnode/conf/', 'lnode.key');
    checkFile('/etc/init.d/', 'S88lnode');
    checkFile('/usr/share/udhcpc/', 'default.script');
    print("");

    print('total: ' .. total)
    print('failds: ' .. failures)

    console.printr(errors)
end

return exports
