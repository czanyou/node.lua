local fs = require('fs')
local app = require('app')
local devices = require('devices')

local exports = {}

exports.onSystemBoot = function (type, ...)
    local function checkPathLink(name1, name2)
        local result = fs.readlinkSync(name1)
        if (result ~= name2) then
            local cmdline = 'rm -rf ' .. name1
            console.log(cmdline)
            os.execute(cmdline)
    
            cmdline = 'ln -s ' .. name2 .. ' ' .. name1
            console.log(cmdline)
            os.execute(cmdline)

            fs.mkdirpSync(name2)
        end
    end

    local function installInitFiles()
        local rootPath = app.rootPath
        local filename = rootPath .. '/app/lci/data/S88lnode'
        local stat = fs.statSync(filename)
        local size = stat and stat.size
        console.log(size)

        local fileData = fs.readFileSync(filename)
        if (not fileData) or (#fileData ~= size) then
            return
        end

        local position = string.find(fileData, '\r\n')
        if (position ~= nil) then
            return
        end

        local destname = '/etc/init.d/S88lnode'
        local destData = fs.readFileSync(destname)
        if (not destData) then
            return
        end

        if (destData == fileData) then
            return
        end

        fs.writeFileSync(destname .. '~', fileData)
        destData = fs.readFileSync(destname .. '~')
        if (destData ~= fileData) then
            return
        end

        os.remove(destname)
        os.rename(destname .. '~', destname)
        os.execute('chmod 777 ' .. destname)
        console.log('fileData', fileData, position)
    end

    local function executeInitScript()
        local rootPath = app.rootPath
        local filename = rootPath .. '/app/lci/bin/init.sh'
        os.execute('sh ' .. filename)
    end

    checkPathLink('/etc/ppp', '/tmp/ppp/')
    checkPathLink('/var/sock', '/tmp/sock/')
    checkPathLink('/var/lock', '/tmp/lock/')
    checkPathLink('/var/log', '/tmp/log/')
    checkPathLink('/var/run', '/tmp/run/')

    devices.init()
    installInitFiles()
    executeInitScript()
end

return exports
