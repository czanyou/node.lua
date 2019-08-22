local wot   = require('wot')
local onvif = require('onvif')

local rtmp  = require('./rtmp')
local rtsp  = require('./rtsp')

local Promise = require('wot/promise')

local exports = {}

-- Camera device actions
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
        return { code = 400, error = 'Unsupported methods' }

    elseif (input.reboot) then
        return { code = 400, error = 'Unsupported methods' }

    elseif (input.read) then
        return onDeviceRead(input.read, webThing)

    else
        return { code = 400, error = 'Unsupported methods' }
    end
end

-- Camera config actions
local function onConfigActions(input, webThing)

    -- read config
    local function onConfigRead(input, webThing)
        local config = exports.app.get('peripherals');
        config = config and config[webThing.id]

        return config
    end

    -- save config
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

-- Camera PTZ actions
local function onPtzActions(input, webThing)
    local onvifClient = webThing.onvif

    -- start move
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
    
    -- stop move
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

-- Camera preset actions
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

-- Start RTSP client
local function startRtspClient(webThing)
    if (webThing.rtsp) then
        return

    elseif (not webThing.profiles) then
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
        -- console.log('setRtmpMediaInfo', did, mediaInfo)
        rtmp.setRtmpMediaInfo(did, mediaInfo)
    end

    local profile = webThing.profiles and webThing.profiles[1]
    if (not profile) or (not profile.streamUri) then
        return
    end
    
    local options = {}
    options.did = webThing.options.did
    options.username = webThing.options.username
    options.password = webThing.options.password
    options.url = profile.streamUri
    webThing.rtsp = rtsp.startRtspClient(rtspActions, options)
end

-- Camera play action
-- - Pull stream from camera
-- - Push stream to RTMP media server
local function onPlayAction(input, webThing)
    local url = input and input.url
    local did = webThing.id;

    -- rtmp
    if (not webThing.rtmp) then
        webThing.rtmp = rtmp.startRtmpClient()
    end

    local rtmp = webThing.rtmp;
    if (rtmp) then
        rtmp.publishRtmpUrl(did, url);
    end

    -- rtsp
    if (webThing.rtsp) then
        webThing.rtsp.play(did)
    else
        startRtspClient(webThing)
    end

    -- console.log('play', did, url)

    local promise = Promise.new()
    if (not url) then
        setTimeout(0, function()
            promise:resolve({ code = 400, error = "Invalid RTMP URL" })
        end)
        return promise
    end

    -- promise
    setTimeout(0, function()
        promise:resolve({ code = 0 })
    end)

    return promise
end

-- Camera stop action
-- - Stop push stream to RTMP media server
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

-- All camera actions
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

-- Expose and register the camera thing
local function exposeThing(webThing)
    if (not webThing) or (not webThing.instance) then
        return
    end

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

-- Load the all camera informations (device and media) via ONVIF protocol
local function loadCameraInformation(webThing, options)

    -- Load stream & snapshot uri address
    local function loadStreamUri(profiles, index)
        local onvifClient = webThing.onvif

        local function getStreamUriResponse(streamUri, error)
            if (not streamUri) then
                console.log('Invalid stream Uri', error)
                return 
            end

            console.log(streamUri)
            webThing.profiles[index].streamUri = streamUri
            -- startRtspClient(webThing)
        end

        local function getSnapshotUriResponse(snapshotUri, error)
            if (not snapshotUri) then
                console.log('Invalid snapshot Uri', error)
                return
            end

            console.log(snapshotUri)
            webThing.profiles[index].snapshotUri = snapshotUri
        end

        local profile = profiles and profiles[index]
        if (not profile) then
            return
        end

        webThing.profiles[index] = {}
        webThing.profiles[index].token = profile['@token']
        webThing.profiles[index].name = profile.Name
        
        onvifClient:getStreamUri(index, getStreamUriResponse)
        onvifClient:getSnapshotUri(index, getSnapshotUriResponse)
    end

    -- Load media profiles of the ONVIF device
    local function getProfilesResponse(profiles)
        if (not profiles) then
            console.log('Invalid Profiles')
            return
        end

        webThing.profiles = {}

        loadStreamUri(profiles, 1)
        loadStreamUri(profiles, 2)
    end

    -- Load ONVIF device information
    local function getDeviceInformationResponse(response, error)
        if (not response) then
            if (error) then
                console.log('GetDeviceInformation Error:', error)
            end
            return
        end

        webThing.deviceInformation = response
        console.log(response)

        -- load profile information
        local onvifClient = webThing.onvif
        onvifClient:getProfiles(getProfilesResponse)

        -- console.log(webThing.instance)
        -- update firmware version
        local instance = webThing.instance
        local version = instance and instance.version
        local firmwareVersion = response.FirmwareVersion
        if (version and firmwareVersion) then
            local pos = string.find(firmwareVersion, ' ')
            if (pos and pos > 1) then
                firmwareVersion = string.sub(firmwareVersion, 1, pos - 1)
            end

            version.firmware = firmwareVersion
        end

        -- start register
        if (not webThing.registerTimer) then
            exposeThing(webThing)
        end
    end

    local function onStartReadInformations()
        if (webThing.profiles) then
            return
        end

        local onvifClient = webThing.onvif
        onvifClient:getDeviceInformation(getDeviceInformationResponse)
    end

    setInterval(1000 * 30, function()
        onStartReadInformations()
    end)

    onStartReadInformations()
end

-- Create a camera WebThing
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

    local function getOnvifStatus(webThing)
        return {
            profiles = webThing.profiles
        }
    end

    webThing.getStatus = function(self)
        return {
            options = self.options,
            deviceInformation = webThing.deviceInformation,
            media = getOnvifStatus(webThing)
        }
    end

    loadCameraInformation(webThing, options)

    return webThing
end

exports.rtmp = function()

end

exports.rtsp = function()
    local options = {
        ip = '192.168.1.64',
        username = 'admin',
        password = 'admin123456',
        url = 'rtsp://192.168.1.64'
    }

    local webThing = {
        options = options
    }

    startRtspClient(webThing)
end

exports.onvif = function(...)
    local options = {
        did = '123456',
        ip = '192.168.1.64',
        username = 'admin',
        password = 'admin123456'
    }

    local webThing = {
        options = options
    }

    webThing.onvif = onvif.camera(options)
    loadCameraInformation(webThing, options)
end

exports.getStatus = function()
    local result = {}
    result.rtmp = rtmp.getRtmpStatus()
    result.rtsp = rtsp.getRtspStatus()
    return result
end

function exports.play(rtmpUrl)
    local urlString = rtmpUrl or 'rtmp://iot.beaconice.cn/live/test'
    local rtmpClient = rtmp.open('test', urlString, { isPlay = true })

    rtmpClient:on('startStreaming', function()
        rtmpClient.isStartStreaming = true
        console.log('startStreaming')
    end)
end

exports.createThing = createCameraThing

return exports
