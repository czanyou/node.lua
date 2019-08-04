local request = require('http/request')
local xml = require("onvif/xml")

local exports = {}

function exports.post(options, callback)
    local url = 'http://' .. options.host
    if (options.port) then
        url = url .. ':' .. options.port
    end

    url = url .. (options.path or '/')

    request.post(url, options, function(err, response, body)
        console.log(err, response.statusCode, body)
        if (err or not body) then
            callback(err or 'error')
            return
        end

        local parser = xml.newParser()
        local data = parser:ParseXmlText(body)
        local root = data['env:Envelope']
        console.log(root:name())

        local xmlBody = root['env:Body']
        console.log(xmlBody:name())

        callback(nil, xmlBody)
    end)
end

function exports.getSystemDateAndTime(options, callback)
    local message = [[
<s:Envelope xmlns:s="http://www.w3.org/2003/05/soap-envelope">
    <s:Body xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
        <GetSystemDateAndTime xmlns="http://www.onvif.org/ver10/device/wsdl"/>
    </s:Body>
</s:Envelope>
]]
    options.path = '/onvif/device_service'
    options.data = message
    exports.post(options, callback)
end

local function test()
    local options = {
        host = '192.168.1.64',
        username = 'admin', 
        password = 'admin123456'
    }

    exports.getSystemDateAndTime(options, function(err, body) 
        console.log(err, body)
    end)
end

local function test3()
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

test()

return exports
