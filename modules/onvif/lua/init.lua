local core = require('core')
local util = require("util")

local request = require('http/request')
local xml = require("onvif/xml")

local exports = {}

-------------------------------------------------------------------------------
-- Common

local noop = function() end

local function getXmlNodeName(name)
    if (type(name) ~= 'string') then
        return name
    end

    local pos = string.find(name, ':')
    if (pos and pos > 0) then
        name = string.sub(name, pos + 1)
    end

    return name
end

-- 将 XML 节点转换为 Lua 表格
-- @param element {XmlNode}
function exports.xmlToTable(element)
    if (not element) then
        return
    end

    local name = getXmlNodeName(element:name())
    local properties = element:properties();
    local children = element:children();

    if (children and #children > 0) then
        local item = {}

        -- children
        for _, value in ipairs(children) do
            local key, ret = exports.xmlToTable(value)
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

-- 发送 POST 请求
-- @param options {object}
-- @param callback {function}
function exports.post(options, callback)
    if (type(callback) ~= 'function') then
        callback = noop
    end

    local host = options.address or options.ip
    if (not host) then
        return callback('Invalid host address')
    end

    local url = 'http://' .. host
    if (options.port) then
        url = url .. ':' .. options.port
    end

    url = url .. (options.path or '/')
    -- console.log(url, options)

    request.post(url, options, function(err, response, body)
        -- console.log(url, err, response, body)

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
        if (not children) then
            return callback('Body element not found')
        end

        local body = children and children[#children] -- and root['env:Body']
        
        -- response
        children = body and body:children();
        local response = children and children[#children]; -- body['Response']
        if (not children) then
            return callback('Response element not found')
        end

        local name = getXmlNodeName(response:name())
        -- console.log(name, #children)

        -- result
        local _, result = exports.xmlToTable(response)
        if (name == 'Fault') then
            callback(result)
        else
            callback(nil, result)
        end
    end)
end

-- 实现 ONVIF 认证
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

-- 生成 SOAP 消息头
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

-- 生成 SOAP 消息
function exports.getMessage(options, body)
    local message = '<s:Envelope xmlns:s="http://www.w3.org/2003/05/soap-envelope" xmlns:a="http://www.w3.org/2005/08/addressing">' ..
    exports.getHeader(options) .. 
    [[<s:Body xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">]] ..
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

-- options
-- - address {string} IP 地址
-- - username {string} 用户名
-- - password {string} 密码
function OnvifCamera:initialize(options)
    self.options = options
    self.deviceInformation = nil
    self.profiles = nil
    self.services = nil
    self.capabilities = nil
end

function OnvifCamera:getPresets(callback)
    local options = self:getPresetOptions(1)
    ptz.getPresets(options, callback)
end

function OnvifCamera:removePreset(preset, callback)
    local options = self:getPresetOptions(1, preset)
    ptz.removePreset(options, callback)
end

function OnvifCamera:gotoPreset(preset, callback)
    local options = self:getPresetOptions(1, preset)
    ptz.gotoPreset(options, callback)
end

function OnvifCamera:setPreset(preset, callback)
    local options = self:getPresetOptions(1, preset)
    ptz.setPreset(options, callback)
end

function OnvifCamera:stopMove(callback)
    local options = self:getOptions(1)
    ptz.stop(options, callback)
end

function OnvifCamera:continuousMove(x, y, z, callback)
    local options = self:getOptions(1)
    options.x = x;
    options.y = y;
    options.z = z;
    ptz.continuousMove(options, callback)
end

function OnvifCamera:get(method, name, callback)
    if (not callback) then callback = function() end end

    if (self[name]) then
        return callback(self[name])
    end

    local options = self:getOptions()
    method(options, function(err, response)
        if (response) then
            self[name] = response
        end

        return callback(response, err)
    end)
end

function OnvifCamera:getDeviceInformation(callback)
    self:get(exports.getDeviceInformation, 'deviceInformation', callback)
end

function OnvifCamera:getCapabilities(callback)
    self:get(exports.getCapabilities, 'capabilities', callback)
end

function OnvifCamera:getServices(callback)
    self:get(exports.getServices, 'services', callback)
end

function OnvifCamera:getProfiles(callback)
    self:get(media.getProfiles, 'profiles', callback)
end

function OnvifCamera:getVideoSources(callback)
    self:get(media.getVideoSources, 'videoSources', callback)
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
        address = options.address,
        port = options.port,
        profile = profile,
        username = options.username,
        password = options.password
    }
end

function OnvifCamera:getPresetOptions(index, preset)
    local options = self:getOptions(index)
    options.preset = preset

    if (options.profile == 'MainStream') then
        -- options.profile = nil
        if (preset == 1) then
            -- 修正某摄像机预置位 1 不能使用的问题
            options.preset = 201
        end
    end
    return options
end

function OnvifCamera:getStreamUri(index, callback)
    if (not callback) then callback = function() end end

    local profile = self.profiles and self.profiles[index]
    if (not profile) then
        return callback(nil, 'Invalid profiles')
    end

    if (profile.streamUri) then
        return profile.streamUri
    end

    local options = self:getOptions(index)
    exports.media.getStreamUri(options, function(err, body) 
        if (err) then
            return callback(nil, err)
        end

        local response = body and body.MediaUri
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
        local response = body and body.MediaUri
        local snapshotUri = response and response.Uri
        if (not snapshotUri) then
            return callback(nil, body)
        end

        -- console.log('snapshotUri', snapshotUri)
        profile.snapshotUri = snapshotUri
        callback(snapshotUri)
    end)
end

-------------------------------------------------------------------------------
-- exports

function exports.camera(options)
    return OnvifCamera:new(options)
end

return exports
