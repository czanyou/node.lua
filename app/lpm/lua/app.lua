local app       = require('app')
local path      = require('path')
local fs        = require('fs')
local lpm       = require('lpm')
local exec      = require('child_process').exec

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
        if (not item or #item <= 0) then
            goto continue
        end

        local filename = path.join(exports.rootPath, 'app', item)
        if not fs.existsSync(filename) then
            filename = path.join(exports.rootPath, 'app', item .. '.zip')
            if not fs.existsSync(filename) then
                goto continue
            end
        end

        names[item] = item
        count = count + 1
        ::continue::
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

    -- console.log(names, procs)
    for _, proc in ipairs(procs) do
        names[proc.name] = nil
    end

    for name, pid in pairs(names) do
        local cmd = "lpm start " .. name
        --local ret, err = os.execute(cmd)
        --console.log('start:', cmd, ret, err)

        local options = { timeout = 30 * 1000, env = process.env }
        exec(cmd, options, function(err, stdout, stderr)
            print(stderr or (err and err.message) or stdout)
        end)
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
