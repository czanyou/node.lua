local app   = require('app')
local util  = require('util')
local fs 	= require('fs')
local path 	= require('path')
local json  = require('json')
local express = require('express')
local config  = require('app/conf')
local rpc     = require('app/rpc')

local exports = {}

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

    return util.bin2hex(item.mac)
end

local function loadProfile(name)
    local nodePath = app.nodePath
    local filename = path.join(nodePath, 'conf', name)
    local data = fs.readFileSync(filename)
    return json.parse(data)
end

-- 检查客户端是否已经登录 
local function checkLogin(request, response)
    local pathname = request.uri.pathname or ''
    -- console.log(pathname)

    if (pathname == '/') or pathname:endsWith('.html') then
        local default = loadProfile('default.conf')
        local activate = default and default.activate
        if (not activate) then
            if (pathname ~= '/activate.html') then
                response:set('Location', '/activate.html')
                response:sendStatus(302)
                return true
            end

            return false
        end

        if (pathname == '/login.html') then
            return false
        end

    elseif pathname ~= '/' then
        return false
    end

    local session = request:getSession()
    local userinfo = session and session.userinfo
    if (userinfo) then
        return false
    end

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

local function apiSystemRead(request, response)
    local system = {
        version = process.version,
        mac = getMacAddress(),
        base = app.get('base'),
        mqtt = app.get('mqtt'),
        did = app.get('did')
    }

    local nodePath = app.nodePath

    local update = fs.readFileSync(nodePath .. '/update/status.json')
    local firmware = fs.readFileSync(nodePath .. '/update/update.json')

    local status = {
        system = system,
        update = json.parse(update),
        firmware = json.parse(firmware)
    }

    rpc.call('wotc', 'status', {}, function(err, result)
        status.register = result or err
        response:json(status)
    end)    
end

local function apiSystemWrite(request, response)
    local query = request.body

    if (query.update) then
        os.execute("lpm update > /tmp/update.log &")

    elseif (query.upgrade) then
        os.execute("lpm upgrade " .. query.upgrade .. " > /tmp/upgrade.log &")

    elseif (query.reboot) then
        os.execute("reboot " .. query.reboot .. " &")

    elseif (query.reset) then
        os.execute("lpm lci reset &")

    elseif (query.install) then
        os.execute("lpm install /tmp/upload > /tmp/install.log &")
    end

    local result = { code = 0 }
    response:json(result)
end

local function apiConfigRead(request, response)
    config.load("network", function(ret, profile)
        local userConfig = profile:get('static')
        -- console.log(userConfig)

        response:json(userConfig)
    end)
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

local function apiConfigWrite(request, response)
    local query = request.body

    local data = {
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
end

local function apiSystemActivateRead(request, response)
    local default = loadProfile('default.conf') or {}

    local system = {
        version = process.version,
        mac = getMacAddress(),
        base = default.base,
        mqtt = default.mqtt,
        did = default.did,
        secret = default.secret
    }

    local status = {
        system = system,
    }

    response:json(status)
end

local function apiSystemActivate(request, response)
    local query = request.body

    config.load("default", function(ret, profile)
        if (profile:get('activate')) then
            return response:json({ code = 400, error = 'Already activated' })
        end

        if (query.did) then
            profile:set("did", query.did)
        end

        if (query.base) then
            profile:set("base", query.base)
        end

        if (query.mqtt) then
            profile:set("mqtt", query.mqtt)
        end

        if (query.secret) then
            profile:set("secret", query.secret)
        end

        profile:set("activate", 'true')
        profile:set("updated", Date.now())
        profile:commit()

        local nodePath = app.nodePath
        console.log(nodePath)

        -- password
        if (not query.password) then
            return print('Invalid password')
        end

        local newPassword = util.md5string('wot:' .. query.password)
        os.execute("lpm set password " .. newPassword)

        response:json({ code = 0 })
    end)
end

local function setConfigRoutes(app) 
    -- checkLogin
    function app:onRequest(request, response)
        -- console.log('onRequest', request.path)
        return checkLogin(request, response)
    end

    -- @param pathname
    function app:getFileName(pathname)
        return path.join(self.root, pathname)
    end

    app:post('/auth/login', apiAuthLogin);
    app:post('/auth/logout', apiAuthLogout);
    app:get('/auth/self', apiAuthSelf);

    app:post('/config/write', apiConfigWrite);
    app:get('/config/read', apiConfigRead);

    app:get('/system/read', apiSystemRead);
    app:post('/system/write', apiSystemWrite);

    app:get('/system/activate', apiSystemActivateRead);
    app:post('/system/activate', apiSystemActivate);
    app:post('/upload', apiUpload);
end

function exports.start(port)
    -- document root path
    local dirname = path.dirname(util.dirname())
    local root = path.join(dirname, 'www')

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
end

return exports
