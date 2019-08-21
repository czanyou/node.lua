local request = require('http/request')
local xml = require("onvif/xml")
local util = require("util")
local core 	 = require('core')

local exports = {}

-------------------------------------------------------------------------------
-- Common

function exports.xml2table(element)
    if (not element) then
        return
    end

    local name = element:name()
    local properties = element:properties();
    local children = element:children();

    local pos = string.find(name, ':')
    if (pos and pos > 0) then
        name = string.sub(name, pos + 1)
    end

    if (children and #children > 0) then
        local item = {}

        -- children
        for _, value in ipairs(children) do
            local key, ret = exports.xml2table(value)
            local lastValue = item[key]
            if (lastValue == nil) then
                item[key] = ret

            elseif (type(lastValue) == 'table') and (lastValue[1]) then
                table.insert(lastValue, ret)

            else
                item[key] = { lastValue, ret }
            end
        end
  
        -- properties
        if (properties and #properties > 0) then
            for _, property in ipairs(properties) do
                local value = element['@' .. property.name]
                item['@' .. property.name] = value
            end
        end

        return name, item

    else
        -- properties
        if (properties and #properties > 0) then
            -- console.log(name, properties)
            local item = {}
            for _, property in ipairs(properties) do
                local value = element['@' .. property.name]
                -- console.log(name, property, value)

                item['@' .. property.name] = value
            end

            item.value = element:value()

            -- console.log(name, item)
            return name, item

        else
            return name, element:value()
        end
    end
end

function exports.post(options, callback)
    local host = options.host or options.ip
    if (not host) then
        return callback('Invalid host')
    end

    local url = 'http://' .. host
    if (options.port) then
        url = url .. ':' .. options.port
    end

    url = url .. (options.path or '/')

    request.post(url, options, function(err, response, body)
        -- console.log(err, response.statusCode, body)
        if (err or not body) then
            callback(err or 'error')
            return
        end

        local parser = xml.newParser()
        local data = parser:ParseXmlText(body)

        -- Envelope
        local children = data:children();
        -- console.log(data:name(), #children)

        local root = children and children[1] -- and data['env:Envelope']
        if (not children) then
            return callback('Envelope element not found')
        end

        -- console.log(root and root:name())

        -- Body
        children = root and root:children();
        local xmlBody = children and children[#children] -- and root['env:Body']
        if (not children) then
            return callback('Body element not found')
        end

        -- console.log(xmlBody:name(), #children)

        local _, result = exports.xml2table(xmlBody)
        callback(nil, result)
    end)
end

function exports.getUsernameToken(options)
    local timestamp = '2019-08-03T03:21:33.001Z'
    local nonce = util.base64Decode('SNMfYjdAJzZzDk0SY8Xdhw==')
    local data = nonce .. timestamp .. options.password
    local digest = util.sha1(data)
    digest = util.base64Encode(digest);

    return {
        timestamp = timestamp,
        nonce = util.base64Encode(nonce),
        digest = digest
    }
end

function exports.getHeader(options)
    if (not options.username) or (not options.password) then
        return ''
    end

    local result = exports.getUsernameToken(options)

    local header = [[    
    <s:Header>
        <Security s:mustUnderstand="1" xmlns="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd">
            <UsernameToken>
                <Username>]] .. options.username .. [[</Username>
                <Password Type="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-username-token-profile-1.0#PasswordDigest">]] .. result.digest .. [[</Password>
                <Nonce EncodingType="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-soap-message-security-1.0#Base64Binary">]] .. result.nonce .. [[</Nonce>
                <Created xmlns="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd">]] .. result.timestamp .. [[</Created>
            </UsernameToken>
        </Security>
    </s:Header>
    ]]

    return header;
end

function exports.getMessage(options, body)
    local message = '<s:Envelope xmlns:s="http://www.w3.org/2003/05/soap-envelope" xmlns:a="http://www.w3.org/2005/08/addressing">' ..
    exports.getHeader(options) .. [[
    <s:Body xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">]] ..
    body .. '</s:Body></s:Envelope>'
    return message
end

-------------------------------------------------------------------------------
-- Device

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

function exports.getCapabilities(options, callback)
    local message = exports.getMessage(options, [[
        <GetCapabilities xmlns="http://www.onvif.org/ver10/device/wsdl">
            <Category>All</Category>
        </GetCapabilities>]])
    options.path = '/onvif/device_service'
    options.data = message
    exports.post(options, callback)
end

function exports.getDeviceInformation(options, callback)
    local message = exports.getMessage(options, [[
        <GetDeviceInformation xmlns="http://www.onvif.org/ver10/device/wsdl">
        </GetDeviceInformation>]])
    options.path = '/onvif/device_service'
    options.data = message
    exports.post(options, callback)
end

function exports.getServices(options, callback)
    local message = exports.getMessage(options, [[
        <GetServices xmlns="http://www.onvif.org/ver10/device/wsdl">
            <IncludeCapability>true</IncludeCapability>
        </GetServices>]])

    options.path = '/onvif/device_service'
    options.data = message
    exports.post(options, callback)
end

-------------------------------------------------------------------------------
-- Media

local media = {}

function media.getProfiles(options, callback)
    local message = exports.getMessage(options, [[<GetProfiles xmlns="http://www.onvif.org/ver10/media/wsdl"/>]])
    options.path = '/onvif/Media'
    options.data = message
    exports.post(options, callback)
end

function media.getVideoSources(options, callback)
    local message = exports.getMessage(options, [[<GetVideoSources xmlns="http://www.onvif.org/ver10/media/wsdl"/>]])
    options.path = '/onvif/Media'
    options.data = message
    exports.post(options, callback)
end

function media.getStreamUri(options, callback)
    local profile = options.profile or 'Profile_1'

    local message = exports.getMessage(options, [[
        <GetStreamUri xmlns="http://www.onvif.org/ver10/media/wsdl">
            <StreamSetup>
                <Stream xmlns="http://www.onvif.org/ver10/schema">RTP-Unicast</Stream>
                <Transport xmlns="http://www.onvif.org/ver10/schema">
                    <Protocol>RTSP</Protocol>
                </Transport>
            </StreamSetup>
            <ProfileToken>]] .. profile .. [[</ProfileToken>
        </GetStreamUri>]])

    options.path = '/onvif/Media'
    options.data = message
    exports.post(options, callback)
end

function media.getSnapshotUri(options, callback)
    local profile = options.profile or 'Profile_1'

    local message = exports.getMessage(options, [[
        <GetSnapshotUri xmlns="http://www.onvif.org/ver10/media/wsdl">
            <ProfileToken>]] .. profile .. [[</ProfileToken>
        </GetSnapshotUri>]])

    options.path = '/onvif/Media'
    options.data = message
    exports.post(options, callback)
end

function media.getOSDs(options, callback)
    local message = exports.getMessage(options, [[
        <GetOSDs xmlns="http://www.onvif.org/ver10/media/wsdl">
        </GetOSDs>]])
    options.path = '/onvif/Media'
    options.data = message
    exports.post(options, callback)
end

exports.media = media

-------------------------------------------------------------------------------
-- PTZ

local ptz = {}

function ptz.getPresets(options, callback)
    local profile = options.profile or 'Profile_1'
    local message = exports.getMessage(options, [[
        <GetPresets xmlns="http://www.onvif.org/ver20/ptz/wsdl">
            <ProfileToken>]] .. profile .. [[</ProfileToken>
        </GetPresets>]])
    options.path = '/onvif/ptz'
    options.data = message
    exports.post(options, callback)
end

function ptz.continuousMove(options, callback)
    local x = options.x or 0
    local y = options.y or 0
    local z = options.z or 0
    local profile = options.profile or 'Profile_1'

    local message = exports.getMessage(options, [[
        <ContinuousMove xmlns="http://www.onvif.org/ver20/ptz/wsdl">
            <ProfileToken>]] .. profile .. [[</ProfileToken>
            <Velocity>
                <PanTilt x="]] .. x .. [[" y="]] .. y .. [[" xmlns="http://www.onvif.org/ver10/schema"/>
                <Zoom x="]] .. z .. [[" xmlns="http://www.onvif.org/ver10/schema"/>
            </Velocity>
        </ContinuousMove>]])
    options.path = '/onvif/ptz'
    options.data = message
    exports.post(options, callback)
end

function ptz.stop(options, callback)
    local profile = options.profile or 'Profile_1'
    local message = exports.getMessage(options, [[
        <Stop xmlns="http://www.onvif.org/ver20/ptz/wsdl">
            <ProfileToken>]] .. profile .. [[</ProfileToken>
        </Stop>]])
    options.path = '/onvif/ptz'
    options.data = message
    exports.post(options, callback)
end

function ptz.setPreset(options, callback)
    local profile = options.profile or 'Profile_1'
    local preset = options.preset or 0
    local message = exports.getMessage(options, [[
        <SetPreset xmlns="http://www.onvif.org/ver20/ptz/wsdl">
            <ProfileToken>]] .. profile .. [[</ProfileToken>
            <PresetToken>]] .. preset .. [[</PresetToken>
        </SetPreset>]])
    options.path = '/onvif/ptz'
    options.data = message
    exports.post(options, callback)
end

function ptz.gotoPreset(options, callback)
    local profile = options.profile or 'Profile_1'
    local preset = options.preset or 0
    local message = exports.getMessage(options, [[
        <GotoPreset xmlns="http://www.onvif.org/ver20/ptz/wsdl">
            <ProfileToken>]] .. profile .. [[</ProfileToken>
            <PresetToken>]] .. preset .. [[</PresetToken>
        </GotoPreset>]])
    options.path = '/onvif/ptz'
    options.data = message
    exports.post(options, callback)
end

function ptz.removePreset(options, callback)
    local profile = options.profile or 'Profile_1'
    local preset = options.preset or 0
    local message = exports.getMessage(options, [[
        <RemovePreset xmlns="http://www.onvif.org/ver20/ptz/wsdl">
            <ProfileToken>]] .. profile .. [[</ProfileToken>
            <PresetToken>]] .. preset .. [[</PresetToken>
        </RemovePreset>]])
    options.path = '/onvif/ptz'
    options.data = message
    exports.post(options, callback)
end

exports.ptz = ptz

-------------------------------------------------------------------------------
-- OnvifCamera

local OnvifCamera = core.Emitter:extend()

function OnvifCamera:initialize(options)
    self.options = options
    self.deviceInformation = nil
end

function OnvifCamera:getPresets(callback)
    if (not callback) then callback = function() end end

    local options = self:getOptions(1)
    ptz.getPresets(options, function(err, body)
        callback(body)
    end)
end

function OnvifCamera:removePreset(preset, callback)
    if (not callback) then callback = function() end end

    local options = self:getOptions(1)
    options.preset = preset
    ptz.removePreset(options, function(err, body)
        callback(body)
    end)
end

function OnvifCamera:gotoPreset(preset, callback)
    if (not callback) then callback = function() end end

    local options = self:getOptions(1)
    options.preset = preset
    ptz.gotoPreset(options, function(err, body)
        callback(body)
    end)
end

function OnvifCamera:setPreset(preset, callback)
    if (not callback) then callback = function() end end

    local options = self:getOptions(1)
    options.preset = preset
    ptz.setPreset(options, function(err, body)
        callback(body)
    end)
end

function OnvifCamera:stopMove(callback)
    if (not callback) then callback = function() end end

    local options = self:getOptions(1)
    ptz.stop(options, function(err, body)
        callback(body)
    end)
end

function OnvifCamera:continuousMove(x, y, z, callback)
    if (not callback) then callback = function() end end

    local options = self:getOptions(1)
    options.x = x;
    options.y = y;
    options.z = z;
    ptz.continuousMove(options, function(err, body)
        callback(body)
    end)
end

function OnvifCamera:getDeviceInformation(callback)
    if (not callback) then callback = function() end end

    if (self.deviceInformation) then
        return callback(self.deviceInformation)
    end

    local options = self:getOptions()

    exports.getDeviceInformation(options, function(err, body) 
        if (err) then
            return callback(nil, err)
        end

        local response = body and body.GetDeviceInformationResponse
        if (response) then
            self.deviceInformation = response
        end

        return callback(response)
    end)
end

function OnvifCamera:getProfiles(callback)
    if (not callback) then callback = function() end end

    if (self.profiles) then
        return callback(self.profiles)
    end

    local options = self:getOptions()

    exports.media.getProfiles(options, function(err, body) 
        if (err) then
            return callback(nil, err)
        end

        local response = body and body.GetProfilesResponse
        if (not response) then
            return callback(nil)
        end

        self.profiles = response and response.Profiles
        return callback(self.profiles)
    end)
end

function OnvifCamera:getOptions(index)
    local options = self.options or {}

    local profile = nil
    if (index) then
        profile = self.profiles and self.profiles[index]
        profile = profile and (profile['@token'] or profile.Name)
    end

    return {
        ip = options.ip,
        profile = profile,
        username = options.username,
        password = options.password
    }
end

function OnvifCamera:getStreamUri(index, callback)
    if (not callback) then callback = function() end end

    local profile = self.profiles and self.profiles[index]
    if (not profile) then
        return callback(nil)
    end

    if (profile.streamUri) then
        return profile.streamUri
    end

    local options = self:getOptions(index)
    exports.media.getStreamUri(options, function(err, body) 
        if (err) then
            return callback(nil, err)
        end

        local response = body and body.GetStreamUriResponse
        response = response and response.MediaUri
        local streamUri = response and response.Uri
        if (not streamUri) then
            return callback(nil, body)
        end

        -- console.log('streamUri', streamUri)
        profile.streamUri = streamUri
        return callback(streamUri)
    end)
end

function OnvifCamera:getSnapshotUri(index, callback)
    if (not callback) then callback = function() end end
    
    local profile = self.profiles and self.profiles[index]
    if (not profile) then
        return callback(nil)
    end

    if (profile.snapshotUri) then
        return profile.snapshotUri
    end

    local options = self:getOptions(index)
    exports.media.getSnapshotUri(options, function(err, body) 
        if (err) then
            return callback(nil, err)
        end

        -- console.log('body', body)
        local response = body and body.GetSnapshotUriResponse
        response = response and response.MediaUri
        local snapshotUri = response and response.Uri
        if (not snapshotUri) then
            return callback(nil, body)
        end

        -- console.log('snapshotUri', snapshotUri)
        profile.snapshotUri = snapshotUri
        callback(snapshotUri)
    end)
end

function OnvifCamera:getVideoUri(profile)
    local host = self.options.host
    -- rtsp://192.168.1.104:554/Streaming/Channels/101?transportmode=unicast&profile=Profile_1
    local path = '/Streaming/Channels/10' .. (profile or 1)
    local query = 'transportmode=unicast&profile=Profile_'  .. (profile or 1)
    return 'rtsp://' .. host .. '' .. path .. '?' .. query
end

function OnvifCamera:getImageUri(profile)
    -- http://192.168.1.104/onvif-http/snapshot?Profile_1

    local host = self.options.host
    local path = '/onvif-http/snapshot'
    local query = 'Profile_'  .. (profile or 1)
    return 'http://' .. host .. '' .. path .. '?' .. query
end

function exports.camera(options)
    return OnvifCamera:new(options)
end

return exports
