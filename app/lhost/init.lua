local app       = require('app')
local utils     = require('util')
local path      = require('path')
local fs        = require('fs')
local rpc       = require('app/rpc')

-------------------------------------------------------------------------------
-- exports

local exports = {}

app.name = 'lhost'

-- 检查应用进程，自动重启意外退出的应用程序
function exports.check()
    local names = app.getStartNames()
    local procs = app.processes()

    for _, proc in ipairs(procs) do
        names[proc.name] = nil
    end

    for name, pid in pairs(names) do
        console.log('start:', name)
        os.execute("lpm start " .. name)
    end
end

-- 检查应用rpc是否还有反应(暂时只有gateway程序)
function exports.rpc()
    local RPC_PORT = 38888
    local method = 'alive'
    local params    = {}
    rpc.call(RPC_PORT, method, params, function(err, result)
        if (result) then
            -- console.log(result)
        else
            print('App gateway is down,restart now')
            os.execute('lpm restart gateway')
        end
    end)
end

-- 不允许指定名称的应用在后台一直运行
function exports.disable(...)
    local names = table.pack(...)
    if (#names < 1) then
        exports.help()
        return
    end

    app.enable(names, false)
end

-- 允许指定名称的应用在后台一直运行
function exports.enable(...)
    local names = table.pack(...)
    if (#names < 1) then
        exports.help()
        return
    end

    app.enable(names, true)
end

function exports.help()
    print([[
        
usage: lpm lhost <command> [args]

Node.lua application daemon manager
    
Available command:

- check              Check all application daemon status
- disable [name...]  Disable application daemon
- enable [name...]   Enable application daemon
- help               Display help information
- start [interval]   Start lhost
- status             Show status

]])
end

-- 启动应用进程守护程序
function exports.start(interval, ...)
    print("Start lhost...")

    -- Check lock
    local lockfd = app.tryLock('lhost')
    if (not lockfd) then
        print('The lhost is locked!')
        return
    end

    -- Check start list
    local list = app.get('start')
    if (list) then
        list = list:split(',')
        console.log('start', list)
        app.enable(list, true)
    end

    -- Start check timer
    interval = tonumber(interval) or 3
    setInterval(interval * 1000, function()
        exports.check()
        exports.rpc()
    end)
end

app(exports)
