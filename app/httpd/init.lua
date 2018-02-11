local app 		= require('app')
local utils 	= require('utils')
local path 		= require('path')
local conf  	= require('ext/conf')
local json  	= require('json')
local fs    	= require('fs')
local express 	= require('express')

local TAG 		= 'httpd'
local HTTP_PORT = 80

local profile   = nil

local exports = {}

-- 配置信息都保存在 user.conf 文件中
local function getProfile()
	if (not profile) then
    	profile = conf('httpd')
	end

	return profile
end

-- 检查客户端是否已经登录 
local function checkLogin(request, response)
	local pathname = request.uri.pathname or ''

	if pathname:endsWith('.html') then
		if (pathname == '/login.html') then
			return false
		end
	else
		if (pathname ~= '/') then
			return false
		end
	end

	local session = request:getSession()
	local userinfo = session and session['userinfo']
	if (userinfo) then
		return false
	end

	response:set('Location', '/login.html')
	response:sendStatus(302)
	return true
end

-------------------------------------------------------------------------------
-- exports

function exports.help()
	print([[

Onboard WEB server

Usage: lpm httpd <command> [args]

Settings:

port       Set the listening port of HTTP server.
password   Set the admin password

Available command:

- start  [port]     Start the WEB server
- passwd <password> Change the admin password

]])

end

function exports.passwd(password)
	local profile = conf('passwd')
	if (not password) then
		console.log(profile)
		return
	end

	local old = profile:get('user.password')
	if (old ~= password) then
		profile:set('user.password', password)
		profile:commit()
	end

	console.log(profile)
end

function exports.ssdp()
    local ssdp = require('./lua/ssdp')
	ssdp.start()
end

function exports.info()
    local ssdp = require('./lua/ssdp')
	ssdp.info()
end

function exports.view()
    local ssdp = require('./lua/ssdp')
	ssdp.view()
end

function exports.start(port, ...)
	local lockfd = app.tryLock('httpd')
    if (not lockfd) then
        print('The httpd is locked!')
        return
    end

	-- listen port
	local profile 	= getProfile()
	local listenPort = port or profile:get('port') or HTTP_PORT

	-- document root path
	local dirname = utils.dirname()
	local root = path.join(dirname, 'www')

	-- app
	local app = express({ root = root })
	app.appPath = path.dirname(dirname)

	app:on('error', function(err, code) 
		print('Express', err)
		if (code == 'EACCES') then
			print('Only administrators have permission to use port 80')
		end

		print('\nusage: lpm httpd start [port]\n')
	end)

	function app:onRequest(request, response)
		return checkLogin(request, response)
	end

	function app:getFileName(pathname)
		-- HLS path
		if (pathname:startsWith('/live/')) then
	    	return path.join('/tmp', pathname)
	    end

	    local filename = path.join(self.root, pathname)
	    if (not pathname:startsWith('/app/')) then
	    	return filename
	    end

	    local tokens = pathname:split('/')
	    tokens[2] = self.appPath

	    if (tokens[4] == 'icon.png') then
	    	tokens[3] = tokens[3]
	    else
	    	tokens[3] = tokens[3] .. "/www"
	    end 

	    filename = path.join(table.unpack(tokens))
	    --print(filename)

		-- APP info
	    if (not fs.existsSync(filename)) then
		    tokens[2] = self.root
		    tokens[3] = "appinfo"
		    filename = path.join(table.unpack(tokens))
	    end

	    return filename
	end

	app:listen(listenPort)

	-- ===================================
	local ssdp = require('./lua/ssdp')
	ssdp.start()
end

app(exports)
