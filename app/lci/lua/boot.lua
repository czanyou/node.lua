local fs = require('fs')
local app = require('app')
local util = require('util')
local lnode = require('lnode')
local devices = require('devices')

local context = {}
local exports = {}

-- 检查指定的链接文件
---@param srcname string 链接文件名
---@param destname string 目标目录名
function exports.checkPathLink(srcname, destname)
    fs.mkdirpSync(destname)

    local result = fs.readlinkSync(srcname)
    if (result == destname) then
        return
    end

    local cmdline = 'rm -rf ' .. srcname
    local ret, type, code = os.execute(cmdline)
    if (not ret) then
        -- console.log(cmdline, ret, type, code)
    end

    cmdline = 'ln -s ' .. destname .. ' ' .. srcname
    ret, type, code = os.execute(cmdline)
    if (not ret) then
        -- console.log(cmdline, ret, type, code)
    end

    print("create link: " .. cmdline, type, code)
end

-- 创建所需的 /var/xxx 目录
function exports.initVarSubpaths()
    exports.checkPathLink('/var/lock', '/tmp/lock/') -- 文件锁
    exports.checkPathLink('/var/log', '/tmp/log/') -- 日志文件
    exports.checkPathLink('/var/run', '/tmp/run/') -- 运行时临时文件
    exports.checkPathLink('/var/sock', '/tmp/sock/') -- IPC 文件
end

-- 初始化 Node.lua 所需要的 init 脚本和配置文件
function exports.installInitFiles()
    exports.saveInitFile('data/S87hidev', '/etc/init.d/S87hidev')
    exports.saveInitFile('data/S88lnode', '/etc/init.d/S88lnode')
    exports.saveInitFile('data/localtime', '/etc/localtime')
end

-- 初始化 pppd 所需的脚本和配置文件
function exports.installPppFiles()
    fs.mkdirpSync('/tmp/ppp')
    fs.mkdirpSync('/tmp/ppp/peers')
    fs.mkdirpSync('/tmp/ppp/data')
    exports.checkPathLink('/etc/ppp', '/tmp/ppp/')

    -- 安装 pppd 所需要的脚本和配置文件
    exports.saveBundleFile('data/ppp/peers/quectel-chat-connect', '/tmp/ppp/peers/quectel-chat-connect')
    exports.saveBundleFile('data/ppp/peers/quectel-chat-disconnect', '/tmp/ppp/peers/quectel-chat-disconnect')
    exports.saveBundleFile('data/ppp/peers/quectel-ppp', '/tmp/ppp/peers/quectel-ppp')
    exports.saveBundleFile('data/ppp/peers/quectel-ppp-kill', '/tmp/ppp/peers/quectel-ppp-kill', 511)
    exports.saveBundleFile('data/ppp/peers/quectel-pppd.sh', '/tmp/ppp/peers/quectel-pppd.sh', 511)
    exports.saveBundleFile('data/ppp/data/chat-test', '/tmp/ppp/data/chat-test')
    exports.saveBundleFile('data/ppp/data/quectel-chat-status', '/tmp/ppp/data/quectel-chat-status')
    exports.saveBundleFile('data/ppp/ip-up', '/tmp/ppp/ip-up', 511)

    fs.chmodSync('/tmp/ppp/ip-up', 511) -- 777
end

-- 从 lci.zip Zip 包中读取指定名称的文件的内容
---@param name string - Bundle file name path/to/file
---@return string - file data
---@return string - error
function exports.readBundleFile(name)
    if (not name) then
        return nil, 'Bad bundle file name'
    end

    local dirname = util.dirname()
    if (dirname and dirname:startsWith('$app/')) then
        local reader = package.apps and package.apps.lci
        if (reader) then
            return reader:readFile(name)
        end
    end

    local rootPath = app.rootPath
    local filename = rootPath .. '/app/lci/' .. name

    -- check source
    local stat, err = fs.statSync(filename)
    if (err) then
        return nil, err
    end

    local fileSize = stat and stat.size

    local fileData
    fileData, err = fs.readFileSync(filename)
    if err or (not fileData) or (#fileData ~= fileSize) then
        return nil, err
    end

    return fileData
end

-- 读取并保存 zip 包中的文件到文件系统中
---@param name string lci.zip 中文件的名称
---@param destname string 要保存的路径
---@param mode string
function exports.saveBundleFile(name, destname, mode)
    local fileData, err
    fileData, err = exports.readBundleFile(name)
    if (err) then
        return print(err)

    elseif (not fileData) then
        return print('File data is empty: ' .. name)
    end

    _, err = fs.writeFileSync(destname, fileData)
    if (err) then
        return print(err)
    end

    if (mode) then
        fs.chmodSync(destname, mode)
    end

    return true
end

function exports.saveInitFile(srcname, destname)
    -- check source
    local fileData, err = exports.readBundleFile(srcname)
    if err or (not fileData) then
        print("saveInitFile: Bad source file", err)
        return
    end

    -- console.log('Source file size: ' .. #fileData)

    local position = string.find(fileData, '\r\n')
    if (position ~= nil) then
        print("saveInitFile: Bad source file line end", position)
        return
    end

    -- check dest
    local destData = fs.readFileSync(destname)
    if (destData == fileData) then
        -- print("saveInitFile: Same dest file!", destname)
        return
    end

    -- write
    _, err = fs.writeFileSync(destname .. '~', fileData)
    if (err) then
        return print("saveInitFile: write error: " .. tostring(err))
    end

    destData, err = fs.readFileSync(destname .. '~')
    if err or (destData ~= fileData) then
        if (err) then
            return print("saveInitFile: check error: " .. tostring(err))
        end
        return
    end

    -- switch
    fs.chmodSync(destname .. '~', 511) -- 777
    os.remove(destname)
    os.rename(destname .. '~', destname)
    fs.chmodSync(destname, 511) -- 777

    print('saveInitFile: ' .. destname)
end

-- --------------------
-- exports

function exports.start()
    devices.init()

    local borad = lnode.board
    print('borad', borad)

    exports.initVarSubpaths(borad)
    if (borad == 'dt02') or (borad == 'dt02b') then
        exports.installInitFiles(borad)
        exports.installPppFiles(borad)

    elseif (borad == 't31a') then
        os.execute('lpm start lci wotc lpm > /tmp/log/lpm.log')
    end
end

function exports.update(type)
    if (not type) then
        print('Usage: lci boot <board name>')
        return
    end

    print('type: ' .. tostring(type))
    local ret = exports.saveBundleFile('data/' .. type .. '.conf', '/usr/local/lnode/conf/device.conf')
    if (ret) then
        exports.installInitFiles()
    end
end

return exports
