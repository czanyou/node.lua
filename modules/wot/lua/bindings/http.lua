local express   = require('express')
local wot       = require('wot')

local WEB_PORT  = 9100

local exports = {}

-------------------------------------------------------------------------------
-- exports

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

local function onGetThingProperties(request, response)
    local thing = getThing(request)

    local properties = nil
    if (thing) then
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

local function cors(request, response, next)
    response:set('Access-Control-Allow-Origin', '*');
    response:set('Access-Control-Allow-Credentials', 'true');
end

function exports.route(app)
    app:use(cors)
    app:get("/things",          onGetThings)
    app:get("/things/:thing",   onGetThing)
    return app
end

function exports.createServer(app)
    print('WoT server started.')
    
    if (not app) then
        app = express({ })
        app:listen(WEB_PORT)
    end

    return exports.route(app)
end


-- local function insertThings()
--     if (not app) then
--         app = express({ })
--         app:listen(WEB_PORT)
--     end
--     app:get("/things",          onGetThings)
--     app:get("/things/:thing",   onGetThing)
-- end
-- exports.insertThings = insertThings
return exports
