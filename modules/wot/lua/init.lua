local core = require('core')

local expose = require('wot/expose') ---@type expose
local consume = require('wot/consume') ---@type consume
local wotClient = require('wot/client')

local exports = {}

exports.STATE_UNREGISTER = 0
exports.STATE_REGISTER = 1

-- ------------------------------------------------------------
-- ThingDiscover

---@class ThingDiscover
local ThingDiscover = core.Emitter:extend()

function ThingDiscover:initialize(filter)
    self.active = false
    self.done = false
    self.error = nil
    self.filter = filter
end

function ThingDiscover:start()

end

function ThingDiscover:stop()

end

function ThingDiscover:next()

end

-- ------------------------------------------------------------
-- exports

function exports.client()
    return wotClient.client
end

-- Accepts an td argument of type ThingDescription and returns a
-- ConsumedThing object instantiated based on parsing that description.
---@param thingDescription string|table - ThingDescription
---@return ConsumedThing
function exports.consume(thingDescription)
    return consume.consume(thingDescription);
end

-- Starts the discovery process that will provide ThingDescriptions
-- that match the optional argument filter of type ThingFilter.
-- @param filter ThingFilter optional
-- Observable
function exports.discover(filter)
    local options = filter or {}
    local method = options.method or 'all'
    local url = options.url
    local query = options.query

    return ThingDiscover:new(method);
end

-- Accepts a model argument of type ThingDescription and returns an
-- ExposedThing object
---@param thingDescription string|table - ThingDescription
---@return ExposedThing
function exports.produce(thingDescription)
    return expose.produce(thingDescription)
end

---@return table<string, WotServer>
function exports.servers()
    return wotClient.client and wotClient.client.options.servers
end

---@return table<string, ExposedThing>
function exports.things()
    local client = wotClient.client
    return client and client.things
end

---@param forms WotClientForms
---@return WotClient
function exports.getClient(forms)
    if (not forms) then
        return wotClient.client
    end

    ---@class WotClientForms
    local WotClientForms = {}

    ---@type WotClientOptions
    local options = {}
    options.clientId = forms.clientId
    options.forms = forms
    options.id = forms.id

    -- console.log('options', options)
    return wotClient.getClient(options, true)
end

-- MQTT 客户端连接状态
---@return boolean
function exports.isConnected()
    local client = wotClient.client;
    local mqttClient = client and client.mqtt
    return mqttClient and mqttClient.connected;
end

return exports
