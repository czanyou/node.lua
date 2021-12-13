local onvif = require('onvif')
local xml = require('app/xml')
local json = require('json')
local fs = require('fs')

local options = {
    address = 'iot.wotcloud.cn',
    password = '123456',
    port = 1108,
    username = 'admin'
}

local function testReplay()
    local onvifClient = onvif.createClient(options)

    local input = {}
    onvifClient:getSegments(input, function(error, result)
        console.log('testReplay', error, result)
    end)
end

testReplay()
