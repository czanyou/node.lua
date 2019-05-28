local app       = require('app')
local fs        = require('fs')
local express   = require('express')
local request   = require('http/request')
local server    = require('ssdp/server')
local utils     = require('util')
local path      = require('path')
local json      = require('json')
local conf      = require('app/conf')
local devices    = require('devices')

local wot       = require('wot')

local WEB_PORT  = 9100

local ssdpServer = nil

local exports = {}

local function getRootPath()
    return app.rootPath
end

-------------------------------------------------------------------------------
-- exports

local function getDeviceDescribe()
    local deviceInfo = devices.getDeviceInfo()

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

    return describe
end

local function getThing(request)
    local params = request.params or {}
    local client = wot.client
    local things = client and client.things
    if (not things) then
        return
    end

    return things[params.thing] or {}
end

local function getThingDescribe(request)
    local thing = getThing(request)
    if (thing) then
        return thing.instance
    end

    return {}
end

-- /device
local function onGetDevice(request, response)
    response:json(getDeviceDescribe())
end

local function onGetThingProperties(request, response)
    local thing = getThing(request)

    local properties = nil
    if (thing and name) then
        properties = thing:readAllProperties()
    end

    response:json(properties or {})
end

local function onGetThingProperty(request, response)
    local thing = getThing(request)
    local name = request.params and request.params['name']
    local value = nil

    if (thing) then
        value = thing:readProperty(name)
    end

    response:json(value or {})
end

local function onPostThingProperty(request, response)
    response:json({ code = 0 })
end

local function onGetThingActions(request, response)
    response:json({ code = 0 })
end

local function onGetThingAction(request, response)
    response:json({ code = 0 })
end

local function onPostThingAction(request, response)
    local thing = getThing(request)
    local name = request.params and request.params['name']
    local input = request.query or request.body
    local output = nil

    if (thing) then
        output = thing:invokeAction(name, input)
    end

    response:json(output or { code = 0 })
end

local function onGetThingEvents(request, response)
    response:json({ code = 0 })
end

local function onGetThingEvent(request, response)
    response:json({ code = 0 })
end

local function onGetThing(request, response)
    local describe = getThingDescribe(request) or {}
    response:json(describe)
end

local function onGetThings(request, response)
    local result = {}
    local client = wot.client
    local things = client and client.things
    if (not things) then
        return response:json(result)
    end

    for name, thing in pairs(things) do
        table.insert(result, thing.instance)
    end
    
    --console.log(result)
    response:json(result)
end

-- default root index.html
local function onGetRoot(request, response)
    local result = {}
    result.version = process.version;
    result.links = {{
        name = "Things",
        description = "instance of things",
        href = "/things/"
    }, {
        name = "Device Information",
        href = "/device/"
    }}
    response:json(result)
end

local function cors(request, response, next)
    response:set('Access-Control-Allow-Origin', '*');
    response:set('Access-Control-Allow-Credentials', 'true');
end

local function startHttpServer(app)
    if (not app) then
        app = express({ })
        app:listen(WEB_PORT)
    end

    app:use(cors)

    app:get("/",                onGetRoot)
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

    return app
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

function exports.createServer(app)
    local deviceInfo = devices.getDeviceInfo()
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
            local mac = devices.getMacAddress()
            if (mac) then
                exports.ssdpServer.deviceId = 'uuid:' .. mac
            end
            return
        end

        clearInterval(timerId)
    end)

    print('WoT server started.')
    return startHttpServer(app)
end

return exports
