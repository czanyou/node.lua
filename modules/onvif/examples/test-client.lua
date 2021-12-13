local onvif = require('onvif')
local xml = require('app/xml')
local json = require('json')
local fs = require('fs')

local options = {
    address = '192.168.1.64',
    username = 'admin', 
    password = 'admin123456'
}

options = {
    address = '192.168.1.104',
    username = 'admin',
    password = 'abcdefg123456'
}

options = {
    address = '192.168.1.10',
    username = 'admin',
    password = '123456'
}

options = {
    address = '192.168.31.108',
    username = 'admin',
    password = '123456'
}

options = {
    address = 'iot.wotcloud.cn:8899',
    username = 'admin',
    password = '123456'
}

local function testGetSystemDateAndTime()
    onvif.getSystemDateAndTime(options, function(err, body) 
        console.log(err, body)
    end)
end

local function testGetCapabilities()
    onvif.getCapabilities(options, function(err, body) 
        console.log(err, body)
    end)
end

local function testGetDeviceInformation()
    onvif.getDeviceInformation(options, function(err, body)
        console.log(err, body)
    end)
end

local function testGetUsernameToken()
    local data = onvif.getUsernameToken(options)
    console.log(data)
end

local function testGetProfiles(callback)
    onvif.media.getProfiles(options, function(err, response)
        local profile1 = response.Profiles and response.Profiles[1]
        local profile2 = response.Profiles and response.Profiles[2]
        local name1 = profile1 and profile1.Name
        local name2 = profile1 and profile2.Name
        console.log(err, name1, name2)

        callback(name1, name2);
    end)
end

local function testGetVideoSourcess()
    onvif.media.getVideoSources(options, function(err, body)
        console.log(err, json.stringify(body))
    end)
end

local function testGetStreamUri(name)
    options.profile = name
    onvif.media.getStreamUri(options, function(err, body)
        console.log(err, body)
    end)
end

local function testGetSnapshotUri()
    onvif.media.getSnapshotUri(options, function(err, body)
        console.log(err, body)
    end)
end

local function testContinuousMove()
    options.profile = 'Profile_1'
    options.x = 1;
    -- options.y = -1;
    options.z = 0;
    onvif.ptz.continuousMove(options, function(err, body)
        console.log(err, json.stringify(body))
    end)
end

local function testXml()
    local message = [[
<s:Envelope xmlns:s="http://www.w3.org/2003/05/soap-envelope">
    <s:Body xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
        <GetSystemDateAndTime xmlns="http://www.onvif.org/ver10/device/wsdl"/>
    </s:Body>
</s:Envelope>
]]
    local parser = xml.newParser()
    local data = parser:parseXmlText(message)
    local root = data['s:Envelope']
    console.log(root:name())

    local body = root['s:Body']
    console.log(body:name())

    local element = body.GetSystemDateAndTime
    console.log(element:name())
    console.log(element:properties())
    console.log(element['@xmlns'])

end

local function testCamera()
    local function printProfile(profile)
        if (not profile) then
            return
        end

        local result = {}
        result.token = profile['@token']
        result.Name = profile.Name

        local encoder = profile.VideoEncoderConfiguration
        result.Encoding = encoder.Encoding
        result.H264 = encoder.H264
        result.Quality = encoder.Quality
        result.RateControl = encoder.RateControl
        result.Resolution = encoder.Resolution

        console.log('profile', result)
    end

    local onvifClient = onvif.createClient(options)

    onvifClient:getDeviceInformation(function(err, result)
        console.log('getDeviceInformation', err, result)
    end)

    onvifClient:getCapabilities(function(err, result)
        console.log('getCapabilities', err, result)
    end)

    onvifClient:getServices(function(err, result)
        console.log('getServices', err, result)
    end)

    onvifClient:getProfiles(function(err, result)
        if (not result) then
            return
        end

        fs.writeFileSync('/home/cz/node.lua/build/profiles.json', json.stringify(result))
        local profiles = result.Profiles or {}
        printProfile(profiles[1])
        printProfile(profiles[2])

        onvifClient:getStreamUri(1, function(err, result)
            console.log('getStreamUri', err, result)
        end)

        onvifClient:getSnapshotUri(1, function(err, result)
            console.log('getSnapshotUri', err, result)
        end)
    end)
end

-- testGetSystemDateAndTime()
-- testGetDeviceInformation()

testCamera()

