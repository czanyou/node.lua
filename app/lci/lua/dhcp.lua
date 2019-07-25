#!/usr/bin/env lnode

local conf  = require('app/conf')

local function onDhcpBound()
    local function saveConfig(data)  
        conf.load("network", function(ret, profile)
            profile:set("dhcp", data)
            profile:set("updated", Date.now())
            profile:commit()
        end)
    end

    local config = {}
    config.ip = os.getenv("ip")
    config.router = os.getenv("router")
    config.netmask = os.getenv("subnet")
    config.broadcast = os.getenv("broadcast")

    config.interface  = os.getenv("interface")
    config.dns = os.getenv("dns")
    config.domain = os.getenv("domain")
    config.ntpsrv = os.getenv("ntpsrv")
    
    if (config.ip) then
        saveConfig(config)
    end
end

onDhcpBound()
