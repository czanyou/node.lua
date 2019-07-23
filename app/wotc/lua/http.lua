local app   = require('app')
local util  = require('util')
local url 	= require('url')
local fs 	= require('fs')
local path 	= require('path')
local http  = require('http')
local json  = require('json')
local wot   = require('wot')
local express = require('express')

local httpd  = require('wot/bindings/http')
local ssdpServer = require('ssdp/server')

local gateway = require('./gateway')
local log = require('./log')

local exports = {}

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

    local value = app.get('user.password') or "888888"
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
