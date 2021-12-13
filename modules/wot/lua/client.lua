local json     = require('json')
local util     = require('util')
local core     = require('core')
local url      = require('url')

local Promise  = require('promise')
local mqtt     = require('wot/bindings/mqtt')

local exports = {}

---@class WotServer
---@field uri string
---@field mode string
---@field secret string
---@field lifetime integer
---@field minPeriod integer
---@field maxPeriod integer
---@field disable boolean
---@field timeout integer
---@field updated integer
---@field retryCount integer
---@field retryTimer integer
local WotServer = {}

exports.servers = {};

-- ------------------------------------------------------------
-- constants

local REGISTER_EXPIRES = 3600
local STATE_UNREGISTER = 0
local STATE_REGISTER   = 1
local REGISTER_MIN_INTERVAL = 4
local MAX_RETRY_COUNT = 10

---@class WotMessage
local WotMessage = {}

---@class ThingDescription
---@field url string
---@field id string
---@field clientId string
---@field actions table<string, table>
---@field events table<string, table>
---@field properties table<string, table>
local ThingDescription = {}

-- ------------------------------------------------------------
-- WotClient

---@class WotClient
local WotClient = core.Emitter:extend()

---@param options WotClientOptions
function WotClient:initialize(options)
    -- console.log('WotClient', options);
    if (not exports.did) then
        exports.did = util.randomString(6)
    end

    ---@class WotClientOptions
    ---@field directory string
    ---@field clientId string
    ---@field id string
    ---@field forms table
    self.isConnected = false
    self.mqtt = nil
    self.options = options or {}
    self.state = {}
    self.things = {}
    self.startTime = Date.now()
end

function WotClient:close(callback)
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

---@param message WotMessage
---@param topic string - MQTT topic name
function WotClient:processActionMessage(message, topic)
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
        self:processInvokeAction(name, input, message)
    end
end

function WotClient:processInvokeAction(name, input, request)
    -- console.log('processInvokeAction', name, input, request)
    -- console.log('processInvokeAction', name, input)

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

    if (exports.onInvokeAction) then
        exports.onInvokeAction(thing, name, input)
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
        --console.log('processInvokeAction.next', data)
        thingClient:sendResultMessage(name, data, request)

    end):catch(function(err)
        --console.log('processInvokeAction.err', err)
        thingClient:sendResultMessage(name, err, request)
    end)
end

---@param message WotMessage
---@param topic string - MQTT topic name
function WotClient:processMessage(message, topic)
    -- print(TAG, 'message', topic, message)

    local messageType = message.type
    if (not messageType) then
        return

    elseif (messageType == 'action') then
        self:processActionMessage(message)

    elseif (messageType == 'register') then
        self:emit('register', message)

        local thing = self.things[message.did]
        if (thing) then
            thing:_onRegisterResult(message)
        end
    end
end

---@param request WotMessage
---@param topic string - MQTT topic name
function WotClient:processReadAction(request, topic)
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

---@param request WotMessage
---@param topic string - MQTT topic name
function WotClient:processWriteAction(request, topic)
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

-- 发送 Action 消息
---@param actions table 要发送的 action
---@param options table 发送选项
-- - {string} did
---@param callback function 收到确认后调用
function WotClient:sendActionMessage(actions, options, callback)
    local messageId = (self.nextMessageId or 0) + 1
    self.nextMessageId = messageId;

    local message = {
        did = options.did,
        mid = tostring(messageId),
        type = 'action',
        data = actions
    }

    -- console.log('sendActionMessage', message)
    local ret, err = self:sendMessage(message, callback)
    if (err) then
        return ret, err
    end

    return messageId
end

-- 发送事件消息
---@param events table 要发送的事件
---@param options table 发送选项
-- - {string} did
---@param callback function 收到确认后调用
function WotClient:sendEventMessage(events, options, callback)
    local message = {
        did = options.did,
        type = 'event',
        data = events
    }

    return self:sendMessage(message, callback)
end

-- 发送消息
---@param message WotMessage 要发送的消息
---@param options table 发送选项
-- - {number} qos
---@param callback function 收到确认后调用
function WotClient:sendMessage(message, options, callback)
    --console.log('sendMessage', message)
    local mqttClient = self.mqtt -- MQTT client
    if (not mqttClient) then
        if (callback) then
            callback(nil, 'The MQTT client is empty')
        end

        return nil, 'The MQTT client is empty'
    end

    -- sendMessage(message, callback)
    if (type(options) == 'function') then
        callback = options
        options  = nil
    end

    local topic = 'messages/' .. message.did
    local data = json.stringify(message)

    -- console.log(topic, data)
    return mqttClient:publish(topic, data, options, callback)
end

-- 发送注册消息
---@param description ThingDescription 要发送的事物描述
---@param options table 发送选项
-- - {string} did
-- - {string} secret
function WotClient:sendRegisterMessage(description, options)
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

    -- console.log('sendRegisterMessage', message)
    return self:sendMessage(message)
end

function WotClient:sendResultMessage(name, output, request)
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
    return self:sendMessage(response)
end

-- 发送数据流
---@param data table 要发送的数据
---@param options table 发送选项
-- - {string} did
-- - {string} stream
---@param callback function 收到确认后调用
function WotClient:sendStreamMessage(data, options, callback)
    local message = {
        data = data,
        did = options and options.did,
        type = 'stream',
        stream = options and options.stream
    }

    options = options and options.options

    -- console.log('stream', message)
    return self:sendMessage(message, options, callback)
end

function WotClient:start()
    if (self.mqtt) then
        return nil, 'The client has already beed started'
    end

    local options = self.options
    if (not options) then
        return nil, 'client.options is null.'
    end

    console.error('wotc.connect')

    local forms = options.forms or {}
    local security = (forms and forms.security) or {}

    local clientId = forms.clientId or options.clientId
    if (not clientId) then
        clientId = 'lnode_' .. (options.id or exports.did or '')
    end

    local mqttOptions = {
        clientId = clientId,
        username = security.username,
        password = security.password,
        servers = options.servers
    }

    -- console.log('start', mqttOptions)
    local mqttClient = mqtt.connect(mqttOptions)

    mqttClient:on('connect', function ()
        self:emit('connect')
        self.state.lastConnectedTime = Date.now()

        self:_onConnected()
    end)

    mqttClient:on('message', function (topic, data)
        -- print(TAG, 'message', topic, data)
        local message = json.parse(data)
        if (message) then
            self:processMessage(message, topic)
        end
    end)

    mqttClient:on('offline', function ()
        if (self.isConnected) then
            self.isConnected = false
            self:emit('offline')
        end
    end)

    mqttClient:on('reconnect', function ()
        self:emit('reconnect')

        setImmediate(function()
            self:_onReconnect()
        end)
    end)

    self.mqtt = mqttClient
    return self
end

---@param thing ExposedThing
function WotClient:subscribe(thing, callback)
    local client = thing.client
    local mqttClient = client and client.mqtt
    if (not mqttClient) then
        return nil, 'The MQTT client is empty'
    end

    local topic = 'actions/' .. thing.id
    local ret, err = mqttClient:subscribe(topic, function(err)
        console.log('wot.subscribed', topic, err)
        thing.isSubscribed = true
    end)

    return ret, err
end

function WotClient:_onConnected()
    local mqttClient = self.mqtt

    -- console.log('wotc.connected', exports.did)

    for did, thing in pairs(self.things) do
        if (thing.register) then
            self:subscribe(thing)

            thing:_onRegisterTimer()
        end
    end

    if (not self.isConnected) then
        self.isConnected = true
        self:emit('online')
    end
end

-- 当 MQTT 发生重连
function WotClient:_onReconnect()

end

-- Generate the Thing Description as td, given the Properties, Actions 
-- and Events defined for this ExposedThing object.
-- Then make a request to register td to the given WoT Thing Directory.
---@param directory string
---@param thing ExposedThing
---@return Promise<void>
function exports.register(directory, thing)
    if (not thing) then
        return nil, 'empty thing'

    elseif (not thing.id) then
        return nil, 'empty thing.id'
    end

    local options = {}
    options.directory = directory
    options.id = thing.id

    -- console.log('register', options)

    local client = exports.getClient(options)
    if (client) then
        thing.client = client;

        -- console.log('options', thing, client)
        client.things[thing.id] = thing;

        if (exports.onThingRegister) then
            exports.onThingRegister(thing)
        end
    end
    return client
end

-- Makes a request to unregister the thing from the given WoT Thing Directory.
---@param directory string
---@param thing ExposedThing
---@return Promise<void>
function exports.unregister(directory, thing)
    local promise = Promise.new()

    local client = exports.client
    if (client) then
        client.things[thing.id] = nil;
    end

    promise:resolve(true)
    return promise
end

---@param options WotClientOptions
---@param flags boolean
---@return WotClient
function exports.getClient(options, flags)
    local client = exports.client
    if (client) then
        return client
    end

    if (not flags) then
        return nil
    end

    local forms = options and options.forms
    local servers = forms and forms.servers
    if (not servers) then
        return nil, 'Invalid servers option'
    end

    options.servers = {}
    for index, server in ipairs(servers) do
        table.insert(options.servers, url.parse(server))
    end

    client = WotClient:new(options)
    exports.client = client

    local ret, err = client:start()
    return client, err
end

exports.WotClient = WotClient

return exports
