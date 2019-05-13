local json     = require('json')
local path 	   = require('path')
local ssdp     = require('ssdp/ssdp')
local util     = require('util')
local core     = require('core')
local request  = require('http/request')

local Promise  = require('wot/promise')
local mqtt     = require('wot/bindings/mqtt')

local exports = {}

-- ------------------------------------------------------------
-- DataSchema

local DataSchema = core.Object:extend()

function DataSchema:initialize(options)
    options = options or {}

    self.type           = options.type or 'string'
    self.description    = options.description or nil
    self.title          = options.title or nil
    self.constant       = options.constant or false
    self.readOnly       = options.readOnly or false
    self.writeOnly      = options.writeOnly or false

    if (self.type == 'array') then
        self.items      = options.items or nil
        self.minItems   = options.minItems or nil
        self.maxItems   = options.maxItems or nil

    elseif (self.type == 'object') then
        self.properties = options.properties or nil
        self.mandatory  = options.mandatory  or nil

    elseif (self.type == 'number') then
        self.minimum    = options.minimum  or nil
        self.maximum    = options.maximum  or nil

    elseif (self.type == 'integer') then
        self.minimum    = options.minimum  or nil
        self.maximum    = options.maximum  or nil

    elseif (self.type == 'string') then
        self.enumeration = options.enumeration or nil

    elseif (self.type == 'boolean') then

    else
        console.log('unknown type:', self.type)
    end
end

-- ------------------------------------------------------------
-- ThingAction

local ThingAction = core.Object:extend()

function ThingAction:initialize(options)
    options = options or {}

    self.title          = options.title or nil
    self.description    = options.description or nil
    self.forms          = options.forms or {}

    self.input          = options.input or nil
    self.output         = options.output or nil
end

function ThingAction:invoke(input)
    local promise = Promise.new()

    local forms = self.forms or {}
    local url = forms.href

    setTimeout(100, function()
        console.log(forms)
        promise:resolve(0)
    end)

    return promise
end

-- ------------------------------------------------------------
-- ThingProperty

local ThingProperty = DataSchema:extend()

function ThingProperty:initialize(options)
    options = options or {}
    DataSchema.initialize(self, options)

    self.observable = options.observable or false
    self.forms      = options.forms or {}
end

function ThingProperty:subscribe(callback, error, finished)
    local timer = setInterval(1000, function()
        callback(1000)
    end)

    local subscription = {
        closed = false,
        unsubscribe = function(self)
            self.closed = true

            if (timer) then
                clearInterval(timer)
                timer = nil
            end
        end
    }

    return subscription 
end

function ThingProperty:read()
    local promise = Promise.new()

    setTimeout(100, function()
        promise:resolve(100)
    end)

    return promise
end

function ThingProperty:write(value)
    local promise = Promise.new()

    setTimeout(100, function()
        promise:resolve()
    end)

    return promise
end

-- ------------------------------------------------------------
-- ThingEvent

local ThingEvent = ThingProperty:extend()

function ThingEvent:initialize(options)
    options = options or {}

    ThingProperty.initialize(self, options)
end

function ThingEvent:emit(payload)
    
end

-- ------------------------------------------------------------
-- ThingDiscover

local ThingDiscover = core.Emitter:extend()

function ThingDiscover:initialize(filter)
    self.filter = filter
end

function ThingDiscover:subscribe(callback, error, finished)
    local subscription = {
        closed = false,
        unsubscribe = function()
            self.closed = false
        end
    }

    self.callback = callback

    return subscription
end

-- ------------------------------------------------------------
-- ThingInstance

local ThingInstance = core.Emitter:extend()

function ThingInstance:initialize(options)
    options = options or {}

    self.id          = options.id or nil            -- optional
    self.name        = options.name or 'thing'      -- mandatory
    self.base        = options.base

    self.description = options.description
    self.support     = options.support

    self.security    = options.security
    self.links       = options.links

    self.properties  = {}
    self.actions     = {}
    self.events      = {}

    self.handlers    = {}

    self['@context'] = options['@context'] or nil;
    self['@type']    = options['@type'] or nil;
end

function ThingInstance:getDescription()
    local result = {}

    result.id           = self.id
    result.name         = self.name
    result.description  = self.description
    result.support      = self.support

    result.security     = self.security
    result.links        = self.links

    result.properties   = self.properties
    result.actions      = self.actions
    result.events       = self.events  

    result['@context']  = self['@context']
    result['@type']     = self['@type']

    return result
end

-- ------------------------------------------------------------
-- ConsumedThing

local ConsumedThing  = ThingInstance:extend()

function ConsumedThing:initialize(td)
    if (type(td) == 'string') then
        td = json.parse(td)
    end

    td = td or {}

    ThingInstance.initialize(self, td)

    local properties  = td.properties or {}
    local actions     = td.actions or {}
    local events      = td.events or {}

    for key, value in pairs(properties) do
        local property = ThingProperty:new(value)
        self.properties[key] = property
    end

    for key, value in pairs(actions) do
        local action = ThingAction:new(value)
        self.actions[key] = action
    end

    for key, value in pairs(events) do
        local event = ThingEvent:new(value)
        self.events[key] = event
    end
end

-- ------------------------------------------------------------
-- ExposedThing

local ExposedThing  = ThingInstance:extend()

function ExposedThing:initialize(model)
    ThingInstance.initialize(self, model)

    self.events = {}
end

function ExposedThing:addProperty(name, property)
    self.properties[name] = property

    return self
end

function ExposedThing:removeProperty(name)
    self.properties[name] = null

    return self
end

function ExposedThing:setPropertyReadHandler(name, handler)
    if (not name) then
        return
    end

    self.handlers['@read:' .. name] = handler

    return self
end

function ExposedThing:setPropertyWriteHandler(name, handler)
    if (not name) then
        return
    end
    
    self.handlers['@write:' .. name] = handler

    return self
end

function ExposedThing:addAction(name, action, handler)
    if (not name) then
        return
    end
    
    self.actions[name] = action

    self.handlers['@action:' .. name] = handler

    -- console.log(name, action, handler, self.actions, self.handlers)

    return self
end

function ExposedThing:removeAction(name)
    self.actions[name] = null

    return self
end

function ExposedThing:addEvent(name, event)
    self.events[name] = event

    return self
end

-- Removes the event specified by the name argument and updates the Thing 
-- Description. Returns a reference to the same object for supporting 
-- chaining.
function ExposedThing:removeEvent(name)
    self.events[name] = null

    return self
end

-- Start serving external requests for the Thing, so that WoT interactions
-- using Properties, Actions and Events will be possible.
function ExposedThing:expose(options)
    local promise = Promise.new()

    if (not self.httpd) then
        promise:resolve()

    else
        promise:reject()
    end

    return promise
end

-- Stop serving external requests for the Thing and destroy the object. 
-- Note that eventual unregistering should be done before invoking this 
-- method.
function ExposedThing:destroy()
    local promise = Promise.new()

    return promise
end

-- ------------------------------------------------------------
-- ThingClient

local ThingClient  = core.Emitter:extend()

function ThingClient:initialize(options)
    -- console.log('ThingClient', options);

    self.options = options or {}
    self.things = {}
end

function ThingClient:start()
    local urlString = self.options.url
    if (not urlString) then
        console.log('empty MQTT url string.')
    end

    local clientId = 'camera-' .. (self.options.id or '')
    local options = {
        clientId = clientId
    }

    local mqttClient = mqtt.connect(urlString, options)

    mqttClient:on('connect', function ()
        console.log('connect')

        for did, thing in pairs(self.things) do
            local topic = 'actions/' .. did
            mqttClient:subscribe(topic)

            self:sendRegister(did, thing)
        end
    end)

    mqttClient:on('message', function (topic, data)
        -- print(TAG, 'message', topic, data)

        local message = json.parse(data)
        if (message) then
            self:processMessage(message, topic)
        end
    end)

    self.mqtt = mqttClient;
end

function ThingClient:invokeAction(name, input, request)
    -- console.log('invokeAction', name, input, request)
    -- check name
    if (not name) then
        local err = { code = 400, error = 'Invalid action name' }
        return thingClient:sendActionResult(nil, err, request)
    end

    -- console.log('invokeAction', name, input, request, self.things)
    -- check did
    local did = request.did;
    local thing = self.things[did]
    if (not thing) then
        console.log('Invalid thing id')
        local err = { code = 404, error = 'Invalid thing id' }
        return self:sendActionResult(name, err, request)
    end

    -- check handler
    local actionName = '@action:' .. name;
    local handler = thing.handlers[actionName]
    if (not handler) then
        console.log('Action handler not found: ', name)
        local err = { code = 404, error = 'Unsupported action' }
        return self:sendActionResult(name, err, request)
    end

    -- handler
    local ret = handler(input)
    if (not ret) then
        console.log('Action invoke result is empty')
        return self:sendActionResult(name, { code = 0 }, request)

    elseif (not ret.next) then
        return self:sendActionResult(name, ret, request)
    end

    -- next
    local thingClient = self
    ret:next(function(data)
        thingClient:sendActionResult(name, data, request)

    end):catch(function(err)
        thingClient:sendActionResult(name, err, request)
    end)
end

function ThingClient:processMessage(message, topic)
    -- print(TAG, 'message', topic, message)
    local messageType = message.type
    if (not messageType) then
        return

    elseif (messageType == 'action') then
        self:processActionMessage(message)

    elseif (messageType == 'register') then
        self:emit('register', message)

        local data = message.data
        local thing = self.things[message.did]
        if (data and thing) then
            thing.token = data.token

            thing.register = {}
            thing.register.id = data.id
            thing.register.token = data.token
            thing.register.expires = data.expires
            thing.register.updated = process.now()
            -- console.log('thing', thing);
        end
    end
end

function ThingClient:readProperties(thing, names)
    if (not names) or (not (#names > 0)) then
        names = {}
        for name, property in pairs(thing.properties) do
            names[#names + 1] = name
        end
    end

    local properties = {}
    for index, name in ipairs(names) do
        local property = thing.properties[name]
        if (property) then
            local handlerName = '@read:' .. name
            local handler = thing.handlers[handlerName]
            if (handler) then
                properties[name] = handler()
            else
                properties[name] = property.value
            end
        end
    end
    
    return properties
end

function ThingClient:writeProperties(thing, properties)
    local count = 0
    for name, value in pairs(properties) do
        local property = thing.properties[name]
        if (property) then
            local actionName = '@write:' .. name;
            local handler = thing.handlers[actionName]
            if (handler) then
                handler(value)
            else
                property.value = value
            end

            count = count + 1
        end
    end

    return count
end

function ThingClient:processReadMessage(request, topic)
    local did = request and request.did;
    local thing = self.things[did]
    if (not thing) then
        console.log('Invalid thing id')
        return
    end

    local names = request.data and request.data.read;
    local properties = self:readProperties(thing, names)
    local response = {
        did = request.did,
        mid = request.mid,
        type = 'action',
        result = {
            read = properties
        }
    }

    --console.log('response', response, self.sendMessage)
    self:sendMessage(response)
end

function ThingClient:processWriteMessage(request, topic)
    local did = request and request.did;
    local thing = self.things[did]
    if (not thing) then
        console.log('Invalid thing id')
        return
    end

    local properties = request.data and request.data.write;
    local ret = self:writeProperties(thing, properties)
    local response = {
        did = request.did,
        mid = request.mid,
        type = 'action',
        result = {
            write = {
                code = 0,
                count = count
            }
        }
    }

    --console.log('response', response, self.sendMessage)
    self:sendMessage(response)
end

function ThingClient:processActionMessage(message, topic)
    local data = message.data
    if (not data) then
        return
    end

    for name, input in pairs(data) do
        if (name == 'read') then
            self:processReadMessage(message, topic)

        elseif (name == 'write') then
            self:processWriteMessage(message, topic)

        else 
            self:invokeAction(name, input, message)
        end
    end
end

function ThingClient:sendMessage(message)
    --console.log('sendMessage', message)
    local client = self.mqtt
    if (not client) then
        console.log('empty mqtt client')
        return
    end

    local topic = 'messages/' .. message.did

    local data = json.stringify(message)
    -- console.log(topic, data)
    client:publish(topic, data)
end

function ThingClient:sendRegister(did, thing)
    local description = thing:getDescription()

    local message = {
        did = did,
        type = 'register',
        data = description
    }

    if (thing.secret) then
        local signData = did .. ':' .. thing.secret
        message.sign = util.md5string(signData) .. ':md5';
    end

    -- console.log('register', did, message)
    self:sendMessage(message)
end

function ThingClient:sendEvent(events, thing)
    local message = {
        did = thing.id,
        token = thing.token,
        type = 'event',
        data = events
    }

    self:sendMessage(message)
end

function ThingClient:sendStream(streams, thing)
    local message = {
        did = thing.id,
        token = thing.token,
        type = 'stream',
        data = streams
    }

    console.log('stream', message)
    self:sendMessage(message)
end

function ThingClient:sendProperty(name, properties, request)
    if (name) then
        properties = {
            [name] = properties
        }
    end

    local message = {
        did = request.did,
        mid = request.mid,
        type = 'property',
        data = properties
    }

    --console.log('response', response, self.sendMessage)
    self:sendMessage(message)
end

function ThingClient:sendActionResult(name, output, request)
    if (not output) then
        output = { code = 0 }
    end

    local response = {
        did = request.did,
        mid = request.mid,
        type = 'action'
    }

    if (name) then
        response.result = { [name] = output }
    else
        response.result = output
    end

    console.log('response', response)
    self:sendMessage(response)
end

-- ------------------------------------------------------------
-- exports

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

-- Accepts an url argument of type USVString that represents a URL 
-- (e.g. "file://..." or "https://...") and returns a Promise that resolves
-- with a ThingDescription (a serialized JSON-LD document of type USVString).
-- @param url String
-- Promise<ThingDescription>
function exports.fetch(url)
    local promise = Promise.new()

    local td = { url = url }

    setTimeout(100, function()
        console.log('timeout')
        promise:resolve(td)
    end)

    return promise
end

-- Accepts an td argument of type ThingDescription and returns a 
-- ConsumedThing object instantiated based on parsing that description.
-- @param description ThingDescription
-- ConsumedThing
function exports.consume(description)
    return ConsumedThing:new(description);
end

-- Accepts a model argument of type ThingModel and returns an 
-- ExposedThing object
-- @param model ThingModel 
-- ExposedThing
function exports.produce(model)
    local thing = ExposedThing:new(model)

    return thing
end

-- Generate the Thing Description as td, given the Properties, Actions 
-- and Events defined for this ExposedThing object.
-- Then make a request to register td to the given WoT Thing Directory.
-- @param directory String
-- @param thing ExposedThing 
-- Promise<void>
function exports.register(directory, thing)
    if (not directory) then
        return nil, 'empty directory url'

    elseif (not thing) then
        return nil, 'empty thing'

    elseif (not thing.id) then
        return nil, 'empty thing.id'
    end

    local options = {}
    options.url = directory
    options.id = thing.id

    local client = exports.client
    if (not client) then
        client = ThingClient:new(options)
        exports.client = client

        client:on('register', function(result)
            local did = result.did
            local webThing = client.things[did]
            if (webThing) then
                webThing:emit('register', result)
            end
        end)

        client:start()
    end

    client.things[thing.id] = thing;
    return client
end

-- Makes a request to unregister the thing from the given WoT Thing Directory.
-- @param directory String
-- @param thing ExposedThing 
-- Promise<void>
function exports.unregister(directory, thing)
    local promise = Promise.new()

    local client = exports.client
    if (client) then
        client.things[thing.id] = nil;
    end

    return promise
end

return exports
