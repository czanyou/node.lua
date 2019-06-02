local app       = require('app')
local fs        = require('fs')
local express   = require('express')
local request   = require('http/request')
local server    = require('ssdp/server')
local utils     = require('util')
local path      = require('path')
local json      = require('json')
local conf      = require('app/conf')
local device    = require('sdl')
local directory = require('wot/directory').directory()

local WEB_PORT  = 9100

local ssdpServer = nil

local exports = {}

local function getRootPath()
    return app.rootPath
end

-------------------------------------------------------------------------------
-- exports

local function getDeviceServiceList()
    local serviceList = {}

    --local service = {}
    --serviceList[1] = service

    --service.type = 'Hygrothermograph:1'
    --service.url  = 'hygrothermograph.json'

    return serviceList
end

local function getDeviceDescribe()
    local deviceInfo = device.getDeviceInfo()

    local describe = {}
    describe.version    = 1

    local info = {}
    describe.device   = info
    info.manufacturer = deviceInfo.manufacturer
    info.model        = deviceInfo.model
    info.description  = deviceInfo.description
    info.name         = deviceInfo.name or deviceInfo.model
    info.serialNumber = deviceInfo.serialNumber
    info.type         = deviceInfo.type
    info.udn          = deviceInfo.udn
    info.target       = deviceInfo.target
    info.version      = deviceInfo.version
    info.arch         = deviceInfo.arch

    info.serviceList = getDeviceServiceList()
    return describe
end

local function getThingDescribe(request)
    local params = request.params or {}

    local describe = directory.things[params.thing] or {}
    if (describe.getDescription) then
        describe = describe:getDescription()
    end

    return describe
end

local function getThingHandlers(request)
    local params = request.params or {}

    local thing = directory.things[params.thing] or {}
    if (thing.handlers) then
        return thing.handlers
    end

    return nil
end

-- /device
local function onGetDevice(request, response)
    response:json(getDeviceDescribe())
end

local function onGetThing(request, response)
    local describe = getThingDescribe(request) or {}
    response:json(describe)
end

local function onGetThingProperties(request, response)
    local describe = getThingDescribe(request) or {}
    response:json(describe.properties or {})
end

local function getHandler(request, type)
    local handlers = getThingHandlers(request) or {}

    local params = request.params or {}
    local name = params['name'] or ''

    -- console.log(params, name, handlers)

    return handlers['@' .. type .. '.' .. name]
end

local function onGetThingProperty(request, response)
    local result
    local handler = getHandler(request, 'read')
    if (handler) then
        result = handler()
    end
    response:json(result or {})
end

local function onPostThingProperty(request, response)
    local result
    local handler = getHandler(request, 'write')
    if (handler) then
        result = handler(request.query or request.body)
    end
    response:json(result or {})
end

local function onGetThingActions(request, response)
    local describe = getThingDescribe(request) or {}
    response:json(describe.actions or {})
end

local function onGetThingAction(request, response)
    local describe = getThingDescribe(request) or {}
    local actions = describe.actions or {}

    local params = request.params or {}
    local name = params['name']
    response:json(actions[name] or {})
end

local function onPostThingAction(request, response)
    -- console.log('onPostThingAction', request.url, request.body);
    local result
    local handler = getHandler(request, 'action')
    if (handler) then
        result = handler(request.query or request.body)
    end

    response:json(result or {})
end

local function onGetThingEvents(request, response)
    local describe = getThingDescribe(request) or {}
    response:json(describe.events or {})
end

local function onGetThingEvent(request, response)
    local describe = getThingDescribe(request) or {}
    local events = describe.events or {}

    local params = request.params or {}
    local name = params['name']
    response:json(events[name] or {})
end

local function onGetThings(request, response)
    local result = {}
    for name, describe in pairs(directory.things) do
        if (describe.getDescription) then
            describe = describe:getDescription()
        end
        result[#result + 1] = describe
    end
    
    --console.log(result)
    response:json(result)
end

-- default root index.html
local function onGetRoot(request, response)
    local result = {}
    result.version = process.version;
    result.links = {{
        name = "Gateway",
        description = "gateway of things",
        href = "/things/gateway"
    }, {
        name = "Gateway Device",
        href = "/device"
    }}
    response:json(result)
end

local function startHttpServer(app)
    if (not app) then
        app = express({ })
        app:listen(WEB_PORT)
    end

    --app:get("/",              onGetRoot)
    app:get("/device",          onGetDevice)
    app:get("/things",          onGetThings)
    app:get("/things/:thing",   onGetThing)

    app:get("/things/:thing/properties", onGetThingProperties)
    app:get("/things/:thing/actions", onGetThingActions)
    app:get("/things/:thing/events", onGetThingEvents)

    app:get("/things/:thing/properties/:name", onGetThingProperty)
    app:get("/things/:thing/actions/:name", onGetThingAction)
    app:get("/things/:thing/events/:name", onGetThingEvent)    

    app:post("/things/:thing/properties/:name", onPostThingProperty)
    app:post("/things/:thing/actions/:name", onPostThingAction)
end

function exports.scan(serviceType, timeout)
    local client = require('ssdp/client')
    local list = {}

    local grid = app.table({20, 24, 24})

    print("Start scaning...")

    grid.line()
    grid.cell("IP", "UID", "Model")
    grid.line('=')


    local ssdpClient = client({}, function(response, rinfo)
        if (list[rinfo.ip]) then
            return
        end

        local headers   = response.headers
        local item      = {}
        item.remote     = rinfo
        item.usn        = headers["usn"] or ''

        list[rinfo.ip] = item

        --console.log(headers)

        local model = headers['X-DeviceModel']
        local name = rinfo.ip .. ' ' .. item.usn
        if (model) then
            name = name .. ' ' .. model
        end

        console.write('\r')  -- clear current line
        grid.cell(rinfo.ip, item.usn, model)
    end)

    -- search for a service type 
    serviceType = serviceType or 'urn:schemas-upnp-org:service:cmpp-iot'
    ssdpClient:search(serviceType)

    local scanCount = 0
    local scanTimer = nil
    local scanMaxCount = timeout or 10

    scanTimer = setInterval(500, function()
        ssdpClient:search(serviceType)
        console.write("\r " .. string.rep('.', scanCount))

        scanCount = scanCount + 1
        if (scanCount >= scanMaxCount) then
            clearInterval(scanTimer)
            scanTimer = nil
            
            ssdpClient:stop()

            console.write('\r') -- clear current line
            grid.line()
            print("End scaning...")
        end
    end)
end

function exports.start(app)
    local deviceInfo = device.getDeviceInfo()
    local model = deviceInfo.model or deviceInfo.target
    
    local server = require('ssdp/server')

    local ssdpSig = "Node.lua/" .. process.version .. ", UPnP/1.0, ssdp/" .. server.version
    model = model .. '/' .. process.version
    local options = { 
        udn = deviceInfo.udn, 
        ssdpSig = ssdpSig, 
        deviceModel = model 
    }
    exports.ssdpServer = server(options)

    local localAddress = exports.ssdpServer:getLocalAddress() or '0.0.0.0'
    local localtion = "http://" .. localAddress .. ':' .. WEB_PORT .. '/device'
    exports.ssdpServer.location = localtion

    local timerId = nil
    timerId = setInterval(2000, function()
        --print(exports.ssdpServer.deviceId)

        if (not exports.ssdpServer.deviceId) then
            local mac = device.getMacAddress()
            if (mac) then
                exports.ssdpServer.deviceId = 'uuid:' .. mac
            end
            return
        end

        clearInterval(timerId)
    end)

    startHttpServer(app)
    print('WoT server started.')
end

return exports
