#!/usr/bin/env lnode

local config  = require('app/conf')

local exports = {}

local function onDhcpBound()
    local profile 
    local function saveConfig(data)  
        config.load("network", function(ret, profile)
            profile:set("dhcp", data)
            profile:set("update", "true")
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
    
    saveConfig(config)
end

onDhcpBound()
