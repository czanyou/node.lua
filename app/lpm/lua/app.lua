local app       = require('app')
local path      = require('path')
local fs        = require('fs')
local lpm       = require('lpm')

-------------------------------------------------------------------------------
-- exports

local exports = lpm

-- 返回所有需要后台运行的应用
local function getApplicationNames()
    local configPath = path.join(app.nodePath, 'conf/process.conf')
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
    local names = getApplicationNames()
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

-- 启动应用进程守护程序
function exports.run(interval, ...)
    print("Start lpm...")

    -- Check lock
    local lockfd = app.lock('lpm')
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
