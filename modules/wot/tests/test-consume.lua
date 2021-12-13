local wot = require('wot')
local tap = require('util/tap')

local description = [[{
    "id": "urn:com.cz.wot",
    "name": "Test",
    "base": "http://www.test.com/things/test",
    "support": "http://www.test.com/support",
    "@context": "http://www.test.com/context",
    "@type": "Test",
    "description": "Test Thing",
    "properties": {
        "on": {
            "label": "On/Off",
            "type": "boolean",
            "forms": [{
                "href" : "/properties/on",
                "mediaType": "application/json",
                "http:methodName": "GET",
                "rel": "readProperty"
            }]
        },
        "status": {
            "type": "object",
            "required": ["brightness", "rgb"],
            "properties": {
                "brightness": {
                    "type": "number",
                    "minimum": 0.0,
                    "maximum": 100.0
                 },
                 "rgb": {
                    "type": "array",
                    "items" : {
                        "type" : "number",
                        "minimum": 0,
                        "maximum": 255
                    },
                    "minItems": 3,
                    "maxItems": 3
                }
            },
            "forms": [{
                "href" : "/properties/status",
                "mediaType": "application/json",
                "http:methodName": "GET",
                "rel": "readProperty"
            }]
        }
    }, 
    "actions": {
        "fade": {
            "label": "Fade in/out",
            "description": "Smooth fade in and out animation.",
            "input": {
                "type": "ojbect",
                "required": ["to", "duration"],
                "properties": {
                    "from": {
                        "type": "integer",
                        "minimum": 0,
                        "maximum": 100
                    },
                    "to": {
                        "type": "integer",
                        "minimum": 0,
                        "maximum": 100
                    },
                    "duration": {
                        "type": "number"
                    }
                }
            },
            "output": {
                "type": "string"
            },
            "forms": [{
                "href" : "/actions/fade",
                "mediaType": "application/json",
                "http:methodName": "POST",
                "rel": "invokeAction"
            }]
        }
    },
    "events": {
        "overheated": {
            "type": "object",
            "properties": {
                "temperature": { "type": "number" }
            },
            "forms": [{
                "href" : "/events/overheated",
                "mediaType": "application/json",
                "http:methodName": "GET",
                "rel": "subscribeEvent"
            }]
        }
    },
    "security": ["apikey", "basic"]

}]]

describe('test description - consume', function()
    local thing = wot.consume(description)
    -- console.log(thing)

    -- read
    local on = thing.properties['on']
    on:read():next(function(data)
        console.log('on', data)
    end):catch(function(err)
        console.log('err', err)
    end)

    -- read
    local status = thing.properties['status']
    status:read():next(function(data)
        console.log('status', data)
    end):catch(function(err)
        console.log('err', err)
    end)

    -- invoke
    local fade = thing.actions['fade']
    fade:invoke({ to = '100', duration = 10 }):next(function(data)
        console.log('fade', data)
    end):catch(function(err)
        console.log('err', err)
    end)

    -- subscribe
    local overheated = thing.events['overheated']
    local subscription = overheated:subscribe(function(data)
        console.log('overheated', data)
    end)

    -- unsubscribe
    setTimeout(3000, function()
        subscription:unsubscribe()
    end)

end)
