local conf   = require('ext/conf')
local lpm    = require('ext/lpm')
local json   = require('json')
local path   = require('path')
local utils  = require('utils')
local fs     = require('fs')
local httpd  = require('httpd')

local profile

local function get_app_path()
    local appPath = path.join(lpm.rootPath, "app")
    if (not fs.existsSync(appPath)) then
        appPath = path.join(path.dirname(lpm.rootPath), "app")
    end

    return appPath
end

local function get_application_info(basePath)
    local filename = path.join(basePath, "package.json")
    local data = fs.readFileSync(filename)
    return data and json.parse(data)
end

local function get_settings_profile()
    if (not profile) then
        profile = conf('user')
    end

    return profile
end

local function on_login(request, response)
    local params = request.params
    local status = { ret = 0 }
    local password = params['password']
    local username = params['username']

    local session = request:getSession(true)

    if (not password) or (#password < 1) then
        status = { ret = -1, message = 'Empty Password' }

    else 
       
        local profile = conf('passwd')
        local value = profile:get('user.password') or "888888"

        if (value == password) then
            session['userinfo'] = username or 'session'
            status = { ret = 0 }

        else
            status = { ret = -1, message = 'Wrong Password' }
        end
    end
    response:json(status)
end

local function on_logout(request, response)
    local status = { ret = 0 }
    local session = request:getSession()
    if (session) then
        session['userinfo'] = nil
    end
    response:json(status)
end

local function on_applications(request, response)
    local applications = {}

    local appPath = get_app_path()
    local files = nil
    if (fs.existsSync(appPath)) then
        files = fs.readdirSync(appPath)
    end

    files = files or {}

    local index = 0
    for i = 1, #files do
        local file = files[i]
        if (file == 'httpd') then
            goto continue
        end

        local filename  = path.join(appPath, file)
        local info      = get_application_info(filename) or {}

        -- console.log(filename, info)

        local www = path.join(filename, 'www')
        if (fs.existsSync(www)) then
            info.path = 'app/' .. path.basename(file)
            table.insert(applications, info) 
            index = index + 1
        end
        
        ::continue::
    end
    
    response:json(applications)
end

local function on_application_info(request, response)

    local pathname = request.params.path or ''
    local tokens = pathname:split('/')

    local appPath = get_app_path()
    local appName = tokens[3] or ''

    local filename = path.join(appPath, appName, 'package.json')

    fs.readFile(filename, function(err, data) 
        response:json(err or json.parse(data) or {})
    end)
end

local methods = {}
methods['/login']               = on_login
methods['/logout']              = on_logout
methods['/applications']        = on_applications
methods['/application/info']    = on_application_info

methods['@noauth'] = { ['/login'] = true }

httpd.call(methods, request, response)

return true
