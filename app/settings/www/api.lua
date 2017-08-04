local conf   = require('ext/conf')
local json   = require('json')
local lpm    = require('ext/lpm')
local path   = require('path')
local utils  = require('utils')
local fs     = require('fs')
local app    = require('app')
local httpd  = require('httpd')

local formdata      = require('express/formdata')
local querystring   = require('querystring')
local upgrade       = require('ext/upgrade')

local uploadCounter = 1


local function formatMACAddress(address)
    local result = {}

    for i = 1, 6 do
        result[#result + 1] = address:sub(i * 2 - 1, i * 2)
    end

    return table.concat(result, ':')
end

function getRootPath()
    return conf.rootPath
end

-- 配置信息都保存在 user.conf 文件中
local function get_settings_profile()
    local profile = nil
    if (not profile) then
        profile = conf('user')
    end

    return profile
end

function get_system_target()
	local platform = os.platform()
	local arch = os.arch()

    local target = nil
	if (platform == 'win32') then
        target = platform

    elseif (platform == 'darwin') then
		target =  platform
    end

    local filename = conf.rootPath .. '/package.json'
    local packageInfo = json.parse(fs.readFileSync(filename)) or {}
    target = target or packageInfo.target or 'linux'
    target = target:trim()
    return target, (process.version or '')
end

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

local function on_device_reboot(request, response)
    local status = { ret = 0 }
    local result = 0

    setTimeout(1000, function()
        os.execute("killall lnode; lpm start lhost&")
    end)

    status.message = tostring(result or "")
    response:json(status)
end

local function on_device_restore(request, response)
    local status = { ret = 0 }
    local result = os.execute("lpm restore")
    status.message = tostring(result or "")
    response:json(status)
end

local function on_device_status(request, response)
    local device = {}
    local status = { device = device }

    local cpu = os.cpus() or {}
    cpu = cpu[1] or {}
    cpu = cpu.model or ''

    local stat = fs.statfs('/') or {}
    local storage_total = (stat.blocks or 0) * (stat.bsize or 0)
    local storage_free  = (stat.bfree or 0) * (stat.bsize or 0)

    local memmory_total = os.totalmem()
    local memmory_free  = os.freemem()

    local memmory = app.formatBytes(memmory_free) .. " / " .. app.formatBytes(memmory_total) .. 
        " (" .. math.floor(memmory_free * 100 / memmory_total) .. "%)"

    local storage = app.formatBytes(storage_free) .. " / " .. app.formatBytes(storage_total) .. 
        " (" .. math.floor(storage_free * 100 / storage_total) .. "%)"

    local model = get_system_target() .. " (" .. os.arch() .. ")"

    device.device_name      = ''
    device.device_model     = model
    device.device_version   = process.version
    device.device_memmory   = memmory
    device.device_cpu       = cpu
    device.device_root      = app.rootPath
    device.device_url       = app.rootURL        
    device.device_storage   = storage
    device.device_time      = os.date('%Y-%m-%dT%H:%M:%S')
    device.device_uptime    = os.uptime()

    response:json(status)   
end

local function on_device_update(request, response)
    local status = { ret = 0 }

    upgrade.update(function(err, filename, info)
        if (info and info.version) then
            status.firmware_latest   = (info.target or target) .. '@' .. info.version
        end

        response:json(status)
    end)
end

local function on_device_upgrade(request, response)
    local status = { ret = 0 }
    local result = os.execute("lpm upgrade")
    status.message = tostring(result or "")
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

local function on_settings_date(request, response)
    local category = 'time'
    local keys = { 'sync', 'zone' }

    local lsdl = require('lsdl')

    local profile = get_settings_profile()
    local params = request.params
    if (params.time_new) then
        if (lsdl.set_system_time) then
            lsdl.set_system_time(tonumber(params.time_new))
        end

    elseif is_edit_action(request) then 
        on_save_params(profile, category, keys, params)
    end

    local settings = on_load_params(profile, category, keys)
    settings.time_now = os.date("%Y-%m-%d %H:%M:%S", os.time())
    response:json(settings)
end

local function on_settings_firmware(request, response)
    local category = 'firmware'
    local keys = { 'version', 'time' }
    local profile = get_settings_profile()

    local settings = on_load_params(profile, category, keys)
    local target, version, time = get_system_target()

    settings.firmware_target    = target
    settings.firmware_version   = target .. '@' .. version
    settings.firmware_time      = os.date('%Y-%m-%dT%H:%M:%S', time)

    local tmpdir = os.tmpdir or '/tmp'
    local filename = path.join(tmpdir, 'latest-sdk.json')
    local data = fs.readFileSync(filename)
    local info = json.parse(data)
    if (info and info.version) then
        settings.firmware_latest   = (info.target or target) .. '@' .. info.version
    end

    response:json(settings)
end

local function on_settings_register(request, response)
    local category = 'register'
    local keys = { 'enabled', 'server', 'account', 'password' }

    local profile = get_settings_profile()
    if is_edit_action(request) then
        local params = request.params
        on_save_params(profile, category, keys, params)
    end

    local settings = on_load_params(profile, category, keys)
    response:json(settings)
end

local function on_settings_user(request, response)
    local category = 'user'
    local keys = { 'password', 'user' }

    local settings = { ret = 0 }

    local profile = conf('passwd')
    if is_edit_action(request) then
        local params = request.params
        --on_save_params(profile, category, keys, params)

        local oldpassword = profile:get('user.password') or '888888'
        if (not oldpassword) or (oldpassword ~= params.oldpassword) then
            settings.error = 'Bad old password'

        elseif (not params.password) then
            settings.error = 'Empty password'

        else
            profile:set('user.password', params.password)
            profile:commit()
        end
    end

    --settings = 
    response:json(settings)
end

local function on_vision_login(request, response)
    local status = { ret = 0 }

    response:json(status)
end

local function on_vision_logout(request, response)
    local status = { ret = 0 }
    response:json(status)
end

local function on_upgrade_result(request, response, status)
    status = status or {}

    local html = {}
    html[#html + 1] = [[
<!DOCTYPE html>
<html>
<head>
  <title>Upgrade Result</title>
  <link rel="shortcut icon" type="image/icon" href="/favicon.ico?v=100003"/>
  <meta http-equiv="Content-Type" content="text/html; charset=utf-8"/>
  <meta http-equiv="X-UA-Compatible" content="IE=edge,chrome=1" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, minimum-scale=1.0, user-scalable=no"/>
  <link rel="stylesheet" href="/style.css?v=100003"/>
  <script src="/jquery.js?v=100003"></script>
  <script src="/common.js?v=100003"></script>
  <script src="lang.js?v=100003"></script>
  <script>

    $(document).ready(function() {
        $translate(document.body)
    });
    </script>

</head>
<body class="app-status" style="display:none">

  <header id="header" class="header-wrapper"><div class="header-inner">
      <a class="logo" href="#status"><h1>${UpgradeFinish}</h1></a>
    </div></header>

  <div id="main-wrapper"><div id="main-inner"><dl>]]

    local data = status.data
    if (data and data.total) then
        html[#html + 1] = string.format('<dt>${UpgradeTotalFiles}</dt><dd>%s</dd>',  data.total)
        html[#html + 1] = string.format('<dt>${UpgradeTotalBytes}</dt><dd>%s</dd>',  data.totalBytes)
        html[#html + 1] = string.format('<dt>${UpgradeVersion}</dt><dd>%s</dd>',     data.version)
        html[#html + 1] = string.format('<dt>${UpgradeUpdated}</dt><dd>%s</dd>',     data.updated)
        html[#html + 1] = string.format('<dt>${UpgradeFaileds}</dt><dd>%s</dd>',     data.faileds)
        html[#html + 1] = string.format('<dt>${UpgradeRootPath}</dt><dd>%s</dd>',    data.rootPath)
    end

    if (status.error) then
        html[#html + 1] = string.format('<dt>${UpgradeError}</dt><dd>%s</dd>', status.error)
    end

    html[#html + 1] = [[</dl></div></div>

  <footer id="footer"></footer>
</body>
</html>
]]

    response:send(table.concat(html))
end

local function on_settings_upgrade(request, response)
    --console.log(request.headers)
    local contentLength = tonumber(request.headers['Content-Length'])
    local MAX_LENGTH = 1024 * 1024 * 2
    if (not contentLength) or (contentLength <= 0) or (contentLength > MAX_LENGTH) then
        response:sendStatus(400, "Bad request: invalid content length!")
        return 
    end

    local filename = nil
    local timerId  = nil
    local filedata = nil

    local FormData = formdata.FormData
    local parser = FormData:new(contentLength)
    parser:on('file', function(data)
        filedata = data
    end)

    request:on('data', function(data)
        parser:processData(data)
    end)

    request:on('end', function(data)
        if (filedata == nil) then
            response:sendStatus(400, "Bad request: invalid upload file!")
            return
        end

        local upgrade = require('ext/upgrade')
        upgrade.handleUpgradePost(filedata, {}, function(result)
            on_upgrade_result(request, response, result)
        end)  
    end)
end


-- API methods
local methods = {}
methods['/device/reboot']       = on_device_reboot
methods['/device/restore']      = on_device_restore
methods['/device/status']       = on_device_status
methods['/device/update']       = on_device_update
methods['/device/upgrade']      = on_device_upgrade

methods['/settings/date']       = on_settings_date
methods['/settings/firmware']   = on_settings_firmware
methods['/settings/register']   = on_settings_register
methods['/settings/user']       = on_settings_user
methods['/settings/upgrade']    = on_settings_upgrade
methods['/settings/result']     = on_upgrade_result

methods['/vision/login']        = on_vision_login
methods['/vision/logout']       = on_vision_logout

-- call API methods
local function do_api(request, response)
    if (httpd and not httpd.isLogin(request)) then
        response:sendStatus(401, "Unauthorized")
        return
    end

    local api = request.api
    local method = methods[api]
    if (method) then
        method(request, response)
    else
        response:sendStatus(400, "No `api` parameters specified!")
    end
end

-- request
request.params  = querystring.parse(request.uri.query) or {}
request.api     = request.params['api']
do_api(request, response)

return true
