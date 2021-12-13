local xml = require('app/xml')
local tap = require('util/tap')
local assert = require('assert')

describe('test xml - parse', function()
    local data, err = xml.parse()
    console.log(data, err)

    data, err = xml.parse(1)
    console.log(data, err)

    data, err = xml.parse({})
    console.log(data, err)

    data, err = xml.parse('')
    console.log(data, err)

    data, err = xml.parse(' ')
    assert.equal(#data:children(), 0)

    data, err = xml.parse('{}')
    assert.equal(#data:children(), 0)

    data, err = xml.parse('<root/>')
    assert.equal(#data:children(), 1)

    data, err = xml.parse('<root></root>')
    assert.equal(#data:children(), 1)
end)

describe('test xml - onvif', function()

    local message = [[
<s:Envelope xmlns:s="http://www.w3.org/2003/05/soap-envelope">
    <s:Body xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
        <GetSystemDateAndTime xmlns="http://www.onvif.org/ver10/device/wsdl"/>
    </s:Body>
</s:Envelope>
]]

    local data = xml.parse(message)

    -- root
    local root = data['s:Envelope']
    assert.equal(root:name(), 's:Envelope')

    -- body
    local body = root['s:Body']
    assert.equal(body:name(), 's:Body')

    -- GetSystemDateAndTime
    local element = body.GetSystemDateAndTime
    assert.equal(element:name(), 'GetSystemDateAndTime')
    assert.equal(element['@xmlns'], 'http://www.onvif.org/ver10/device/wsdl')

    -- properties
    local properties = element:properties()
    local property = properties[1]
    assert.equal(property.name, 'xmlns')

    -- xmlToTable
    local _, object = xml.xmlToTable(data)
    -- console.log(object)
    local Envelope = object.Envelope
    local Body = Envelope.Body
    local GetSystemDateAndTime = Body.GetSystemDateAndTime
    assert.equal(GetSystemDateAndTime['@xmlns'], 'http://www.onvif.org/ver10/device/wsdl')
end)
