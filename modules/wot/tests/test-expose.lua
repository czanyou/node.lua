local expose = require('wot/expose')
local wot = require('wot')
local util = require('util')
local assert = require('assert')
local Promise = require('promise')

local tap = require('util/tap')

describe('test expose - produce 1', function()
    local description = {
        id = 'test',
        url = 'mqtt://iot.wotcloud.cn/',
        properties = { test = {}, a = {}, b = {}, c = {} },
        actions = { test = {} }
    }

    local properties = {}

    description['@read'] = function(names)
        local result = {}
        for _, name in ipairs(names) do
            result[name] = properties[name]
        end
        return result
    end

    description['@write'] = function(values)
        for name, value in pairs(values) do
            properties[name] = value
        end
    end

    local thing = expose.produce(description)

    console.log('writeProperty')
    thing:writeProperty('test', 'data')

    console.log('readProperty')
    local value = thing:readProperty('test')
    console.log('readProperty', value)

    thing:writeMultipleProperties({ test = 'data2', a = 1, b = 2, c = 3 })

    local values = thing:readAllProperties()
    console.log('readAllProperties', values)

    values = thing:readMultipleProperties({'test', 'a', 'b', 'c'})
    console.log('readMultipleProperties', values)

end)

describe('test expose - produce 2', function()

    ---@type WotClientForms
    local forms = {
        directory = 'mqtt://iot.wotcloud.cn/'
    }

    ---@type WotClient
    wot.getClient(forms, true)

    ---@type ThingDescription
    local description = {
        id = 'test',
        url = 'mqtt://iot.wotcloud.cn/',
        properties = { test = {} },
        actions = { test = {} }
    }

    ---@type ExposedThing
    local thing = expose.produce(description)

    thing:setActionHandler('test', function(input)
        local promise = Promise.new()
        promise:resolve(input .. ':result')
        return promise
    end)

    thing:on('state', function(state)
        console.log(state)
    end)

    thing:on('register', function(result)
        console.log(result, thing.register)
    end)

    local function onClose()
        if (not thing) then
            return
        end

        local client = thing.client
        thing:destroy()
        -- console.log(thing)
        client:close()

        thing = nil
    end

    thing:expose():next(function()
        console.log('next')
        local client = thing.client
        tap.assert(client)

        client:on('connect', function(result)
            console.log('connect', result)
        end)

        -- writeProperty
        console.log('writeProperty')
        thing:writeProperty('test', 'data')

        thing:writeMultipleProperties({ test = 'data2' })

        -- readProperty
        console.log('readProperty')
        local value = thing:readProperty('test')
        console.log('readProperty', value)

        local values = thing:readAllProperties()
        console.log('readAllProperties', values)

        values = thing:readMultipleProperties({'test'})
        console.log('readMultipleProperties', values)

        -- invokeAction
        local ret = thing:invokeAction('test', 'data')
        ret:next(function(result)
            console.log('invokeAction', result)
            assert.equal(result, 'data:result')
        end)

        -- emitEvent
        local _, err = thing:emitEvent('test', 'data')
        console.log('emitEvent', err)

        -- sendStream
        _, err = thing:sendStream('test', {})
        console.log('sendStream', err)

    end):catch(function(error)
        console.log('error', error)
    end)

    setTimeout(2000, function()
        onClose()
    end)
end)
