local wot   = require('wot')
local onvif = require('onvif')

local rtmp  = require('./rtmp')
local rtsp  = require('./rtsp')

local Promise = require('wot/promise')

local exports = {}

local function onDeviceActions(input, webThing)

    local function onDeviceRead(input, webThing)
        local device = {}
        device.deviceType = 'camera'
        device.errorCode = 0

        local info = webThing.deviceInformation
        if (info) then
            device.serialNumber = info.SerialNumber
            device.model = info.Model
            device.manufacturer = info.Manufacturer
            device.hardwareVersion = info.HardwareId
            device.firmwareVersion = info.FirmwareVersion
        end

        return device
    end

    if (not input) then
        return { code = 400, error = 'Unsupported methods' }
   
    elseif (input.reset) then
        return { code = 0 }

    elseif (input.reboot) then
        return { code = 0 }

    elseif (input.read) then
        return onDeviceRead(input.read, webThing)

    else
        return { code = 400, error = 'Unsupported methods' }
    end
end

local function onConfigActions(input, webThing)

    local function onConfigRead(input, webThing)
        local config = exports.app.get('peripherals');
        config = config and config[webThing.id]

        return config
    end

    local function onConfigWrite(input, webThing)
        local config = exports.app.get('peripherals') or {}
        if (input) then
            config[webThing.id] = input
            exports.app.set('peripherals', config)
        end

        return { code = 0 }
    end

    if (not input) then
        return { code = 400, error = 'Unsupported methods' }

    elseif (input.read) then
        return onConfigRead(input.read, webThing)

    elseif (input.write) then
        return onConfigWrite(input.write, webThing);

    else
        return { code = 400, error = 'Unsupported methods' }
    end
end

local function onPtzActions(input, webThing)
    local onvifClient = webThing.onvif

    local function onPtzStart(direction, speed)
        local x = 0
        local y = 0
        local z = 0
        if (direction == 0) then
            y = 1

        elseif (direction == 1) then
            y = -1

        elseif (direction == 2) then
            x = 1

        elseif (direction == 3) then
            x = -1

        elseif (direction == 4) then
            y = 1

        elseif (direction == 5) then
            y = -1

        elseif (direction == 6) then
            x = 1

        elseif (direction == 7) then
            x = -1

        elseif (direction == 8) then
            z = 1

        elseif (direction == 9) then
            z = -1
        end

        onvifClient:continuousMove(x, y, z)
        return { code = 0 }
    end
    
    local function onPtzStop()
        onvifClient:stopMove()
        return { code = 0 }
    end

    if (input.start) then
        local direction = tonumber(input.start.direction)
        local speed = input.start.speed or 1

        if direction and (direction >= 0) and (direction <= 9) then
            return onPtzStart(direction, speed)
        else 
            return { code = 400, error = 'Invalid direction' }
        end

    elseif (input.stop) then
        return onPtzStop()
        
    else
        return { code = 400, error = 'Unsupported methods' }
    end
end

local function onPresetActions(input, webThing)
    local did = webThing.id;

    local getIndex = function(input, name)
        local index = math.floor(tonumber(input[name].index))
        if index and (index > 0 and index <= 128) then
            return index
        end
    end

    local onvifClient = webThing.onvif

    if (input.set) then
        local index = getIndex(input, 'set')
        if index then
            onvifClient:setPreset(index)
            return { code = 0 }
        else
            return { code = 400, error = "Invalid preset index" }
        end

    elseif (input['goto']) then
        local index = getIndex(input, 'goto')
        if index then
            onvifClient:gotoPreset(index)
            return { code = 0 }
        else
            return { code = 400, error = "Invalid preset index" }
        end

    elseif (input.remove) then
        local index = getIndex(input, 'remove')
        if index then
            onvifClient:removePreset(index)
            return { code = 0 }
        else
            return { code = 400, error = "Invalid preset index" }
        end

    elseif (input.read) then
        return { code = 0, presets = { { index = 1 }, { index = 2 } } }

    else
        return { code = 400, error = 'Unsupported methods' }
    end
end

local function startRtspClient(webThing)
    if (webThing.rtsp) then
        return
    end

    local rtspActions = {}

    rtspActions.sendVideoMessage = function (did, data, timestamp, isSync)
        -- console.log('sendVideoMessage', did, isSync)
        rtmp.sendVideoMessage(did, data, timestamp, isSync)
    end
    
    rtspActions.setVideoConfiguration = function (did, tagData)
        -- console.log('setVideoConfiguration', did, tagData)
        rtmp.setVideoConfiguration(did, tagData)
    end
    
    rtspActions.setRtmpMediaInfo = function (did, mediaInfo)
        console.log('setRtmpMediaInfo', did, mediaInfo)
        rtmp.setRtmpMediaInfo(did, mediaInfo)
    end
    
    local options = {}
    options.did = webThing.options.did
    options.username = webThing.options.username
    options.password = webThing.options.password
    options.url = webThing.streamUri1
    webThing.rtsp = rtsp.startRtspClient(rtspActions, options)
end

local function onPlayAction(input, webThing)
    local url = input and input.url
    local did = webThing.id;

    if (not webThing.rtmp) then
        webThing.rtmp = rtmp.startRtmpClient()
    end

    startRtspClient(webThing)

    console.log('play', did, url)

    local promise = Promise.new()
    if (not url) then
        setTimeout(0, function()
            promise:resolve({ code = 400, error = "Invalid RTMP URL" })
        end)
        return promise
    end

    local rtmp = webThing.rtmp;
    if (rtmp) then
        rtmp.publishRtmpUrl(did, url);
    end

    -- promise
    setTimeout(0, function()
        promise:resolve({ code = 0 })
    end)

    return promise
end

local function onStopAction(input, webThing)
    console.log('stop', input);

    local did = webThing.id;

    local rtmp = webThing.rtmp;
    if (rtmp) then
        rtmp.stopRtmpClient(did, 'stoped');
    end

    -- promise
    local promise = Promise.new()
    setTimeout(0, function()
        promise:resolve({ code = 0 })
    end)

    return promise
end

local function onSetActionHandlers(webThing)
    webThing:setActionHandler('play', function(input)
        return onPlayAction(input, webThing)
    end)

    webThing:setActionHandler('stop', function(input)
        return onStopAction(input, webThing)
    end)

    webThing:setActionHandler('ptz', function(input)
        return onPtzActions(input, webThing)
    end)

    webThing:setActionHandler('preset', function(input)
        return onPresetActions(input, webThing)
    end)

    webThing:setActionHandler('device', function(input)
        return onDeviceActions(input, webThing)
    end)

    webThing:setActionHandler('config', function(input)
        return onConfigActions(input, webThing)
    end)

end

local function exposeThing(webThing)
    console.log('register')
    onSetActionHandlers(webThing)

    -----------------------------------------------------------
    -- register

    webThing:expose()
    webThing:on('register', function(response)
        local result = response and response.result
        if (result and result.code and result.error) then
            console.log('register', 'error', response.did, result)

        elseif (result.token) then
            console.log('register', response.did, result.token)
            webThing.registerToken = result.token
        end
    end)

end

local function loadCameraInformation(webThing, options)
    local function getStreamUriResponse1(streamUri)
        if (streamUri) then
            console.log(streamUri)
            webThing.streamUri1 = streamUri

            startRtspClient(webThing)
        end
    end

    local function getSnapshotUriResponse1(snapshotUri)
        if (snapshotUri) then
            console.log(snapshotUri)
            webThing.snapshotUri1 = snapshotUri
        end
    end

    local function getStreamUriResponse2(streamUri)
        if (streamUri) then
            console.log(streamUri)
            webThing.streamUri2 = streamUri
        end
    end

    local function getSnapshotUriResponse2(snapshotUri)
        if (snapshotUri) then
            console.log(snapshotUri)
            webThing.snapshotUri2 = snapshotUri
        end
    end

    local function getProfilesResponse(profiles)
        local profile1 = profiles and profiles[1]
        local profile2 = profiles and profiles[2]
        local name1 = profile1 and profile1.Name
        local name2 = profile1 and profile2.Name

        webThing.profileName1 = name1
        webThing.profileName2 = name2

        local onvifClient = webThing.onvif
        onvifClient:getStreamUri(1, getStreamUriResponse1)
        onvifClient:getSnapshotUri(1, getSnapshotUriResponse1)

        onvifClient:getStreamUri(2, getStreamUriResponse2)
        onvifClient:getSnapshotUri(2, getSnapshotUriResponse2)
    end

    local function getDeviceInformationResponse(response)
        if (not response) then
            return
        end

        webThing.deviceInformation = response
        -- console.log(response)

        local onvifClient = webThing.onvif
        onvifClient:getProfiles(getProfilesResponse)

        -- console.log(webThing.instance)
        local instance = webThing.instance
        local version = instance and instance.version
        if (version) then
            version.firmware = response.FirmwareVersion
        end

        if (not webThing.registerTimer) then
            exposeThing(webThing)
        end
    end

    local onvifClient = webThing.onvif
    onvifClient:getDeviceInformation(getDeviceInformationResponse)
end

local function createCameraThing(options)
    if (not options) then
        return nil, 'need options'

    elseif (not options.mqtt) then
        return nil, 'need MQTT url option'

    elseif (not options.did) then
        return nil, 'need did option'
    end

    -----------------------------------------------------------
    -- description

    local camera = { 
        ['@context'] = "https://iot.beaconice.cn/schemas",
        ['@type'] = 'Camera',
        id = options.did, 
        url = options.mqtt,
        name = 'camera',
        actions = {
            play = { ['@type'] = 'play' },
            stop = { ['@type'] = 'stop' },
        },
        properties = {},
        events = {},
        version = {
            instance = '1.0'
        }
    }

    local webThing = wot.produce(camera)
    webThing.secret = options.secret
    webThing.options = options
    webThing.onvif = onvif.camera(options)

    loadCameraInformation(webThing, options)

    return webThing
end

exports.rtmp = function()

end

exports.rtsp = function()
    
end

exports.createThing = createCameraThing

return exports
