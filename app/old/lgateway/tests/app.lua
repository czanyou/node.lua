local app       = require('app')
local wot       = require('wot')
local express 	= require('express')
local path 		= require('path')
local json  	= require('json')
local util 		= require('util')
local fs    	= require('fs')

local gateway   = require('./gateway')

local TAG 		= 'gateway'
local HTTP_PORT = 80

local exports = {}

-- ----------------------------------------------------------------------------
-- Things

local function setThingRoutes(app) 
	--console.log(server)
	gateway:expose(app)

end

-- ----------------------------------------------------------------------------
-- Config


-- 检查客户端是否已经登录 
local function checkLogin(request, response)
    
	local pathname = request.uri.pathname or ''
    console.log(pathname)
	if pathname:endsWith('.html') then
		if (pathname == '/login.html') then
			return false
		end

	else
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

local function apiAccountLogin(request, response)

    console.log("apiAccountLogin")
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

local function apiAccountLogout(request, response)
	local session = request:getSession(false)
	if (session and session.userinfo) then
		session.userinfo = nil
		return response:json({ message = "logout" })
    end
    
	response:json({ code = 401, error = 'Unauthorized' })
end

local function apiAccountSelf(request, response)
	local session = request:getSession(false)
	local userInfo
	if (session) then
		userInfo = session['userinfo']
	end

	response:json(userInfo or { code = 401, error = 'Unauthorized' })
end




local config  = require('app/conf')


-- local did = app.get('did')

local function apiAccountRead(request,response)
    local profile 
    local userConfig
    local udhcpConfig
    local profile 
    local function readConfig()  
        config.load("network",function(ret,profile)

        userConfig = profile:get('config')
        udhcpConfig = profile:get('udhcp')

        console.log(userConfig)
        local result = { udhcpConfig = udhcpConfig, userConfig =userConfig }
        console.log(result)
        response:json(result)
            
        end)
    end

    readConfig()






end

local function apiAccountConfig(request, response)
	local query = request.body
    local ip        = query.ip
    local router    = query.router
    local mask      = query.mask
    local username
    console.log(query)

    local profile 
    local function saveConfig(data)  
        config.load("network",function(ret,profile)
            profile:set("config",data)
            profile:set("update","true")
            profile:commit()

        local  userConfig = profile:get('config')
        console.log(userConfig)
            
        end)
    end


    saveConfig(query)





    -- local session = request:getSession(true)
    -- session['userinfo'] = { username = (username or 'admin') }

    local result = { username = "admin" }
    -- console.log(result)
    response:json(result)
end



local function setConfigRoutes(app) 
	-- checkLogin
	-- function app:onRequest(request, response)
	-- 	console.log('onRequest', request.path)
    --     return checkLogin(request, response)


	-- end

    -- @param pathname

	function app:getFileName(pathname)
	    return path.join(self.root, pathname)
	end
    app:post('/account/config', apiAccountConfig);
	app:post('/account/login', apiAccountLogin);
    app:post('/account/logout', apiAccountLogout);
    app:post('/account/read', apiAccountRead);
    -- app:get('/account/self', apiAccountSelf);
    
end

-- ----------------------------------------------------------------------------
-- Exports

function exports.scan()
    local discover = wot.discover()
    --console.log(discover)

    discover:on('thing', function(thing)
        console.log('discover', thing)
    end)
end

function exports.start()
    local lockfd = app.lock(TAG)
    if (not lockfd) then
        print('The application is locked!')
        return
    end

	-- listen port
	local listenPort = port or app:get('port') or HTTP_PORT

	-- document root path
	local dirname = path.dirname(util.dirname())
    -- local root = path.join(dirname, 'www')
    local root = "/mnt/dt02/node.lua/app/old/lgateway/www"

    console.log(root)

	-- app
    local app = express({ root = root })
    
    app:on('error', function(err, code) 
		print('Express', err)
		if (code == 'EACCES') then
			print('Only administrators have permission to use port 80')
		end

		print('\nusage: lpm lhttpd start [port]\n')
    end)
    
    setThingRoutes(app);
    setConfigRoutes(app);

	app:listen(listenPort)    
end

function exports.register()
    --console.log(server)
    --gateway:expose()

    local gateway = {}

    local url = "http://tour.beaconice.cn/v2/"
    local client = wot.register(url, gateway)
    client:on('register', function(ret) 
        console.log(ret)
    end)

    setTimeout(1000 * 5, function()
        
    end)
end

function exports.message()
    --console.log(server)
    --gateway:expose()

    local url = "http://tour.beaconice.cn/v2/"
    local client = wot.register(url, gateway)
    client:on('register', function(ret) 
        console.log('register', ret)


        local message = {
            type = 'message',
            did = client.info.did,
            data = {
                value = 100
            }
        }

        client:sendMessage(message);
    end)

    client:on('message', function(ret) 
        console.log('message', ret)
    end)

    setTimeout(1000 * 5, function()

    end)
end


app(exports)
