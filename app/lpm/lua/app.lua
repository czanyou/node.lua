local app       = require('app/init')
local utils     = require('util')
local path      = require('path')
local fs        = require('fs')
local rpc       = require('app/rpc')

-------------------------------------------------------------------------------
-- exports

local exports = {}

app.name = 'apm'

-- 返回所有需要后台运行的应用
function exports.getStartNames()
    local configPath = path.join(app.rootPath, 'conf/process.conf')
    local filedata = fs.readFileSync(configPath)
    local names = {}
    local count = 0

    if (not filedata) then
        return names, count, filedata
    end

    -- check application name
    local list = filedata:split(",")
    for _, item in ipairs(list) do
        if (#item > 0) then
            local filename = path.join(exports.rootPath, 'app', item)
            if fs.existsSync(filename) then
                names[item] = item
                count = count + 1
            end
        end
    end
    
    return names, count, filedata
end

-- 检查应用进程，自动重启意外退出的应用程序
function exports.check()
    local names = exports.getStartNames()
    local procs = app.processes()
    if (not procs) then
        return
    end

    for _, proc in ipairs(procs) do
        names[proc.name] = nil
    end

    for name, pid in pairs(names) do
        console.log('start:', name)
        os.execute("lpm start " .. name)
    end
end

function exports.list()
    local names = exports.getStartNames()
    console.log(names)

    local processes = app.processes()
    console.log(processes)    
end

function exports.help()
    print([[
        
usage: apm <command> [args]

Node.lua application daemon manager
    
Available command:

- check              Check all application daemon status
- help               Display help information
- start [interval]   Start apm

]])
end

-- 启动应用进程守护程序
function exports.start(interval, ...)
    print("Start apm...")

    -- Check lock
    local lockfd = app.tryLock('apm')
    if (not lockfd) then
        print('The apm is locked!')
        return
    end

    -- Start check timer
    interval = tonumber(interval) or 3
    setInterval(interval * 1000, function()
        exports.check()
    end)
end

app(exports)
