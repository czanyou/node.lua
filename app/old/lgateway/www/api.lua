local conf   = require('app/conf')
local json   = require('json')
local path   = require('path')
local utils  = require('util')
local fs     = require('fs')
local querystring = require('querystring')

local profile

local function get_application_info(basePath)
    local filename = path.join(basePath, "package.json")
    local data = fs.readFileSync(filename)
    return data and json.parse(data)
end

local function get_config()
    local basePath = path.join(conf.rootPath, "app/lgateway")
    local packageInfo = get_application_info(basePath);
    local applications = packageInfo.settings;
    
    return applications;
end

local function get_app_path()
    local appPath = path.join(conf.rootPath, "app")
    if (not fs.existsSync(appPath)) then
        appPath = path.join(path.dirname(conf.rootPath), "app")
    end

    return appPath
end

local function get_settings_profile()
    if (not profile) then
        profile = conf('user')
    end

    return profile
end

local function on_applications(request, response)
    local applications = get_config()
    local profile = get_settings_profile()

    for index, application in ipairs(applications) do
        --console.log(key, value)
        local configs = application.config or {}
        for _, config in ipairs(configs)  do
            local items = config.items;
            for _, item in ipairs(items)  do
                -- console.log(index, item)
                item.value = profile:get(config.name .. '.' .. item.name)
                console.log(config.name .. '.' .. item.name, item.value);
            end
        end
    end

    response:json(applications)
end

local function on_settings(request, response)
    local ret = { ret = 0 }

    local profile = get_settings_profile()
    console.log(request.body)

    local applications = get_config()

    for index, application in ipairs(applications) do
        --console.log(key, value)
        local configs = application.config or {}
        for _, config in ipairs(configs)  do
            local items = config.items;
            for _, item in ipairs(items)  do
                -- console.log(index, item)
                --item.value = profile:get()
                --console.log(config.name .. '.' .. item.name, item.value);
                local name = config.name .. '.' .. item.name;
                local value = request.body[name];
                if (not item.readonly) and (value) then
                    if (item.type == 'boolean') then
                        value = value == 'yes'

                    elseif (item.type == 'integer') then
                        value = math.floor(tonumber(value) or 0)

                    elseif (item.type == 'number') then
                        value = tonumber(value) or 0
                    end

                    profile:set(name, value)
                end
            end
        end
    end

    --for key, value in pairs(request.body) do
    --    profile:set(key, value)
    --end

    profile:commit()

    response:json(ret)
end

local function on_display(request, response)
    --console.log(request.method);
    --console.log(request.query);
    --console.log(request.body);

    local cmdline = 'test display ' .. 

end

local methods = {}

methods['/applications'] = on_applications
methods['/settings'] = on_settings
methods['/display'] = on_display

methods['@noauth'] = { ['/login'] = true, ['/'] = true }

function isLogin(request)
	if (request == nil) then
		return true
	end

	local session = request:getSession()
	local userinfo = session and session['userinfo']
	if (userinfo) then
		return true
	end

	return false
end


-- call API methods
function dispatchMethod(methods, request, response, flags)
	request.params  = querystring.parse(request.uri.query) or {}
	request.api     = request.params['api']

    local api = request.api
    local method = methods[api]
    if (not method) then
        response:sendStatus(400, "No `api` parameters specified!")
        return
    end

    -- skip noauth API
    local noauth = methods['@noauth']
   	if (noauth) then
   		noauth = noauth[api]
   	end

   	-- check login
    if (not noauth) and (not isLogin(request)) then
        response:json({code = 200, erro = "Unauthorized"})
        return
    end

	request:readBody(function()
		local err

    	local handler = function(message)
        	err = (message or '') .. "\r\n" .. debug.traceback()
    	end

    	local ret = xpcall(method, handler, request, response)
    	if (not ret) then
    		local content = '<pre><code>' .. tostring(err) .. '</code></pre>'
        	response:sendStatus(500, content)
    	end
    end)
end

dispatchMethod(methods, request, response)

return true
