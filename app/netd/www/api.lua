local conf   = require('ext/conf')
local json   = require('json')
local lpm    = require('ext/lpm')
local path   = require('path')
local utils  = require('utils')
local thread = require('thread')
local httpd  = require('httpd')

function get_network_interfaces(mode)
	local addresses = {}
	local interfaces = os.networkInterfaces()
	if (not interfaces) then
		return 
	end

	local _getIPv4Number = function(ip)
		local tokens = ip:split('.')
		local ret = (tokens[1] << 24) + (tokens[2] << 16) + (tokens[3] << 8) + (tokens[4])
		return math.floor(ret)
	end

	local family = mode or 'inet'

	for name, interface in pairs(interfaces) do
		if (type(interface) ~= 'table') then
			break
		end

		for _, item in pairs(interface) do
			if (not item) then
				break
			end

			if (item.family == family and not item.internal) then
                item.mac = utils.bin2hex(item.mac)
                item.name = name
				table.insert(addresses, item)
			end
		end
	end

	return addresses
end

-- 配置信息都保存在 user.conf 文件中
local function get_settings_profile()
    local profile = nil
    if (not profile) then
        profile = conf('network')
    end

    return profile
end

-- 在提交的表单中，附带一个 action=edit 的参数表示保存参数。
local function is_edit_action(request)
    local params = request.params
    local action = params['action']
    return (action == 'edit')
end

-- 从配置文件中读取需要的表单参数集
-- - cateogry {String} 参数分类, 如 'network'
-- - keys {Array} 参数名称列表, 如 {'lan_ipaddr', 'lan_gateway', ... }
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
-- - keys {Array} 参数名称列表, 如 {'lan_ipaddr', 'lan_gateway', ... }
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

local function on_device_status(request, response)
    local lpm = conf('lpm')

    local device = {}
    local status = { device = device }
    --status.lpm  = lpm.options
    --status.sscp = sscp.options
    status.interfaces = get_network_interfaces()

    if (lpm) then
        device.device_name      = lpm:get('device.id')
        device.device_model     = lpm:get('device.model')
        device.device_version   = lpm:get('device.version')
        device.device_time      = os.date('%Y-%m-%dT%H:%M:%S')
    end

    response:json(status)   
end

local function on_settings_common(request, response, category, keys)
    local profile = get_settings_profile()       
    if is_edit_action(request) then
        on_save_params(profile, category, keys, request.params)
    end

    local settings = on_load_params(profile, category, keys)
    response:json(settings)
end

local function on_settings_network(request, response)
    local category = 'lan'
    local keys = { 'name', 'dns', 'gateway', 'ip', 'mode', 'netmask' }

    local profile = get_settings_profile()
    if is_edit_action(request) then
        local params = request.params
        local list = {}
        if (params.lan_dns1) then
            list[#list + 1] = params.lan_dns1
        end
        if (params.lan_dns2) then
            list[#list + 1] = params.lan_dns2
        end
        params.lan_dns = table.concat(list, ' ')

        on_save_params(profile, category, keys, params)
    end

    local settings = on_load_params(profile, category, keys)
    if (settings.lan_dns) then
        local tokens = settings.lan_dns:split(' ')
        settings.lan_dns1 = tokens[1] or ''
        settings.lan_dns2 = tokens[2] or ''
    end

    local interfaces = get_network_interfaces()

    local lan_name = settings.lan_name or 'eth0'
    local lan_iface = nil
    for _, iface in ipairs(interfaces) do
        if (iface.name == lan_name) then
            lan_iface = iface
            break
        end
    end

    settings.interface   = lan_iface
    settings.lan_ip      = settings.lan_ip or lan_iface.ip or '0.0.0.0'
    settings.lan_netmask = settings.lan_netmask or lan_iface.netmask or '0.0.0.0'

    response:json(settings)
end

local function on_settings_wireless(request, response)
    local category = 'wl'
    local keys = { 'name', 'enabled', 'ssid', 'key', 'dns', 'gateway', 'ip', 'mode', 'netmask' }

    local profile = get_settings_profile()
    if is_edit_action(request) then
        local params = request.params
        local list = {}
        if (params.wl_dns1) then
            list[#list + 1] = params.wl_dns1
        end
        if (params.wl_dns2) then
            list[#list + 1] = params.wl_dns2
        end
        params.wl_dns = table.concat(list, ' ')

        on_save_params(profile, category, keys, params)
    end

    local settings = on_load_params(profile, category, keys)
    if (settings.wl_dns) then
        local tokens = settings.wl_dns:split(' ')
        settings.wl_dns1 = tokens[1] or ''
        settings.wl_dns2 = tokens[2] or ''
    end

    local interfaces = get_network_interfaces()

    local wl_name = settings.wl_name or 'wlan0'
    local wl_iface = nil
    for _, iface in ipairs(interfaces) do
        if (iface.name == wl_name) then
            wl_iface = iface
            break
        end
    end

    settings.interface = wl_iface
    settings.wl_ip = settings.wl_ip or wl_iface.ip or '0.0.0.0'
    settings.wl_netmask = settings.wl_netmask or wl_iface.netmask or '0.0.0.0'

    response:json(settings)
end

-- API methods
local methods = {}
methods['/device/status']       = on_device_status
methods['/settings/network']    = on_settings_network
methods['/settings/wireless']   = on_settings_wireless

httpd.call(methods, request, response)

return true
