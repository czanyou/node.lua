local json     = require('json')
local util     = require('util')
local core     = require('core')

local Promise  = require('wot/promise')
local mqtt     = require('wot/bindings/mqtt')

local exports = {}

-- ------------------------------------------------------------
-- constants

local REGISTER_EXPIRES = 3600
local STATE_UNREGISTER = 0
local STATE_REGISTER   = 1
local REGISTER_MIN_INTERVAL = 4

-- ------------------------------------------------------------
-- ThingClient

local ThingClient = core.Emitter:extend()

-- ------------------------------------------------------------
-- ThingDiscover

local ThingDiscover = core.Emitter:extend()

function ThingDiscover:initialize(filter)
    self.filter = filter
    self.active = false
    self.done = false
    self.error = nil
end

function ThingDiscover:start()

end

function ThingDiscover:stop()

end

function ThingDiscover:next()

end

-- ------------------------------------------------------------
-- ConsumedThing

local ConsumedThing  = core.Emitter:extend()

function ConsumedThing:initialize(thingInstance)
    if (type(thingInstance) == 'string') then
        thingInstance = json.parse(thingInstance)
    end

    self.handlers = {}
    self.instance = thingInstance or {}
    self.id = thingInstance.id
    self.client = exports.client
    self.consumed = true

    if (self.client) then
        self.client.things['@' .. self.id] = self;
    end
end

function ConsumedThing:readProperty(name)
    
end

function ConsumedThing:readMultipleProperties(names)
    
end

function ConsumedThing:readAllProperties()
    
end

function ConsumedThing:writeProperty(name, value)
    
end

function ConsumedThing:writeMultipleProperties(values)
    
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

function ConsumedThing:subscribeProperty(name, listener)
    
end

function ConsumedThing:unsubscribeProperty(name)
    
end

function ConsumedThing:subscribeEvent(name, listener)
    
end

function ConsumedThing:unsubscribeEvent(name)
    
end

-- ------------------------------------------------------------
-- ExposedThing

local ExposedThing  = core.Emitter:extend()

function ExposedThing:initialize(thingInstance)
    if (type(thingInstance) == 'string') then
        thingInstance = json.parse(thingInstance)
    end
    -- console.log(thingInstance)
    self.client = nil -- MQTT thing client
    self.handlers = {} -- Action handlers
    self.id = thingInstance.id -- Thing ID / DID
    self.instance = thingInstance or {} -- Thing instance
    self.exposed = true

    if (thingInstance.clientId) then
        self.clientId = thingInstance.clientId
        thingInstance.clientId = nil
    end

    -- register state
    self.register = {}
    self.register.expires = REGISTER_EXPIRES -- Register expires
    self.register.interval = REGISTER_MIN_INTERVAL -- Register retry interval
    self.register.state = STATE_UNREGISTER -- Register state
    self.register.time = 0    -- The last register send time
    self.register.updated = 0 -- Register updated time
    self.registerTimer = nil -- The register timer
end

function ExposedThing:_setHandler(type, name, handler)
    if (not name) then
        return
    end

    self.handlers[type .. name] = handler
    return self
end

function ExposedThing:_onRegister()
    local client = self.client
    if (not client) then
        return
    end


    local now = Date.now()

    local description = self.instance
    local options = { did = self.id, secret = self.sceret }

    if (not self.register.state) then
        -- init
        self.register.state = STATE_UNREGISTER
        self.register.time = now
        client:sendRegisterMessage(description, options, 1)

    elseif (self.register.state == STATE_REGISTER) then
        -- register
        local span = (now - (self.register.updated or 0)) / 1000
        local expires = self.register.expires or REGISTER_EXPIRES

        if (span >= expires) or (span <= -expires) then
            console.log('span', span, expires)
            self.register.time = now
            client:sendRegisterMessage(description, options, 2)
        end

    else
        -- unregister
        local span = math.abs(now - (self.registerTime or 0)) / 1000
        local registerInterval = self.register.interval or 2
        
        if (span >= registerInterval) then
            -- console.log('span', span, registerInterval,self.registerTime)
            self.register.interval = math.min(REGISTER_EXPIRES, 2 * registerInterval)
            self.register.time = now
            client:sendRegisterMessage(description, options, 3)
        end
    end
end

function ExposedThing:_onRegisterResult(response)
    if (not response) then
        return
    end

    local result = response.result
    if (result and result.code and result.error) then
        self.register.state = STATE_UNREGISTER

    else
        local data = result.data or {}

        self.register.state = STATE_REGISTER
        self.register.interval = REGISTER_MIN_INTERVAL
        self.register.token = data.token
        self.register.id = data.id
        self.register.expires = data.expires or REGISTER_EXPIRES
        self.register.updated = Date.now()
    end

    self:emit('register', response)
end

function ExposedThing:setPropertyReadHandler(name, handler)
    return self:_setHandler('@read:', name, handler)
end

function ExposedThing:setPropertyWriteHandler(name, handler)
    return self:_setHandler('@write:', name, handler)
end

function ExposedThing:setActionHandler(name, handler)
    return self:_setHandler('@action:', name, handler)
end

function ExposedThing:emitEvent(name, data)
    local client = self.client;
    if (not client) then
        return
    end

    local events = {}
    events[name] = data;

    local options = { did = self.id }
    client:sendEventMessage(events, options)
end

function ExposedThing:sendStream(values, options, callback)
    local client = self.client;
    if (not client) or (not values) then
        if (callback) then
            setImmediate(callback)
        end
        return
    end

    if (not options) then
        options = {}
    end

    options.did = self.id
    client:sendStreamMessage(values, options, callback)
end

function ExposedThing:readProperty(name)
    local handler = self.handlers['@read:' .. name]
    if (handler) then
        return handler()
    end

    local instance = self.instance
    local property = instance.properties[name]
    if (property) then
        return property.value
    end
end

function ExposedThing:readAllProperties()
    local names = {}
    local instance = self.instance
    
    for name, property in pairs(instance.properties) do
        names[#names + 1] = name
    end
  
    local properties = {}
    for index, name in ipairs(names) do
        properties[name] = self:readProperty(name)
    end
    
    return properties
end

function ExposedThing:readMultipleProperties(names)
    local instance = self.instance
    if (not names) or (not (#names > 0)) then
        names = {}
        for name, property in pairs(instance.properties) do
            names[#names + 1] = name
        end
    end

    local properties = {}
    for index, name in ipairs(names) do
        properties[name] = self:readProperty(name)
    end
    
    return properties
end

function ExposedThing:writeProperty(name, value)
    local instance = self.instance
    local property = instance.properties[name]
    if (property) then
        property.value = value

        local handler = self.handlers['@write:' .. name]
        if (handler) then
            handler(value)
        end
    end
end

function ExposedThing:writeMultipleProperties(values)
    if (type(values) ~= 'table') then
        return 0
    end

    local count = 0
    for name, value in pairs(values) do
        self:writeProperty(name, value)
        count = count + 1
    end

    return count
end

function ExposedThing:invokeAction(name, params)
    local handler = self.handlers['@action:' .. name]
    if (not handler) then
        console.log('Action handler not found: ', name)
        return { code = 404, error = 'Unsupported action' }
    end

    return handler(params)
end

-- Start serving external requests for the Thing, so that WoT interactions
-- using Properties, Actions and Events will be possible.
function ExposedThing:expose()
    local promise = Promise.new()

    -- console.log(self.instance)

    local mqtt = self.instance.url
    if (mqtt) then
        ThingClient.register(mqtt, self)
    end

    setImmediate(function()
        promise:resolve()
    end)

    return promise
end

-- Stop serving external requests for the Thing and destroy the object. 
-- Note that eventual unregistering should be done before invoking this 
-- method.
function ExposedThing:destroy()
    local promise = Promise.new()

    local mqtt = self.instance.url
    ThingClient.unregister(mqtt, self)
    
    if (self.registerTimer) then
        clearInterval(self.registerTimer)
        self.registerTimer = nil;
    end

    self.instance = nil
    self.client = nil
    
    self.register.token = nil
    self.register.expires = REGISTER_EXPIRES
    self.register.interval = REGISTER_MIN_INTERVAL
    self.register.state = STATE_UNREGISTER
    self.register.time = 0
    self.register.updated = 0
    self.registerTimer = nil

    setImmediate(function()
        promise:resolve()
    end)

    return promise
end

-- ------------------------------------------------------------
-- ThingClient

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

    local clientId = self.options.clientId
    if (not clientId) then
        clientId = 'lnode_' .. (exports.did or self.options.id or '')
    end

    local options = {
        clientId = clientId
    }

    console.log('start', urlString, options)
    local mqttClient = mqtt.connect(urlString, options)

    mqttClient:on('connect', function ()
        console.log('connect')
        for did, thing in pairs(self.things) do
            if (thing.register) then
                local topic = 'actions/' .. did
                mqttClient:subscribe(topic)
                console.log('subscribe', topic)
                thing.isSubscribed = true
                thing:_onRegister()
            end
        end
    end)

    mqttClient:on('message', function (topic, data)
        -- print(TAG, 'message', topic, data)
        local message = json.parse(data)
        if (message) then
            self:processMessage(message, topic)
        end
    end)

    self.mqtt = mqttClient
end

function ThingClient:close(callback)
    local mqttClient = self.mqtt

    for did, thing in pairs(self.things) do
        if (thing.register) then
            thing.isSubscribed = false
            thing.register.interval = REGISTER_MIN_INTERVAL
            thing.register.state = STATE_UNREGISTER
        end
    end

    if (mqttClient) then
        mqttClient:close(callback)

    elseif (callback) then
        callback()
    end

    self.mqtt = nil
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
            thing.register = {}
            thing.register.id = data.id
            thing.register.token = data.token
            thing.register.expires = data.expires
            thing.register.updated = process.now()
            -- console.log('thing', thing);
        end
    end
end

function ThingClient:processActionMessage(message, topic)
    if (not message) or (not message.did) then
        return
    end

    local result = message.result
    if (result) then
        local thing = self.things['@' .. message.did]
        if (thing) then
            -- console.log(message)
            thing:emit('result', message)
        end
        return
    end

    local data = message.data
    if (not data) then
        return
    end

    for name, input in pairs(data) do
        if (name == 'read') then
            self:processReadAction(message, topic)

        elseif (name == 'write') then
            self:processWriteAction(message, topic)

        else
            self:processInvokeAction(name, input, message)
        end
    end
end

function ThingClient:processReadAction(request, topic)
    local did = request and request.did;
    local thing = self.things[did]
    if (not thing) then
        console.log('Invalid thing id')
        return
    end

    local names = request.data and request.data.read;
    local properties = thing:readMultipleProperties(names)
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

function ThingClient:processWriteAction(request, topic)
    local did = request and request.did;
    local thing = self.things[did]
    if (not thing) then
        console.log('Invalid thing id')
        return
    end

    local properties = request.data and request.data.write;
    local count = thing:writeMultipleProperties(properties)
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

function ThingClient:processInvokeAction(name, input, request)
    -- console.log('processInvokeAction', name, input, request)
    console.log('processInvokeAction', name, input)

    -- check name
    if (not name) then
        local err = { code = 400, error = 'Invalid action name' }
        return self:sendResultMessage(nil, err, request)
    end

    -- console.log('processInvokeAction', name, input, request, self.things)
    -- check did
    local did = request.did;
    local thing = self.things[did]
    if (not thing) then
        console.log('Invalid thing id')
        local err = { code = 404, error = 'Invalid thing id' }
        return self:sendResultMessage(name, err, request)
    end

    -- check handler
    local ret = thing:invokeAction(name, input)
    if (not ret) then
        ret = { code = 0, message = 'result is empty' }
        return self:sendResultMessage(name, ret, request)

    elseif (not ret.next) then
        return self:sendResultMessage(name, ret, request)
    end

    -- next
    local thingClient = self
    ret:next(function(data)
        thingClient:sendResultMessage(name, data, request)

    end):catch(function(err)
        thingClient:sendResultMessage(name, err, request)
    end)
end

-- 发送消息
-- @param {object} message 要发送的消息
-- @param {object} options 发送选项
-- - {number} qos
-- @param {function} callback 收到确认后调用
function ThingClient:sendMessage(message, options, callback)
    --console.log('sendMessage', message)
    local client = self.mqtt -- MQTT client
    if (not client) then
        if (callback) then
            callback(nil, 'empty mqtt client')
        end
        return
    end

    -- sendMessage(message, callback)
    if (type(options) == 'function') then
        callback = options
        options  = nil
    end

    local topic = 'messages/' .. message.did
    local data = json.stringify(message)

    -- console.log(topic, data)
    client:publish(topic, data, options, callback)
end

-- 发送注册消息
-- @param {object} description 要发送的事物描述
-- @param {object} options 发送选项
-- - {string} did
-- - {string} secret
-- @param {function} callback 收到确认后调用
function ThingClient:sendRegisterMessage(description, options)
    local data = {}
    if (description.register) then
        for key, value in pairs(description.register) do
            data[key] = value
        end
    end

    data.version = description.version

    local message = {
        did = options.did,
        type = 'register',
        data = data
    }

    if (options.secret) then
        local signData = options.did .. ':' .. options.secret
        message.sign = util.md5string(signData) .. ':md5';
    end

    self:sendMessage(message)
end

-- 发送事件消息
-- @param {object} events 要发送的事件
-- @param {object} options 发送选项
-- - {string} did
-- @param {function} callback 收到确认后调用
function ThingClient:sendEventMessage(events, options, callback)
    local message = {
        did = options.did,
        type = 'event',
        data = events
    }

    self:sendMessage(message, callback)
end

-- 发送 Action 消息
-- @param {object} actions 要发送的 action
-- @param {object} options 发送选项
-- - {string} did
-- @param {function} callback 收到确认后调用
function ThingClient:sendActionMessage(actions, options, callback)
    local messageId = (self.nextMessageId or 0) + 1
    self.nextMessageId = messageId;

    local message = {
        did = options.did,
        mid = tostring(messageId),
        type = 'action',
        data = actions
    }

    -- console.log('sendActionMessage', message)
    self:sendMessage(message, callback)
    return messageId
end

-- 发送数据流
-- @param {object} data 要发送的数据
-- @param {object} options 发送选项
-- - {string} did
-- - {string} stream
-- @param {function} callback 收到确认后调用
function ThingClient:sendStreamMessage(data, options, callback)
    local message = {
        did = options.did,
        type = 'stream',
        data = data,
        stream = options.stream
    }

    -- console.log('stream', message)
    self:sendMessage(message, callback)
end

function ThingClient:sendResultMessage(name, output, request)
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

    -- console.log('response', response)
    self:sendMessage(response)
end

-- Generate the Thing Description as td, given the Properties, Actions 
-- and Events defined for this ExposedThing object.
-- Then make a request to register td to the given WoT Thing Directory.
-- @param directory String
-- @param thing ExposedThing 
-- Promise<void>
function ThingClient.register(directory, thing)
    if (not directory) then
        return nil, 'empty directory url'

    elseif (not thing) then
        return nil, 'empty thing'

    elseif (not thing.id) then
        return nil, 'empty thing.id'
    end

    -- console.log(thing)
    local options = {}
    options.url = directory
    options.id = thing.id
    options.clientId = thing.clientId

    local client = ThingClient.getClient(options, true)
    thing.client = client;

    local onRegister = function()
        if (not thing.isSubscribed) then
            local topic = 'actions/' .. options.id
            local mqttClient = client.mqtt
            if (mqttClient) then
                mqttClient:subscribe(topic)
                console.log('subscribe', topic)
                thing.isSubscribed = true
            end
        end

        -- console.log("subscirbe ", topic)
        thing:_onRegister()
    end

    if (not thing.registerTimer) then
        thing.registerTimer = setInterval(1000 * 5, onRegister)
    end

    client.things[thing.id] = thing;
    return client
end

-- Makes a request to unregister the thing from the given WoT Thing Directory.
-- @param directory String
-- @param thing ExposedThing 
-- Promise<void>
function ThingClient.unregister(directory, thing)
    local promise = Promise.new()

    local client = exports.client
    if (client) then
        client.things[thing.id] = nil;
    end

    return promise
end

function ThingClient.getClient(options, flags)
    local client = exports.client
    if (client) then
        return client
    end

    if (not flags) then
        return nil
    end

    client = ThingClient:new(options)
    exports.client = client

    client:on('register', function(result)
        local did = result and result.did
        local webThing = client.things[did]
        if (webThing) then
            webThing:_onRegisterResult(result)
        end
    end)

    client:start()
    return client
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

-- Accepts an td argument of type ThingDescription and returns a 
-- ConsumedThing object instantiated based on parsing that description.
-- @param {string|object} thingDescription ThingDescription
-- @returns {ConsumedThing}
function exports.consume(thingDescription)
    return ConsumedThing:new(thingDescription);
end

-- Accepts a model argument of type ThingModel and returns an 
-- ExposedThing object
-- @param {string|object} model ThingModel 
-- @returns {ExposedThing}
function exports.produce(thingDescription)
    return ExposedThing:new(thingDescription)
end

function exports.isConnected()
    local client = exports.client;
    local mqttClient = client and client.mqtt
    return mqttClient and mqttClient.connected;
end

return exports
