local app   = require('app')
local util  = require('util')
local fs 	= require('fs')
local path 	= require('path')
local json  = require('json')
local exec  = require('child_process').exec

local express = require('express')
local config  = require('app/conf')
local rpc     = require('app/rpc')

local network = require("./network")

local exports = {}

-- 加载描写的配置文件的内容
-- @param {string} name 名称
local function loadProfile(name)
    local filename = path.join(app.nodePath, 'conf', name)
    local data = fs.readFileSync(filename)
    return json.parse(data)
end

local function startWatchConfig(callback)
    exports.defaultConfig = config('default')
    exports.userConfig = config('user')

    exports.userConfig:startWatch(callback)
    exports.defaultConfig:startWatch(callback)
end

-- Get the MAC address of localhost
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

local function getSystemTime()
    return os.date('%Y-%m-%d %X')
end

-- 检查客户端是否已经登录
local function checkLogin(request, response)
    local pathname = request.uri.pathname or ''
    -- console.log(pathname)
    if (pathname == '/login.html') then
        return false
    end

    -- check file type
    local isHtml = (pathname == '/') or pathname:endsWith('.html')
    if (not isHtml) then
        return false
    end

    -- check activate
    local default = exports.defaultConfig
    local activate = default and default:get('activate')
    if (not activate) then
        -- 当设备还未激活时，总是重定向到激活页面
        if (pathname ~= '/activate.html') then
            response:set('Location', '/activate.html')
            response:sendStatus(302)
            return true
        end

        return false
    end

    -- check session
    local session = request:getSession()
    local userinfo = session and session.userinfo
    if (userinfo) then
        return false
    end

    -- 重定向到登录页面
    response:set('Location', '/login.html')
    response:sendStatus(302)
    return true
end

local function apiAuthLogin(request, response)
    local query = request.body

    local password = query.password
    local username = query.username

    if (not password) or (#password < 1) then
        return response:json({ code = 401, error = 'Empty Password' })
    end

    local hash = util.md5string('wot:' .. password)

    local value = app.get('password') or "60b495fa71c59a109d19b6d66ce18dc2"
    if (value ~= password) and (value ~= hash) then
        return response:json({ code = 401, error = 'Wrong Password' })
    end

    local session = request:getSession(true)
    session['userinfo'] = { username = (username or 'admin') }

    local result = { username = username }
    response:json(result)
end

local function apiAuthLogout(request, response)
    local session = request:getSession(false)
    if (session and session.userinfo) then
        session.userinfo = nil
        return response:json({ message = "logout" })
    end

    response:json({ code = 401, error = 'Unauthorized' })
end

local function apiAuthSelf(request, response)
    local session = request:getSession(false)
    local userInfo
    if (session) then
        userInfo = session['userinfo']
    end

    response:json(userInfo or { code = 401, error = 'Unauthorized' })
end

local function apiGetSystemStatus(request, response)
    app.reloadProfile()

    local device = loadProfile('device.conf') or {}

    local system = {
        version = process.version,
        mac = getMacAddress(),
        base = app.get('base'),
        mqtt = app.get('mqtt'),
        hardwareVersion = device.hardwareVersion,
        firmwareVersion = device.firmwareVersion,
        modelNumber = device.modelNumber,
        serialNumber = app.get('serialNumber'),
        datetime = getSystemTime(),
        did = app.get('did')
    }

    local tmpPath = os.tmpdir
    local update = fs.readFileSync(tmpPath .. '/update/status.json')
    local firmware = fs.readFileSync(tmpPath .. '/update/update.json')

    local networkStatus = network.getNetworkStatus()
    if (networkStatus and networkStatus.ethernet) then
        networkStatus.ethernet.mac = getMacAddress()
    end

    local status = {
        network = networkStatus,
        system = system,
        update = json.parse(update),
        firmware = json.parse(firmware)
    }

    rpc.call('wotc', 'status', {}, function(err, result)
        status.register = result or err
        response:json(status)
    end)
end

local function apiSystemAction(request, response)

    local function shellExecute(cmdline)
        exec(cmdline, {}, function(err, stdout, stderr)
            console.log('exec', err, stdout, stderr)
            local output = stdout or stderr

            local result = { code = 0, output = output }
            response:json(result)
        end)
    end

    local query = request.body

    if (query.update) then
        return shellExecute("lpm update")

    elseif (query.upgrade) then
        return shellExecute("lpm upgrade " .. query.upgrade .. "")

    elseif (query.reboot) then
        return shellExecute("reboot " .. query.reboot .. " &")

    elseif (query.reset) then
        return shellExecute("lpm lci reset")

    elseif (query.install) then
        return shellExecute("lpm install /tmp/upload")
    end

    local result = { code = 0 }
    response:json(result)
end

local function apiUpload(request, response)
    --console.log(request.body)
    --console.log(request.files)

    local file = request.files and request.files[1]
    if (file) then
        fs.writeFileSync('/tmp/upload', file.data);
    end

    response:json({ code = 0 })
end

local function apiGetNetworkConfig(request, response)
    config.load("network", function(ret, profile)
        local userConfig = profile:get('static') or {}
        -- console.log(userConfig)

        userConfig.base = app.get('base')
        userConfig.mqtt = app.get('mqtt')

        response:json(userConfig)
    end)
end

local function apiPostNetworkConfig(request, response)
    local query = request.body

    local data = {
        net_mode = query.net_mode,
        ip_mode = query.ip_mode,
        ip = query.ip,
        netmask = query.netmask,
        router = query.router,
        dns = query.dns,
    }

    config.load("network", function(ret, profile)
        profile:set("static", data)
        profile:set("updated", Date.now())
        profile:commit()

        local result = { code = 0 }
        response:json(result)
    end)

    if (query.base and query.base ~= app.get('base')) then
        app.set('base', query.base)
    end

    if (query.mqtt and query.mqtt ~= app.get('mqtt')) then
        app.set('mqtt', query.mqtt)
    end
end

local function apiGetUserConfig(request, response)
    config.load("user", function(ret, profile)
        local gateway = profile:get('gateway')
        response:json(gateway or { code = -404 })
    end)
end

local function apiPostUserConfig(request, response)
    config.load("user", function(ret, profile)
        local gateway = request.body
        if (gateway) then
            --console.log('gateway', gateway)
            profile:set("gateway", gateway)
            profile:commit()
        end

        response:json({ code = 0 })
    end)
end

local function apiActivateRead(request, response)
    local default = loadProfile('default.conf') or {}
    local device = loadProfile('device.conf') or {}

    local system = {
        version = process.version,
        mac = getMacAddress(),
        base = default.base or 'http://iot.beaconice.cn/v2',
        mqtt = default.mqtt or 'mqtt://iot.beaconice.cn',
        did = default.did or getMacAddress(),
        hardwareVersion = device.hardwareVersion,
        firmwareVersion = device.firmwareVersion,
        modelNumber = device.modelNumber,
        serialNumber = default.serialNumber,
        secret = default.secret or '0123456789abcdef',
        password = ''
    }

    local status = {
        system = system,
    }

    response:json(status)
end

local function apiActivateWrite(request, response)
    local query = request.body

    config.load("default", function(ret, profile)
        if (profile:get('activate')) then
            return response:json({ code = 400, error = 'Already activated' })
        end

        -- password
        if (not query.password) then
            return response:json({ code = 400, error = 'Invalid password'})
        end

        local names = { 'did', 'base', 'mqtt', 'secret', 'serialNumber' }
        for index, name in ipairs(names) do
            if (query[name] ~= nil) then
                profile:set(name, query[name])
            end
        end

        profile:set("activate", 'true')
        profile:set("updated", Date.now())
        profile:commit()

        local newPassword = util.md5string('wot:' .. query.password)
        os.execute("lpm set password " .. newPassword)

        response:json({ code = 0 })
    end)
end

local function setConfigRoutes(app)
    -- checkLogin
    app:use(function(request, response, next)
        -- console.log('checkLogin', request.path, next)
        return checkLogin(request, response, next)
    end)

    -- @param pathname
    function app:getFileName(pathname)
        return path.join(self.root, pathname)
    end

    app:post('/auth/login', apiAuthLogin);
    app:post('/auth/logout', apiAuthLogout);
    app:get('/auth/self', apiAuthSelf);

    app:get('/config/network', apiGetNetworkConfig);
    app:get('/config/user', apiGetUserConfig);
    app:post('/config/network', apiPostNetworkConfig);
    app:post('/config/user', apiPostUserConfig);

    app:get('/system/status', apiGetSystemStatus);
    app:post('/system/action', apiSystemAction);

    app:get('/system/activate', apiActivateRead);
    app:post('/system/activate', apiActivateWrite);
    app:post('/upload', apiUpload);

    local function getRpcResult(name, method, params, callback)
        rpc.call(name, method, params, function(err, result)
            if (callback) then
                callback(result, err, name, method)
            end
        end)
    end

    local function addRpcHandler(app, name, method)
        app:get('/status/' .. name .. '/' .. method, function(req, res)
            getRpcResult(name, method, {}, function(result)
                res:json(result or {})
            end)
        end)
    end

    addRpcHandler(app, 'gateway', 'beacons')
    addRpcHandler(app, 'gateway', 'bluetooth')
    addRpcHandler(app, 'gateway', 'camera')
    addRpcHandler(app, 'gateway', 'logs')
    addRpcHandler(app, 'gateway', 'lora')
    addRpcHandler(app, 'gateway', 'modbus')
    addRpcHandler(app, 'gateway', 'status')
    addRpcHandler(app, 'gateway', 'tags')
    addRpcHandler(app, 'gateway', 'things')
    addRpcHandler(app, 'wotc', 'status')
end

function exports.start(port)
    -- document root path
    local dirname = path.dirname(util.dirname())
    local root = path.join(dirname, 'www')

    startWatchConfig(function (profile)
        local default = exports.defaultConfig
        local activate = default and default:get('activate')

        console.log('changed', activate)
    end)

    -- app
    local httpd = express({ root = root })

    httpd:on('error', function(err, code)
        print('Error: ', err)
        if (code == 'EACCES') then
            print('Error: Only administrators have permission to use port 80')
        end
    end)

    setConfigRoutes(httpd)

    httpd:listen(port or 80)

    -- HTTP sessions
    express.startHttpSessions()
end

return exports
