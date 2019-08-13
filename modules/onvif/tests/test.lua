local onvif = require('onvif')
local xml = require("onvif/xml")
local json = require('json')

local options = {
    host = '192.168.1.64',
    username = 'admin', 
    password = 'admin123456'
}

options = {
    host = '192.168.1.104',
    username = 'admin',
    password = 'abcdefg123456'
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

local function testGetProfiles()
    onvif.media.getProfiles(options, function(err, body)
        console.log(err, json.stringify(body))
    end)
end

local function testGetVideoSourcess()
    onvif.media.getVideoSources(options, function(err, body)
        console.log(err, json.stringify(body))
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
    local data = parser:ParseXmlText(message)
    local root = data['s:Envelope']
    console.log(root:name())

    local body = root['s:Body']
    console.log(body:name())

    local element = body.GetSystemDateAndTime
    console.log(element:name())
    console.log(element:properties())
    console.log(element['@xmlns'])

end

testContinuousMove()
