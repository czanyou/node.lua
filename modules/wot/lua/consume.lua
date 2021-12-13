local json     = require('json')
local core     = require('core')

local wotclient = require('wot/client')

---@class consume
local exports = {}

-- ------------------------------------------------------------
-- ConsumedThing

---@class ConsumedThing
local ConsumedThing  = core.Emitter:extend()

---@param thingInstance ThingDescription
function ConsumedThing:initialize(thingInstance)
    if (type(thingInstance) == 'string') then
        thingInstance = json.parse(thingInstance)
    end

    self.handlers = {}
    self.instance = thingInstance or {}
    self.id = thingInstance.id
    self.client = wotclient.client
    self.consumed = true

    if (self.client) then
        self.client.things['@' .. self.id] = self;
    end
end

function ConsumedThing:invokeAction(name, params, callback)
    local client = self.client;
    if (not client) then
        return nil, 'Invalid client'
    end

    local data = {}
    data[name] = params;

    local options = { did = self.id }
    local mid, err = client:sendActionMessage(data, options, callback)
    return mid, err
end

function ConsumedThing:readAllProperties()

end

function ConsumedThing:readMultipleProperties(names)

end

function ConsumedThing:readProperty(name)

end

function ConsumedThing:subscribeEvent(name, listener)

end

function ConsumedThing:subscribeProperty(name, listener)

end

function ConsumedThing:unsubscribeEvent(name)

end

function ConsumedThing:unsubscribeProperty(name)

end

function ConsumedThing:writeMultipleProperties(values)

end

function ConsumedThing:writeProperty(name, value)

end

exports.ConsumedThing = ConsumedThing

---@return ConsumedThing
function exports.consume(thingDescription)
    return ConsumedThing:new(thingDescription);
end

return exports
