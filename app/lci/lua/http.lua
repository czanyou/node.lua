local app   = require('app')
local util  = require('util')
local fs 	= require('fs')
local path 	= require('path')
local json  = require('json')
local express = require('express')
local config  = require('app/conf')

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

-- 检查客户端是否已经登录 
local function checkLogin(request, response)
    local pathname = request.uri.pathname or ''

    console.log(pathname)

    if pathname:endsWith('.html') then
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

    local value = app.get('password') or "wot2019"
    if (value ~= password) then
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

local function apiStatusRead(request, response)
    local system = {
        version = process.version,
        mac = getMacAddress()
    }

    local nodePath = app.nodePath

    local update = fs.readFileSync(nodePath .. '/update/status.json')
    local firmware = fs.readFileSync(nodePath .. '/update/update.json')

    local status = {
        system = system,
        update = json.parse(update),
        firmware = json.parse(firmware)
    }

    response:json(status)
end

local function apiStatusWrite(request, response)
    local query = request.body

    if (query.update) then
        os.execute("lpm update &")

    elseif (query.upgrade) then
        os.execute("lpm upgrade " .. query.upgrade .. " &")

    elseif (query.reboot) then
        os.execute("reboot " .. query.reboot .. " &")
    end

    local result = { code = 0 }
    response:json(result)
end

local function apiConfigRead(request, response)
    config.load("network", function(ret, profile)
        local userConfig = profile:get('static')
        console.log(userConfig)

        response:json(userConfig)
    end)
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

local function setConfigRoutes(app) 
    -- checkLogin
    function app:onRequest(request, response)
        console.log('onRequest', request.path)
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

    app:get('/system/read', apiStatusRead);
    app:post('/system/write', apiStatusWrite);
end

function exports.start(port)
 
    -- document root path
    local dirname = path.dirname(util.dirname())
    local root = path.join(dirname, 'www')

    console.log(root)

    -- app
    local app = express({ root = root })

    app:on('error', function(err, code) 
        print('Express', err)
        if (code == 'EACCES') then
            print('Only administrators have permission to use port 80')
        end
    end)

    setConfigRoutes(app)

    app:listen(port or 80)
end

return exports
