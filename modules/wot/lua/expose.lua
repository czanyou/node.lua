local json     = require('json')
local core     = require('core')
local Promise  = require('promise')

local wotclient = require('wot/client')

---@class expose
local exports = {}

-- ------------------------------------------------------------
-- constants

local REGISTER_EXPIRES = 3600
local STATE_UNREGISTER = 0
local STATE_REGISTER   = 1
local REGISTER_MIN_INTERVAL = 4

-- ------------------------------------------------------------
-- ExposedThing

---@class ExposedThing
local ExposedThing  = core.Emitter:extend()

---@param thingInstance ThingDescription
function ExposedThing:initialize(thingInstance)
    if (type(thingInstance) == 'string') then
        thingInstance = json.parse(thingInstance)
    end

    -- console.log(thingInstance)
    self.client = nil -- MQTT thing client
    self.exposed = true
    self.handlers = {} -- Action handlers
    self.id = thingInstance.did or thingInstance.id -- Thing ID / DID
    self.instance = thingInstance or {} -- Thing instance
    self.isSubscribed = nil
    self.register = {}
    self.registerTimer = nil -- The register timer
    self.secret = nil

    self.streamCurrent = nil
    self.streamQueue = {}
    self.streamQueueLimit = 1000

    if (thingInstance.clientId) then
        self.clientId = thingInstance.clientId
        thingInstance.clientId = nil
    end

    -- register state
    local register = self.register
    register.error = nil
    register.expires = REGISTER_EXPIRES -- Register expires
    register.interval = REGISTER_MIN_INTERVAL -- Register retry interval
    register.lastSentTime = 0    -- The last register send time
    register.state = STATE_UNREGISTER -- Register state
    register.tryTimes = 0
    register.updated = 0 -- Register updated time
end

-- Stop serving external requests for the Thing and destroy the object.
-- Note that eventual unregistering should be done before invoking this
-- method.
function ExposedThing:destroy()
    local promise = Promise.new()

    local forms = self.instance.forms or {}
    local mqttUrl = forms and forms.href
    wotclient.unregister(mqttUrl, self)

    if (self.registerTimer) then
        clearInterval(self.registerTimer)
        self.registerTimer = nil;
    end

    self.client = nil
    self.handlers = nil
    self.instance = nil
    self.isSubscribed = nil

    self.register.error = nil
    self.register.expires = REGISTER_EXPIRES
    self.register.interval = REGISTER_MIN_INTERVAL
    self.register.lastSentTime = 0
    self.register.token = nil
    self.register.tryTimes = 0
    self.register.updated = 0

    self:_setRegisterState(STATE_UNREGISTER)

    setImmediate(function()
        promise:resolve(true)
    end)

    return promise
end

---@param name string
---@param data table
function ExposedThing:emitEvent(name, data)
    if (not name) or (not data) then
        return nil, 'Invalid event name or data'
    end

    if (not self:isRegistered()) then
        return nil, 'The thing is not register'
    end

    local client = self.client;
    if (not client) then
        return nil, 'The client is empty'
    end

    local events = {}
    events[name] = data;

    local options = { did = self.id }

    if (wotclient.onEmitEvent) then
        wotclient.onEmitEvent(self, events)
    end

    return client:sendEventMessage(events, options)
end

-- Start serving external requests for the Thing, so that WoT interactions
-- using Properties, Actions and Events will be possible.
---@return Promise
function ExposedThing:expose()
    local promise = Promise.new()
    -- console.log(self.instance)
    local forms = self.instance.forms or {}
    local mqttUrl = forms.href or self.instance.url

    if (self.registerTimer) then
        -- TODO: update
        promise:resolve(true)
        return promise
    end

    local _, err = wotclient.register(mqttUrl, self)
    if (err) then
        promise:reject(err)
        return promise
    end

    local onRegisterTimer = function()
        local client = self.client
        local isConnected = client and client.isConnected

        if (isConnected and not self.isSubscribed) then
            console.log('wotc.registerTimer', self.id)

            if client then
                client:subscribe(self)
            end
        end

        -- console.log("subscirbe ", topic)
        self:_onRegisterTimer()
    end

    if (not self.registerTimer) then
        self.registerTimer = setInterval(1000 * 5, onRegisterTimer)
    end

    setImmediate(function()
        promise:resolve(true)
    end)

    return promise
end

function ExposedThing:invokeAction(name, params)
    local actions = self.instance.actions
    local action = actions and actions[name]
    if (action) then
        action.input = params
    end

    local handler = self.handlers['@action.' .. name]
    if (not handler) then
        console.log('Action handler not found: ', name)
        return { code = 404, error = 'Unsupported action' }
    end

    return handler(params)
end

---@return boolean
function ExposedThing:isRegistered()
    local register = self.register
    local state = register and register.state
    return state == STATE_REGISTER
end

function ExposedThing:readAllProperties()
    local instance = self.instance
    local properties = instance and instance.properties

    if (not properties) then
        return
    end

    local names = {}
    for name, _ in pairs(properties) do
        table.insert(names, name)
    end
    return self:readMultipleProperties(names)
end

---@param names table
function ExposedThing:readMultipleProperties(names)
    if (names == nil) then
        return
    end

    if (type(names) ~= 'table') then
        names = { tostring(names) }
    end

    local instance = self.instance
    local readAction = instance and instance['@read']
    if (type(readAction) == 'function') then
        return readAction(names)
    end

    local result = {}
    for _, name in ipairs(names) do
        result[name] = self:readProperty(name)
    end

    return result
end

---@param name string
function ExposedThing:readProperty(name)
    local handler = self.handlers['@read.' .. name]
    if (handler) then
        return handler()
    end

    local instance = self.instance
    local readAction = instance and instance['@read']
    if (type(readAction) == 'function') then
        return readAction({ name })
    end

    local properties = instance and instance.properties
    local property = properties and properties[name]
    if (property) then
        return property.value
    end
end

-- 发送数据流
---@param values table
---@param options table
---@param callback function
function ExposedThing:sendStream(values, options, callback)
    if (not values) then
        if (callback) then
            setImmediate(callback)
        end
        return nil, 'Invalid stream values'
    end

    if (type(options) == 'function') then
        options, callback = options, nil
    end

    local client = self.client;
    if (not client) then
        if (callback) then
            setImmediate(callback)
        end
        return nil, 'The client is empty'
    end

    if (not options) then
        options = {}

    elseif (type(options) ~= 'table') then
        options = { stream = options }
    end

    options.did = self.id

    local message = {
        values = values,
        options = options,
        callback = callback
    }

    if (wotclient.onSendStream) then
        wotclient.onSendStream(self, message)
    end

    -- 未注册
    if (not self:isRegistered()) then
        if (callback) then
            setImmediate(callback)
        end
        return nil, 'The thing is not register'
    end

    message.created = process.now()
    table.insert(self.streamQueue, message)

    setImmediate(function()
        self:_onSendStream()
    end)
end

---@param name string
---@param handler fun(input:any)
---@return ExposedThing
function ExposedThing:setActionHandler(name, handler)
    if (not self.instance.actions) then
        self.instance.actions = {}
    end

    if (not self.instance.actions[name]) then
        self.instance.actions[name] = {}
    end

    return self:_setHandler('@action.', name, handler)
end

---@param name string
---@param handler fun(name:string):any
---@return ExposedThing
function ExposedThing:setPropertyReadHandler(name, handler)
    return self:_setHandler('@read.', name, handler)
end

---@param name string
---@param handler fun(name:string, value:any)
---@return ExposedThing
function ExposedThing:setPropertyWriteHandler(name, handler)
    return self:_setHandler('@write.', name, handler)
end

---@param values table<string,any>
function ExposedThing:writeMultipleProperties(values)
    if (type(values) ~= 'table') then
        return 0
    end

    local instance = self.instance
    local writeAction = instance and instance['@write']
    if (type(writeAction) == 'function') then
        return writeAction(values)
    end

    local count = 0
    for name, value in pairs(values) do
        self:writeProperty(name, value)
        count = count + 1
    end

    return count
end

---@param name string
---@param value any
function ExposedThing:writeProperty(name, value)
    local instance = self.instance
    local properties = instance and instance.properties
    local property = properties and properties[name]
    if (not property) then
        return
    end

    property.value = value

    local handler = self.handlers['@write.' .. name]
    if (handler) then
        handler(value)
    end

    local writeAction = instance and instance['@write']
    if (type(writeAction) == 'function') then
        return writeAction({ [name] = value })
    end
end

-- Update register
function ExposedThing:update()
    --TODO:
end

function ExposedThing:_onCleanStream()
    local queue = self.streamQueue
    while (#queue > 0) do
        local message = table.remove(queue, 1)
        if (message.callback) then
            message.callback()
        end
    end
end

function ExposedThing:_onRegisterTimer()
    local client = self.client
    if (not client) then
        return
    end

    self:_onSendStream();

    local now = Date.now()

    local description = self.instance
    local options = { did = self.id, secret = self.secret }

    if (not self.register.state) then
        -- init register
        self:_setRegisterState(STATE_UNREGISTER)

        self.register.lastSentTime = now
        self.register.tryTimes = (self.register.tryTimes or 0) + 1
        client:sendRegisterMessage(description, options, 1)

    elseif (self.register.state == STATE_REGISTER) then
        -- update register
        local span = (now - (self.register.updated or 0)) / 1000
        local expires = self.register.expires or REGISTER_EXPIRES

        if (span >= expires) or (span <= -expires) then
            console.log('span', span, expires)
            self.register.lastSentTime = now
            self.register.tryTimes = (self.register.tryTimes or 0) + 1
            client:sendRegisterMessage(description, options, 2)
        end

    else
        -- unregister
        local span = math.abs(now - (self.register.lastSentTime or 0)) / 1000
        local registerInterval = self.register.interval or 2

        if (span >= registerInterval) then
            -- console.log('span', span, registerInterval, self.register.lastSentTime)

            self.register.interval = math.min(REGISTER_EXPIRES, 2 * registerInterval)
            self.register.lastSentTime = now
            self.register.tryTimes = (self.register.tryTimes or 0) + 1
            client:sendRegisterMessage(description, options, 3)
        end
    end
end

function ExposedThing:_onRegisterResult(response)
    if (not response) then
        return
    end

    local result = response.result
    if (not result) then
        return
    end

    local register = self.register
    if (result.code and result.error) then
        register.error = result

        self:_setRegisterState(STATE_UNREGISTER)

    else
        -- data
        local data = result.data or {}
        register.token = data.token
        register.id = data.id
        register.tryTimes = 0
        register.error = nil
        register.interval = REGISTER_MIN_INTERVAL
        register.updated = Date.now()
        register.expires = data.expires or REGISTER_EXPIRES

        self:_setRegisterState(STATE_REGISTER)
    end

    self:emit('register', result)
end

function ExposedThing:_onSendStream()
    local client = self.client;
    if (not client) or (not client.isConnected) then
        return
    end

    local queue = self.streamQueue
    -- console.log('queue', #queue, queue.sendCount)

    if (#queue < 1) then
        return

    elseif (#queue > self.streamQueueLimit) then
        self:_onCleanStream()
    end

    local message = table.remove(queue, 1)
    -- console.log('message', message)

    return client:sendStreamMessage(message.values, message.options, function()
        queue.sendCount = (queue.sendCount or 0) + 1

        if (message.callback) then
            message.callback()
        end

        setImmediate(function()
            self:_onSendStream()
        end)
    end)
end

function ExposedThing:_setHandler(type, name, handler)
    if (not name) then
        return
    end

    self.handlers[type .. name] = handler
    return self
end

function ExposedThing:_setRegisterState(state)
    local register = self.register
    if (register.state ~= state) then
        register.state = state
        self:emit('state', state)

        if (wotclient.onRegisterStateChange) then
            wotclient.onRegisterStateChange(self, state)
        end
    end
end

exports.ExposedThing = ExposedThing

---@return ExposedThing
function exports.produce(thingDescription)
    return ExposedThing:new(thingDescription)
end

return exports
