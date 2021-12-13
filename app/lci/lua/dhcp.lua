local path  = require('path')
local fs    = require('fs')
local json  = require('json')

-- 当 DHCP 客户端获取到新的 IP 地址时调用这个方法
-- - 这个方法由 /usr/share/udhcpc/default.script 中调用
-- - 这个方法将获取到新地址等保存到 network.conf 配置文件中
-- TODO: 改为保存到临时目录

local function start()
    local function saveConfig(data)
        local filename = path.join(os.tmpdir, 'run/dhcp.json')
        local filedata = json.stringify(data)
        fs.writeFile(filename, filedata)
    end

    local config = {}
    config.ip = os.getenv("ip")
    config.router = os.getenv("router")
    config.netmask = os.getenv("subnet")
    config.broadcast = os.getenv("broadcast")

    config.ifname  = os.getenv("interface")
    config.dns = os.getenv("dns")
    config.domain = os.getenv("domain")
    config.ntpsrv = os.getenv("ntpsrv")
    config.updated = Date.now()

    if (config.ip) then
        saveConfig(config)
    else
        print('dhcp: invalid ip params')
    end
end

local function stop()

end

start()
