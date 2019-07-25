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

    if (thing and thing.invokeAction) then
        output = thing:invokeAction(name, input)
    end

    if (not output) then
        output = { code = 0, message = 'output is empty' }
        return response:json(output)

    elseif (not output.next) then
        return response:json(output)
    end

    -- next
    output:next(function(data)
        return response:json(data)

    end):catch(function(err)
        return response:json(err)
    end)
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
    app:get("/things",          onGetThings)
    app:get("/things/:thing",   onGetThing)

    app:get("/things/:thing/properties", onGetThingProperties)
    app:get("/things/:thing/actions", onGetThingActions)
    app:get("/things/:thing/events", onGetThingEvents)

    app:get("/things/:thing/properties/:name", onGetThingProperty)
    app:get("/things/:thing/actions/:name", onGetThingAction)
    app:get("/things/:thing/events/:name", onGetThingEvent)    

    --app:post("/things/:thing/properties/:name", onPostThingProperty)
    --app:post("/things/:thing/actions/:name", onPostThingAction)

    return app
end

function exports.createServer(app)
    print('WoT server started.')
    return startHttpServer(app)
end

return exports
