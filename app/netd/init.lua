local app 		= require('app')
local utils     = require('utils')
local env       = require('env')
local fs        = require('fs')
local conf      = require('ext/conf')
local lpm       = require('ext/lpm')
local netd      = require('netd')

local profile   = nil
local confile   = nil
local confmtime = 0

local color = console.color

function get_network_settings()
    local profile = get_settings_profile()
    
    local settings = {}
    settings.mode       = profile:get('lan.mode') or 'dhcp'
    settings.interface  = profile:get('lan.interface') 
    settings.ip         = profile:get('lan.ip') 
    settings.netmask    = profile:get('lan.netmask') 
    settings.gateway    = profile:get('lan.gateway') 
    settings.dns        = profile:get('lan.dns') 

    return settings
end

-- 配置信息都保存在 user.conf 文件中
function get_settings_profile()
    if (not profile) then
        profile = conf('network')
        confile = profile.filename
    end

    return profile
end


local function update_network_settings()
    local settings = get_network_settings()
    local mode = settings.mode or 'dhcp'
    --print('mode: ' .. mode)

    if (mode == 'static') then
        netd.start_static_mode(settings)

    else
        netd.start_dhcp_mode(settings)
    end
end

local function _watch_timer()
    if (not confile) then
        profile = get_settings_profile()
        if (not confile) then
            print("invalid confile")
            return
        end
    end
    
    --print('confile', confile)

    fs.stat(confile, function(err, statInfo)
        local mtime = -1
        if (statInfo) then
            mtime = statInfo.mtime.sec
        end
        
        if (mtime == confmtime) then
            return
        end
        
        print(color('success') .. "Applying network settings...", color())
        confmtime = mtime
        profile = nil
        update_network_settings()
    end)
end

local INTERVAL = 2000

local exports = {}

function exports.help()
    app.usage(utils.dirname())

    print([[
available command:

- start     Start network manager
- settings  Show network manager
- update    Update network settings


]])
end

function exports.settings()
    local ret = get_network_settings() or {}
    ret.dns = (ret.dns or ''):split(' ')
    console.log(ret)
end

function exports.status()


end

function exports.update()
    _watch_timer()
end

function exports.apply()
    _watch_timer()
end

function exports.start()
    local timer = setInterval(INTERVAL, _watch_timer)
    _watch_timer()
end

app(exports)

