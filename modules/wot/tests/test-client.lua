local wotclient = require('wot/client')
local util = require('util')

local WotClient = wotclient.WotClient

local tap = require('util/tap')

describe('test client - new WotClient', function()
    ---@type WotClientOptions
    local options = {
        directory = 'mqtt://iot.wotcloud.cn/'
    }

    ---@type WotClient
    local client = WotClient:new(options)
    console.log(client)

    client:on('register', function(result)
        console.log('register', result)
    end)

    client:on('connect', function(result)
        console.log('connect', result)

        client:close()
    end)

    client:start()
end)
