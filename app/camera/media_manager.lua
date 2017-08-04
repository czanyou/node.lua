local app       = require('app')
local conf      = require('ext/conf')
local fs        = require('fs')
local json      = require('json')
local path      = require('path')
local utils     = require('utils')

local camera    = require('media/camera')
local express   = require('express')
local session   = require('media/session')

local exports   = {}

-------------------------------------------------------------------------------
-- camera

local _getVideoMockFilename, _getSnapshotMockFilename, _probeCameraType
local _openCamera, _getCamera, _stopCameras
local _getCameraMockSettings, _getCameraSettings

local _cameraList = {}

function _getCamera(name)
    name = name or '1'
    local cameraDevice = _cameraList[name]
    if (not cameraDevice) then
        cameraDevice = _openCamera(name)
        if (not cameraDevice) then
            return
        end

        cameraDevice.mediaSessions = {}

        _cameraList[name] = cameraDevice
    end

    return cameraDevice   
end

function _getSnapshotMockFilename()
    local dirname   = path.dirname(utils.dirname())
    local filename  = path.join(dirname, "examples/test.jpg")
    return "mock:" .. filename
end

function _getVideoMockFilename()
    local dirname   = path.dirname(utils.dirname())
    return path.join(dirname, "examples/hd.ts")
end

function _getCameraSettings(name)
    name = name or "1"

    local options   = {}
    local profile = conf('camera')

    local category = 'video.' .. name .. '.'
    options.bitrate     = profile:get(category .. "bitrate")
    options.width       = profile:get(category .. "width")
    options.height      = profile:get(category .. "height")
    options.frameRate   = profile:get(category .. "framerate")

    --console.log(options)
    return options
end

function _getCameraMockSettings(name)
    print("start mock camera...")

    local options = _getCameraSettings(name)

    options.basePath    = utils.dirname()
    options.filename    = _getVideoMockFilename()
    options.bitrate     = 800
    options.width       = 640
    options.height      = 360
    options.frameRate   = 25
    return options
end

function _openCamera(name)
	local cameraId  = 0
    local mockImage = nil
    local mockVideo = nil
    local options   = {}

    local mode = _probeCameraType()
    if (not mode) then
        name = 'mock'
    end

	if (name == 'mock') then
		cameraId    = camera.CAMERA_MOCK
        options     = _getCameraMockSettings(name)

    else
        cameraId    = tonumber(name) or 1
        options     = _getCameraSettings(name)
	end

    --console.log(cameraId, options)
	return camera(cameraId, options)
end

-- CMPP8888@

function _probeCameraType()
    local mode = nil
    if (fs.existsSync('/dev/video0')) then
        mode = 'uvc' -- USB camera

    elseif (fs.existsSync('/dev/venc')) then
        mode = 'hi'  -- hi35xx camera
    end

    return mode
end

function _stopCameras()
    for name, cameraDevice in pairs(_cameraList) do
        if (cameraDevice) then
            cameraDevice:release()
            cameraDevice = nil
        end 
    end

    _cameraList = {}
end

-------------------------------------------------------------------------------
-- MediaSessionManager

local _stopMediaSession, _startMediaSession
local _mediaSessionIdCounter = 1
local _mediaSessionCount     = 0

function _startMediaSession(name)
    local cameraDevice = _getCamera(name)
    if (not cameraDevice) then
        return nil
    end


    if (not cameraDevice.mediaSessions) then
        cameraDevice.mediaSessions = {}
    end

    _mediaSessionIdCounter = _mediaSessionIdCounter + 1
    local mediaSessionId = _mediaSessionIdCounter
    local mediaSession = session.newMediaSession()

    mediaSession.name           = name
    mediaSession.camera         = cameraDevice
    mediaSession.mediaSessionId = mediaSessionId
    cameraDevice.mediaSessions[mediaSessionId] = mediaSession

    mediaSession.close = function(self)
        if (self.isClosed) then
            return
        end

        self.isClosed = true
        session.MediaSession.close(self)
        _stopMediaSession(self)
    end

    _mediaSessionCount = _mediaSessionCount + 1
    return mediaSession
end

function _stopMediaSession(mediaSession)
    if (not mediaSession) then
        return
    end

    mediaSession:readStop()
    mediaSession:close()

    local cameraDevice = mediaSession.camera
    mediaSession.camera = nil

    session.MediaSession.close(mediaSession)

    if (not cameraDevice) or (not cameraDevice.mediaSessions) then
        return
    end

    local mediaSessions = cameraDevice.mediaSessions

    if (mediaSessions[mediaSession.mediaSessionId]) then
        _mediaSessionCount = _mediaSessionCount - 1
        mediaSessions[mediaSession.mediaSessionId] = nil
    end

    --console.log('_stopMediaSession:', _mediaSessionCount)
end

function _writeMediaSession(mediaSessions, sample)
    if (not mediaSessions) then
        return
    end

    for _, session in pairs(mediaSessions) do
        session:writeSample(sample)
    end
end

-------------------------------------------------------------------------------
-- MediaManager

local _startMediaManager, _stopMediaManager, _startVideoStat
local _mainCamera            = nil
local _mediaAudioIn          = nil

local lastVideoSampleTime    = nil

local MediaSessionManager = {}

function _startAudioIn()
    -- [[
    local audio = require('media/audio')

    local profile  = conf('camera')
    local audioCardId = tonumber(profile:get("audio.in.id") or 0) or 2
    if (audioCardId < 0) then
    	print("camera: audio in is disabled.")
    	return
    end

    local sampleRate = profile:get("audio.in.sampleRate") or 8000
    local channels   = profile:get("audio.in.channels") or 1
    local codec      = profile:get("audio.in.codec")
    local disabled   = tonumber(profile:get("audio.in.disabled") or 0)
    if (disabled == 1) then
        return
    end

    print("Audio In: " .. audioCardId .. ", sample rate: " .. sampleRate .. ", chanenls: " .. channels)

    local options = {}
    options.codec      = audio.MEDIA_FORMAT_AAC
    options.sampleRate = sampleRate
    options.channels   = channels

    if (codec == 'PCM') then
        options.codec  = audio.MEDIA_FORMAT_PCM
        print("Audio In: PCM")
    end

    local audioIn = audio.openAudioIn(audioCardId, options, function(sample)
        sample.sampleTime = lastVideoSampleTime or sample.sampleTime -- test only
        
        --print('audio', sample.sampleTime, #sample.sampleData)

        sample.codec = options.codec
        _writeMediaSession(nil, sample)
        
    end)

    _mediaAudioIn = audioIn

    --]]
end


function _startVideoStat(name)
    local totalBytes    = 0
    local totalFrames   = 0
    local lastTime      = process.now()
    local index         = 0

    local grid = app.table({8, 8, 12, 12, 8, 12})
    
    return function(sample)
        totalBytes  = totalBytes + #sample.sampleData
        totalFrames = totalFrames + 1
        
        if (not sample.syncPoint) then
            return
        end

        -- console.log(sample)
        local interval = process.now() - lastTime
        if (interval < 1000) then
            return
        end

        if (index % 20 == 0) then
            grid.line()
            grid.cell('channel', 'index', 'ts', 'bitrate', 'fps', 'interval')
            grid.line('=')
        end

        local bitrate = (totalBytes * 1000) // interval
        local framteRate = (totalFrames * 1000 + 500) // interval
        grid.cell(name, index, sample.sampleTime / 1000000, 
            bitrate, framteRate, interval)

        totalBytes  = 0
        totalFrames = 0
        lastTime    = process.now()
        index       = index + 1
    end
end


function _startVideoIn(name)
    local cameraDevice = _getCamera(name)
    if (not cameraDevice) then
        print('camera open failed!')
        return
    end

    local stat = _startVideoStat(name)

    cameraDevice:startPreview(function(sample)
        if (sample.isAudio) then
        	if (_mediaAudioIn) then
            	return
            end
        end

        if sample.isAudio then
        	--print('audio', sample.sampleTime, sample.isSync)
        else
        	--print('video', sample.sampleTime, sample.isSync)
        end
        lastVideoSampleTime = sample.sampleTime;

        _writeMediaSession(cameraDevice.mediaSessions, sample)
        
        stat(sample)
    end)

    return cameraDevice
end

function _startMediaManager(name)
    if (_mainCamera ~= nil) then
        return
    end

    local ret, lmedia = pcall(require, 'lmedia')
    local ltype = lmedia.TYPE or ''
    --console.log(lmedia.TYPE)

    if (name == 'mock') then
   		_startVideoIn(name)
   		_startAudioIn()

    else
        if (ltype == 'hi3516a') then
            _mainCamera = _startVideoIn("1")
            _startVideoIn("2")
            _startVideoIn("3")

        else
            _mainCamera = _startVideoIn(name)
        end

    	--_startAudioIn()
    end
end

function _stopMediaManager(name)
    if (_mainCamera) then
        _mainCamera:stopPreview()
    end

    if (_mediaAudioIn) then
        _mediaAudioIn:stop()
    end
end


-------------------------------------------------------------------------------
-- exports


function exports.init(name)
	return _startMediaManager(name)
end

function exports.getMediaSession(name)
	return _startMediaSession(name)
end

function exports.stopMediaSession(mediaSession)
	return _stopMediaSession(mediaSession)
end

function exports.snapshot(callback)
	if (not _mainCamera) then
		callback(nil)
		return
	end

	return _mainCamera:takePicture(callback)
end

function exports.getCamera(name)
	return _getCamera(name)
end

function exports.release()
	_stopCameras()
end

function exports.list() 
    print("Available cameras:")

    local filename = _getVideoMockFilename()
    if (fs.existsSync(filename)) then
        print("- mock")
    end

    local type = _probeCameraType()
    if (type == 'uvc') then
        print("- 1 (snapshot only)")

    elseif (type == 'nanopi') then
        print("- 1 (h.264)")

    elseif (type == 'hi') then
        print("- 1 (jpeg and h.264)")
    end
end


return exports
