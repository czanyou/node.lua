local utils     = require('utils')
local path      = require('path')
local conf      = require('ext/conf')
local json      = require('json')
local fs        = require('fs')
local thread    = require('thread')
local path      = require('path')
local json      = require('json')
local lutils    = require('lutils')
local fs        = require('fs')
local rpc       = require('ext/rpc')

local querystring = require('querystring')

local RPC_PORT  = 38888
local RPC_STORE = 8889

-- 在提交的表单中，附带一个 action=edit 的参数表示保存参数。
local function is_edit_action(request)
    local params = request.params
    local action = params['action']
    return (action == 'edit')
end

-- 从配置文件中读取需要的表单参数集
-- - cateogry {String} 参数分类, 如 'network'
-- - keys {Array} 参数名称列表, 如 {'eth_ipaddr', 'eth_gateway', ... }
-- 返回包含这些参数的名称和值的 `table`.
local function on_load_params(profile, cateogry, keys)
    local settings = { cateogry = cateogry }

    for _, key in pairs(keys) do
        settings[cateogry .. "_" .. key] = profile:get(cateogry .. "." .. key)
    end

    return settings
end

-- 保存表单参数集到配置文件中
-- - cateogry {String} 参数分类, 如 'network'
-- - keys {Array} 参数名称列表, 如 {'eth_ipaddr', 'eth_gateway', ... }
local function on_save_params(profile, cateogry, keys, params)
    local oldValue = profile:toString()

    for _, key in pairs(keys) do
        local value = params[cateogry .. "_" .. key]
        if (value) then
            profile:set(cateogry .. "." .. key, value)
        end
    end
    
    local newValue = profile:toString()
    if (oldValue ~= newValue) then
        profile:commit()
    end
end

-- 配置信息都保存在 user.conf 文件中
local function get_settings_profile()
    local profile = nil
    if (not profile) then
        profile = conf('beacon')
    end

    return profile
end


local function on_settings(request, response)
    local category = 'reader'
    local keys = { 'server', 'id', 'key', 
        'stat_timeout', 'stat_max_count', 'stat_max_time', 'stat_factor' }

    local profile = get_settings_profile()
    local params = request.params
    if is_edit_action(request) then 
        on_save_params(profile, category, keys, params)
    end

    local settings = on_load_params(profile, category, keys)
    response:json(settings)
end

local function on_list(request, response)
    local method    = 'getBeacons'
    local params    = {}

    rpc.call(RPC_PORT, method, params, function(err, result)
        response:json(result)
    end)
end

local function do_api(request, response, onEnd)
    local api = request.api
    if (api == '/list') then
        on_list(request, response)

    elseif (api == '/settings') then
        on_settings(request, response)

    else
        response:sendStatus(400, "No `api` parameters specified!")
    end
end

request.params  = querystring.parse(request.uri.query) or {}
request.api     = request.params['api']
do_api(request, response)

return true
