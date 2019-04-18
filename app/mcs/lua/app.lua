local app       = require('app')
local wot       = require('wot')
local express 	= require('express')
local path 		= require('path')
local json  	= require('json')
local util 		= require('util')
local fs    	= require('fs')
local request 	= require('http/request')

local BASE_URL = 'http://iot.beaconice.cn:7001'

local exports = {}

function pushCameraStatus(did)
    local data = {
        on = true
    };

    pushDataStream(did, 'camera', data, function(err, data)
        console.log(did, 'camera', err, data)
    end)
end

local USER_AGENT = 'Mozilla/5.0 (Linux; Android 6.0; Nexus 5 Build/MRA58N) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/70.0.3538.110 Mobile Safari/537.36'

function getLiveStatus(callback)
    local headers = {
        ['User-Agent'] = USER_AGENT
    }

    local options = { headers = headers }

    local urlString = BASE_URL .. '/api/streams'
    request.get(urlString, options, function(err, response, body) 
        if (err) then
            callback(err);
            return
        end

        local data = json.parse(body)
        callback(nil, data);
    end)
end

function pushDataStream(did, name, data, callback)
    local message = {
        did = did,
        type = 'stream',
        data = data
    }

    local messageData = json.stringify(message)
    local headers = {
        ['Content-Type'] = 'application/json'
    }
    
    local options = { data = messageData, headers = headers }

    local urlString = 'http://iot.beaconice.cn/v2/stream/messages/'
    -- local urlString = 'http://localhost:8951/messages/'
    request.post(urlString, options, function(err, response, body) 
        if (err) then
            callback(err)
            return
        end

        local result = json.parse(body)
        callback(nil, result)
    end)

end

function exports.query()
    getLiveStatus(function(result) 
        console.log(result)
    end)
end

function exports.push()
    
end

function exports.start()
    local interval = 1000 * 60;
    setInterval(interval, function()
        exports.test();
    end)

    exports.test();
end

function exports.test()
    local did = 'test2';
    pushCameraStatus(did);
end

app(exports)
