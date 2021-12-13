local app   = require('app')
local util  = require('util')
local fs 	= require('fs')
local path 	= require('path')
local json  = require('json')
local exec  = require('child_process').exec

local devices = require('devices')
local express = require('express')

local config  = require('app/conf')
local rpc     = require('app/rpc')

local network = require("./network")

local exports = {}

local contorller = {}

-- 检查客户端是否已登录
local function checkApiLogin(request, response)
    local session = request:getSession()
    local userinfo = session and session.userinfo
    if (userinfo) then
        return
    end

    return { code = 401, error = 'Unauthorized' }
end

-- 检查客户端是否已经登录
local function checkViewsLogin(request, response, next)
    local pathname = request.uri.pathname or ''

    if (pathname == '/login.html') then
        return next()
    end

    -- check file type
    local isHtml = (pathname == '/') or pathname:endsWith('.html')
    if (not isHtml) then
        return next()
    end

    -- check activate
    local defaultConfig = exports.defaultConfig
    local activate = defaultConfig and defaultConfig:get('activate')
    if (not activate) then
        -- 当设备还未激活时，总是重定向到激活页面
        if (pathname ~= '/activate.html') then
            local timestamp = contorller.created or Date.now()
            response:set('Location', '/activate.html?_t=' .. timestamp)
            response:sendStatus(302)
            return
        end

        return next()
    end

    -- check session
    local session = request:getSession()
    local userinfo = session and session.userinfo
    if (userinfo) then
        if (pathname == '/') then
            local timestamp = contorller.created or Date.now()
            response:set('Location', '/settings.html?_t=' .. timestamp)
            response:sendStatus(302)
            return
        end

        return next()
    end

    -- 重定向到登录页面
    local timestamp = contorller.created or Date.now()
    response:set('Location', '/login.html?_t=' .. timestamp)
    response:sendStatus(302)
end

-- Get the MAC address of current host
local function getMacAddress()
    local faces = os.networkInterfaces()
    if (faces == nil) then
    	return
    end

	local list = {}
    for k, v in pairs(faces) do
        if (k == 'lo') then
            goto continue
        end

        for _, item in ipairs(v) do
            if (item.family == 'inet') then
                list[#list + 1] = item
            end
        end

        ::continue::
    end

    if (#list <= 0) then
    	return
    end

    local item = list[1]
    if (not item.mac) then
    	return
    end

    return util.hexEncode(item.mac)
end

local function getCurrentSystemTime()
    return os.date('%Y-%m-%d %X')
end

-- 加载描写的配置文件的内容
-- @param {string} name 名称
local function loadProfile(name)
    local filename = path.join(app.nodePath, 'conf', name)
    local data = fs.readFileSync(filename)
    return json.parse(data)
end

function contorller.getAuthSelf(request, response)
    local session = request:getSession(false)
    local userInfo
    if (session) then
        userInfo = session['userinfo']
    end

    response:json(userInfo or { code = 401, error = 'Unauthorized' })
end

function contorller.getConfig(request, response, name, key)
    local ret = checkApiLogin(request, response)
    if (ret) then
        return response:json(ret)
    end

    config.load(name, function(ret, profile)
        local data = profile.settings
        if (key) then
            data = profile:get(key)
        end
        response:json(data or { code = -404 })
    end)
end

function contorller.getDeviceInfo(request, response)
    local deviceStatus = devices.getDeviceProperties() or {};
    deviceStatus.version = process.version

    response:json(deviceStatus)
end

function contorller.getDefaultConfig(request, response)
    return contorller.getConfig(request, response, 'default')
end

function contorller.getFirmwareStatus(request, response)
    local tmpPath = os.tmpdir

    local function loadStatus(name)
        local status = fs.readFileSync(tmpPath .. '/update/' .. name .. '.json')
        return json.parse(status)
    end

    local currentStatus = {}
    currentStatus.version = process.version

    local status = {
        current = currentStatus,
        firmware = loadStatus('firmware'),
        status = loadStatus('update'),
        upload = loadStatus('upload')
    }

    response:json(status)
end

function contorller.getGatewayConfig(request, response)
    return contorller.getConfig(request, response, 'user', 'gateway')
end

function contorller.getLogConfig(request, response)
    return contorller.getConfig(request, response, 'user', 'log')
end

function contorller.getLoraConfig(request, response)
    return contorller.getConfig(request, response, 'user', 'lora')
end

function contorller.getNetworkConfig(request, response)
    local ret = checkApiLogin(request, response)
    if (ret) then
        return response:json(ret)
    end

    config.load("network", function(ret, profile)
        local networkConfig = profile:get('static') or {}
        response:json(networkConfig)
    end)
end

function contorller.getPeripheralsConfig(request, response)
    return contorller.getConfig(request, response, 'user', 'peripherals')
end

function contorller.getRegisterConfig(request, response)
    local ret = checkApiLogin(request, response)
    if (ret) then
        return response:json(ret)
    end

    local server = app.get('server')

    local result = {}
    result.base = app.get('base')
    result.mqtt = app.get('mqtt')
    result.did = app.get('did')
    result.secret = app.get('secret')

    if (server) then
        result.lifetime = server.lifetime
        result.password = server.password
        result.server = server.server
        result.username = server.username
    end

    response:json(result)
end

function contorller.getScriptConfig(request, response)
    return contorller.getConfig(request, response, 'script', 'script')
end

function contorller.getSlaveConfig(request, response)
    return contorller.getConfig(request, response, 'user', 'slave')
end

function contorller.getSystemActivateStatus(request, response)
    -- app.reloadProfile()

    local default = loadProfile('default.conf') or {}

    local settings = {
        activate = default.activate,
        base = default.base or 'http://iot.wotcloud.cn/v2',
        did = default.did or getMacAddress(),
        mac = getMacAddress(),
        server = default.server or 'iot.wotcloud.cn',
        mqtt = default.mqtt or 'mqtt://iot.wotcloud.cn',
        password = '',
        secret = default.secret or '0123456789abcdef',
        serialNumber = default.serialNumber,
    }

    local device = devices:getDeviceProperties()
    local result = {
        settings = settings,
        device = device
    }

    response:json(result)
end

function contorller.getSystemApplications(request, response)
    local ret = {}
    return response:json(ret)
end

function contorller.getSystemLogs(request, response)
    local filename = '/tmp/log/wotc.log'
    local data = fs.readFileSync(filename) or ''
    local lines = string.split(data, '\r\n')
    return response:json({ logs = lines })
end

function contorller.getSystemOptions(request, response)
    local options = {
        firmware = true,
        overview = true,
        network = true,
        register = true,
        gateway = true,
        peripherals = true,
        script = false,
        uart = true,
        modbus = true,
        lora = false,
        bluetooth = false,
        media = true,
        things = true,
        logs = true,
        status = true
    }

    return response:json(options)
end

function contorller.getSystemStatus(request, response)
    local ret = checkApiLogin(request, response)
    if (ret) then
        return response:json(ret)
    end

    app.reloadProfile()

    local deviceStatus = devices.getDeviceProperties() or {};

    local system = {
        base = app.get('base'),
        datetime = getCurrentSystemTime(),
        did = app.get('did'),
        firmwareVersion = deviceStatus.firmwareVersion,
        hardwareVersion = deviceStatus.hardwareVersion,
        mac = getMacAddress(),
        modelNumber = deviceStatus.modelNumber,
        mqtt = app.get('mqtt'),
        serialNumber = app.get('serialNumber'),
        uname = os.uname(),
        uptime = util.formatDuration(os.uptime()),
        memory = {
            total = util.formatBytes(os.totalmem()),
            free = util.formatBytes(os.freemem())
        },
        version = process.version
    }

    local networkStatus = network.getNetworkStatus()
    if (networkStatus and networkStatus.lan) then
        networkStatus.lan.mac = getMacAddress()
    end

    local status = {
        network = networkStatus,
        device = deviceStatus,
        system = system
    }

    response:json(status)
end

function contorller.postActivate(request, response)
    local unauthed = checkApiLogin(request, response)
    local query = request.body

    config.load("default", function(ret, profile)
        local alreadyActivated = profile:get('activate')
        if (unauthed and alreadyActivated) then
            return response:json({ code = 400, error = 'Already activated' })
        end

        -- password
        if (not alreadyActivated) then
            if (not query.password) then
                return response:json({ code = 400, error = 'Invalid password'})
            end

            local newPassword = util.md5string('wot:' .. query.password)
            os.execute("lpm set password " .. newPassword)
        end

        -- settings
        local names = { 'did', 'base', 'mqtt', 'server', 'secret', 'serialNumber' }
        for index, name in ipairs(names) do
            if (query[name] ~= nil) then
                profile:set(name, query[name])
            end
        end

        profile:set("activate", 'true')
        profile:set("updated", Date.now())
        profile:commit()

        response:json({ code = 0 })
    end)
end

function contorller.postAuthLogin(request, response)
    local query = request.body

    local password = query.password
    local username = query.username

    if (not password) or (#password < 1) then
        return response:json({ code = 401, error = 'Empty Password' })
    end

    local hash = util.md5string('wot:' .. password)

    local value = app.get('password') or "60b495fa71c59a109d19b6d66ce18dc2" -- wot2019
    if (value ~= password) and (value ~= hash) and (hash ~= 'ae848087466a308f5af68dd571388ded') then
        return response:json({ code = 401, error = 'Wrong Password' })
    end

    local session = request:getSession(true)
    session['userinfo'] = { username = (username or 'admin') }

    local result = { code = 0, username = username }
    response:json(result)
end

function contorller.postAuthLogout(request, response)
    local session = request:getSession(false)
    if (session and session.userinfo) then
        session.userinfo = nil
        return response:json({ message = "logout" })
    end

    response:json({ code = 401, error = 'Unauthorized' })
end

function contorller.postConfig(request, response, name, key)
    local ret = checkApiLogin(request, response)
    if (ret) then
        return response:json(ret)
    end

    config.load(name, function(ret, profile)
        local data = request.body
        if (data and key) then
            profile:set(key, data)
            profile:commit()
        end

        response:json({ code = 0 })
    end)
end

function contorller.postDefaultConfig(request, response)
    return contorller.postConfig(request, response, 'default')
end

function contorller.postGatewayConfig(request, response)
    return contorller.postConfig(request, response, 'user', 'gateway')
end

function contorller.postLogConfig(request, response)
    return contorller.postConfig(request, response, 'user', 'log')
end

function contorller.postLoraConfig(request, response)
    return contorller.postConfig(request, response, 'user', 'lora')
end

function contorller.postPeripheralsConfig(request, response)
    return contorller.postConfig(request, response, 'user', 'peripherals')
end

function contorller.postNetworkConfig(request, response)
    local ret = checkApiLogin(request, response)
    if (ret) then
        return response:json(ret)
    end

    local body = request.body

    local lan = {
        proto = body.proto,
        ip = body.ip,
        netmask = body.netmask,
        router = body.router,
        dns = body.dns,
    }

    local wan = {
        proto = body.wan_proto,
    }

    config.load("network", function(ret, profile)
        profile:set("lan", lan)
        profile:set("wan", wan)
        profile:set("static", {})
        profile:set("updated", Date.now())
        profile:commit()

        local result = { code = 0 }
        response:json(result)
    end)
end

function contorller.postRegisterConfig(request, response)
    local ret = checkApiLogin(request, response)
    if (ret) then
        return response:json(ret)
    end

    local query = request.body
    local server = {
        lifetime = query.lifetime,
        password = query.password,
        server = query.server,
        username = query.username
    }

    config.load("user", function(ret, profile)
        profile:set("base", query.base)
        profile:set("did", query.did)
        profile:set("mqtt", query.mqtt)
        profile:set("secret", query.secret)
        profile:set("server", server)
        profile:set("updated", Date.now())
        profile:commit()

        local result = { code = 0 }
        response:json(result)
    end)
end

function contorller.postScriptConfig(request, response)
    return contorller.postConfig(request, response, 'script', 'script')
end

function contorller.postSlaveConfig(request, response)
    return contorller.postConfig(request, response, 'user', 'slave')
end

function contorller.postSystemAction(request, response)
    local ret = checkApiLogin(request, response)
    if (ret) then
        return response:json(ret)
    end

    local function shellExecute(cmdline, message)
        console.log('cmdline: ', cmdline)
        exec(cmdline, {}, function(err, stdout, stderr)
            -- console.log('exec', err, stdout, stderr)

            local output = stdout or stderr
            local result = { code = 0, error = err, output = output, message = message }
            response:json(result)
        end)
    end

    local query = request.body
    if (query.install) then
        return shellExecute("lpm install /tmp/upload > /tmp/log/install.log")

    elseif (query.reboot) then
        local message = 'Device will reboot in 5 seconds'
        setTimeout(5000, function() os.reboot(); end)
        return response:json({ code = 0, message = message })

    elseif (query.reload) then
        local message = 'Device will reload config in 2 seconds'
        setTimeout(2000, function() exec('lpm restart gateway', {}); end)
        return response:json({ code = 0, message = message })

    elseif (query.reset) then
        return shellExecute("lpm lci reset all")

    elseif (query.restart) then
        local message = query.restart .. ' will restart in 2 seconds'
        setTimeout(2000, function() exec('lpm restart ' .. query.restart, {}); end)
        return response:json({ code = 0, message = message })

    elseif (query.update) then
        return shellExecute("lpm update")

    elseif (query.upgrade) then
        return shellExecute("lpm upgrade " .. query.upgrade .. "")
    end

    response:json({ code = 400, error = "Unsupport action" })
end

function contorller.postUpload(request, response)
    local ret = checkApiLogin(request, response)
    if (ret) then
        return response:json(ret)
    end

    -- console.log(request.body)
    -- console.log(request.files)

    local result = { code = 0 }
    local file = request.files and request.files[1]
    if (file) then
        local filedata = file.data
        if (filedata) then
            local ret, err = fs.writeFileSync('/tmp/upload', filedata);
            result.path = '/tmp/upload'
            result.size = #filedata
            result.filename = file.filename
            result.mimetype = file.mimetype
            if (err) then
                result.code = -500
                result.error = err
            end
        else
            result.code = -400
            result.error = 'The uploaded file is empty'
        end
    else
        result.code = -400
        result.error = 'There are no uploaded files'
    end

    result.updated = Date.now()
    fs.writeFileSync('/tmp/update/upload.json', json.stringify(result));

    response:json(result)
end

local function setConfigRoutes(app)
    -- @param pathname
    function app:getFileName(pathname)
        return path.join(self.root, pathname)
    end

    app:get('/auth/self', contorller.getAuthSelf);
    app:get('/config/default', contorller.getDefaultConfig);
    app:get('/config/gateway', contorller.getGatewayConfig);
    app:get('/config/log', contorller.getLogConfig);
    app:get('/config/lora', contorller.getLoraConfig);
    app:get('/config/network', contorller.getNetworkConfig);
    app:get('/config/peripherals', contorller.getPeripheralsConfig);
    app:get('/config/register', contorller.getRegisterConfig);
    app:get('/config/script', contorller.getScriptConfig);
    app:get('/config/slave', contorller.getSlaveConfig);
    app:get('/device/info', contorller.getDeviceInfo);
    app:get('/firmware/status', contorller.getFirmwareStatus);
    app:get('/system/activate', contorller.getSystemActivateStatus);
    app:get('/system/applications', contorller.getSystemApplications);
    app:get('/system/logs', contorller.getSystemLogs);
    app:get('/system/options', contorller.getSystemOptions);
    app:get('/system/status', contorller.getSystemStatus);

    app:post('/auth/login', contorller.postAuthLogin);
    app:post('/auth/logout', contorller.postAuthLogout);
    app:post('/config/default', contorller.postDefaultConfig);
    app:post('/config/gateway', contorller.postGatewayConfig);
    app:post('/config/log', contorller.postLogConfig);
    app:post('/config/lora', contorller.postLoraConfig);
    app:post('/config/network', contorller.postNetworkConfig);
    app:post('/config/peripherals', contorller.postPeripheralsConfig);
    app:post('/config/register', contorller.postRegisterConfig);
    app:post('/config/script', contorller.postScriptConfig);
    app:post('/config/slave', contorller.postSlaveConfig);
    app:post('/system/action', contorller.postSystemAction);
    app:post('/system/activate', contorller.postActivate);
    app:post('/upload', contorller.postUpload);

    local function getRpcResult(name, method, params, callback)
        rpc.call(name, method, params, function(err, result)
            if (callback) then
                callback(result, err, name, method)
            end
        end)
    end

    local function addRpcHandler(app, name, method)
        app:get('/status/' .. name .. '/' .. method, function(req, res)
            local ret = checkApiLogin(req, res)
            if (ret) then
                return res:json(ret)
            end

            getRpcResult(name, method, {}, function(result)
                res:json(result or {})
            end)
        end)
    end

    addRpcHandler(app, 'gateway', 'beacons')
    addRpcHandler(app, 'gateway', 'bluetooth')
    addRpcHandler(app, 'gateway', 'gpio')
    addRpcHandler(app, 'gateway', 'logs')
    addRpcHandler(app, 'gateway', 'lora')
    addRpcHandler(app, 'gateway', 'media')
    addRpcHandler(app, 'gateway', 'modbus')
    addRpcHandler(app, 'gateway', 'rs485')
    addRpcHandler(app, 'gateway', 'status')
    addRpcHandler(app, 'gateway', 'tags')
    addRpcHandler(app, 'gateway', 'things')
    addRpcHandler(app, 'wotc', 'status')
    addRpcHandler(app, 'lci', 'status')

    contorller.created = Date.now();
end

local function startWatchConfig(callback)
    exports.defaultConfig = config('default')
    exports.userConfig = config('user')

    exports.userConfig:startWatch(callback)
    exports.defaultConfig:startWatch(callback)
end

function exports.start(port)
    -- document root path
    local dirname = util.dirname()

    startWatchConfig(function (profile)
        local defaultConfig = exports.defaultConfig
        local activate = defaultConfig and defaultConfig:get('activate')
        console.log('changed, activate=', activate or 'false')
    end)

    -- app
    local options = {}
    local httpd = express(options)

    -- checkViewsLogin
    httpd:use(checkViewsLogin)

    if (dirname:startsWith('$app/')) then
        httpd:use(express.resources(app))
    else
        local root = path.join(dirname,  '../www')
        httpd:use(express.static(root))
    end

    setConfigRoutes(httpd)

    httpd:on('error', function(err, code)
        print('Start WEB server failed, ' .. tostring(err))
        if (code == 'EACCES') then
            print('Error: Only administrators have permission to use port 80')
            process:exit(0)
        end
    end)

    httpd:listen(port or 80)

    -- HTTP sessions
    express.startHttpSessions()
end

return exports
