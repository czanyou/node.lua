local fs     = require("fs")
local conf   = require('ext/conf')
local json   = require('json')
local lpm    = require('ext/lpm')
local path   = require('path')
local utils  = require('utils')
local thread = require('thread')
local httpd  = require('httpd')

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

    for basename, key in pairs(keys) do
        if (type(key) == 'table') then
            for _, subkey in pairs(key) do
                local index = cateogry .. "." .. basename .. "." .. subkey
                local name  = cateogry .. "_" .. basename .. "_" .. subkey
                settings[name] = profile:get(index)
            end

        else
            settings[cateogry .. "_" .. key] = profile:get(cateogry .. "." .. key)
        end
    end

    return settings
end

-- 保存表单参数集到配置文件中
-- - cateogry {String} 参数分类, 如 'network'
-- - keys {Array} 参数名称列表, 如 {'eth_ipaddr', 'eth_gateway', ... }
local function on_save_params(profile, cateogry, keys, params)
    local oldValue = profile:toString()

    for basename, key in pairs(keys) do
        if (type(key) == 'table') then
            for _, subkey in pairs(key) do
                local index = cateogry .. "." .. basename .. "." .. subkey
                local name  = cateogry .. "_" .. basename .. "_" .. subkey
                local value = params[name]
                if (value) then
                    profile:set(index, value)
                end
            end
        else
            local value = params[cateogry .. "_" .. key]
            if (value) then
                profile:set(cateogry .. "." .. key, value)
            end
        end
    end
    
    local newValue = profile:toString()
    if (oldValue ~= newValue) then
        profile:commit()
    end
end

local function on_settings_snapshot(request, response)
    local function main()
        local rpc       = require('ext/rpc')
        local method    = 'snapshot'
        local params    = { 'test' }

        local IPC_PORT = 53212
        rpc.call(IPC_PORT, method, params, function(err, result)
            local filedata = fs.readFileSync('/tmp/snapshot.jpg') or 'test'
            response:send(filedata, "image/jpeg")
        end)
    end

    local ret, err = pcall(main)
    if (not ret) then
        response:send(err, "text/html")
    end
end

local function on_settings_camera(request, response)
    local category = 'video'
    local keys = { 
        ['1'] = {'bitrate', 'frame_rate', 'width', 'height', 'bitrate_mode'}, 
        ['2'] = {'bitrate', 'frame_rate', 'width', 'height'}, 
        ['3'] = {'bitrate', 'frame_rate', 'width', 'height'}, 
        'text', 'overlay' }

    local profile = conf('camera')
    if is_edit_action(request) then
        local params = request.params
        on_save_params(profile, category, keys, params)
    end

    local settings = on_load_params(profile, category, keys)
    response:json(settings)
end

-- API methods
local methods = {}
methods['/settings/camera']  = on_settings_camera
methods['/snapshot']         = on_settings_snapshot

httpd.call(methods, request, response)

return true