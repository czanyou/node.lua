local wot = require('wot')

local exports = {}

-------------------------------------------------------------------------------
-- exports

function exports.cors(request, response, next)
    response:set('Access-Control-Allow-Origin', '*');
    response:set('Access-Control-Allow-Credentials', 'true');

    next()
end

function exports.getThing(request)
    local params = request.params or {}
    local things = wot.things()
    if (not things) then
        return
    end

    return things[params.thing] or {}
end

function exports.getThingDescribe(request)
    local thing = exports.getThing(request)
    if (thing) then
        return thing.instance
    end

    return {}
end

function exports.onGetThingActions(request, response)
    local thing = exports.getThing(request)

    local actions = nil
    if (thing) then
        actions = thing.instance.actions
    end

    response:json(actions or {})
end

function exports.onGetThingProperties(request, response)
    local thing = exports.getThing(request)

    local properties = nil
    if (thing) then
        properties = thing:readAllProperties()
    end

    response:json(properties or {})
end

function exports.onGetThingProperty(request, response)
    local thing = exports.getThing(request)
    local name = request.params and request.params['name']
    local value = nil

    if (thing) then
        value = thing:readProperty(name)
    end

    response:json(value or nil)
end

function exports.onGetThings(request, response)
    local result = {}
    local things = wot.things()
    if (not things) then
        return response:json(result)
    end

    for name, thing in pairs(things) do
        table.insert(result, thing.instance)
    end

    --console.log(result)
    response:json(result)
end

function exports.onGetThing(request, response)
    local describe = exports.getThingDescribe(request) or {}
    response:json(describe)
end

function exports.onSetThingProperties(request, response)
    local thing = exports.getThing(request)

    local properties = nil
    if (thing) then
        properties = thing:readAllProperties()
    end

    response:json(properties or {})
end

function exports.onSetThingProperty(request, response)
    local thing = exports.getThing(request)
    local name = request.params and request.params['name']
    local value = nil

    if (thing) then
        value = thing:readProperty(name)
    end

    response:json(value or nil)
end

function exports.onThingAction(request, response)
    local thing = exports.getThing(request)
    local name = request.params and request.params['name']

    if (not thing) then
        return response:json({ code = 400, error = "Invalid thing ID" })
    end

    local body = request.body
    local input = body and body[name]
    local ret = thing:invokeAction(name, input)
    -- console.log('invokeAction', name, body, input, ret, thing)

    if (not ret) then
        return response:json({ code = 400, error = "Invalid response" })

    elseif (not ret.next) then
        return response:json(ret)
    end

    ret:next(function(data)
        response:json(data)

    end):catch(function(err)
        response:json(err)
    end)
end

function exports.route(app)
    app:use(exports.cors)
    app:get("/things",                          exports.onGetThings)
    app:get("/things/:thing",                   exports.onGetThing)
    app:get("/things/:thing/actions",           exports.onGetThingActions)
    app:get("/things/:thing/properties",        exports.onGetThingProperties)
    app:get("/things/:thing/properties/:name",  exports.onGetThingProperty)
    app:post("/things/:thing/actions/:name",    exports.onThingAction)
    app:post("/things/:thing/properties",       exports.onSetThingProperties)
    app:post("/things/:thing/properties/:name", exports.onSetThingProperty)
    return app
end

return exports
