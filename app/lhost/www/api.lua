local utils     = require('utils')
local path 	    = require('path')
local conf      = require('ext/conf')
local json      = require('json')
local fs        = require('fs')
local thread    = require('thread')
local rpc       = require('ext/rpc')
local httpd     = require('httpd')
local app       = require('app')

local querystring = require('querystring')

local function on_list()
    local list = app.list()
    local result = { applications = list }
    result.settings = app.getStartNames()
    
    local status = {}
    local list = app.processes() or {}
    for _, item in ipairs(list) do
        status[item.name] = item.pid
    end

    result.status = status
    response:json(result)
end

local function on_run_list(request, response)
    local names = app.getStartNames()
    local list  = app.processes()
    if (not list) or (#list < 1) then
        print('No matching application process were found!')
        return
    end

    local services = {}
    for name, value in pairs(names) do
        services[name] = { name = name }
    end

    for _, proc in ipairs(list) do
        local service = services[proc.name]
        if (not service) then
            service = { name = proc.name }
            services[proc.name] = service
        end

        if (not service.pids) then
            service.pids = {}
        end

        service.pids[#service.pids + 1] = tostring(proc.pid)
    end

    list = {}
    for name, service in pairs(services) do
        list[#list + 1] = service
    end 

    table.sort(list, function(a, b) 
        return tostring(a.name) < tostring(b.name) 
    end)

    return list
end

local function on_status(request, response)
    local method    = 'status'
        
    local list = on_run_list()
    console.log(list)

    local result = { applications = list }
    response:json(result)
end

local function on_restart(request, response)
    local params = request.params or {}
    local name = params.name

    if (name) then
        app.enable({name}, true)
    end

    local result = { ret = 0 }
    response:json(result)
end

local function on_stop(request, response)
    local params = request.params or {}
    local name = params.name

    if (name) then
        app.enable({name}, false)
    end

    local result = { ret = 0 }
    response:json(result)
end

local methods = {}
methods['/status']   = on_status
methods['/list']     = on_list
methods['/restart']  = on_restart
methods['/stop']     = on_stop

httpd.call(methods, request, response)

return true
