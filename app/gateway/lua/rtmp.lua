local app   = require('app')
local rtmp  = require('rtmp')
local util  = require('util')
local url 	= require('url')
local fs 	= require('fs')
local path 	= require('path')
local core 	= require('core')
local rtsp  = require('rtsp')
local http  = require('http')
local json  = require('json')
local wot   = require('wot')
local request = require('http/request')
local client  = require('rtmp/client')
local Promise = require('wot/promise')

local TAG = 'media.rtmp'

local RTMPClient = client.RTMPClient

local flv = rtmp.flv

local exports = {}

exports.rtmpSessions = {}

local function getRtmpSession(did, create)
    create = true

    local rtmpSession = exports.rtmpSessions[did]
    if (not rtmpSession) and (create) then
        rtmpSession = {}
        exports.rtmpSessions[did] = rtmpSession
    end

    return rtmpSession;
end


-- ////////////////////////////////////////////////////////////////////////////
-- Snapshot

local function saveSnapshot(did, videoConfiguration, body, timestamp)
    local rtspSession = getRtmpSession(did)
    local now = process.now()
    local span = now - (rtspSession.lastSnapshotTime or 0)
    if (span < 3600 * 1000) then
        return
    end

    local did = rtspSession.did
    if (not did) then
        return
    end

    rtspSession.lastSnapshotTime = now;

    local filePath = os.tmpdir .. '/snapshot.flv'
    os.remove(filePath)

    local imagePath = os.tmpdir .. '/snapshot.jpg'
    os.remove(imagePath)

    console.log(#videoConfiguration, #body, timestamp);

    local stream = fs.createWriteStream(filePath)
    stream:on('finish', function()
        console.log('finish');

        local imageSize = '640x360';
        local cmdline = 'ffmpeg -y -i ' .. filePath .. ' -ss 00:00:00 -vframes 1 ' ..
            '-f image2 -s ' .. imageSize .. ' ' .. imagePath .. ''
        local ret, err = os.execute(cmdline)
        console.log('ret', ret, err);

        local fileData = fs.readFileSync(imagePath);
        console.log('did', did, #fileData);

        local dateString = os.date("%Y%m%d-%H%M%S")
        local files = {
            did = did,
            file = {
                name = did .. '-' .. (dateString or '') .. '.jpg',
                data = fileData,
                contentType = 'image/jpeg'
            }
        }

        local urlString = 'http://iot.beaconice.cn/v2/storage/upload/snapshot';
        --local urlString = 'http://127.0.0.1:8905/upload/test';
        urlString = urlString .. '?did=' .. did;

        console.log('urlString', urlString);
        request.post(urlString, { files = files }, function(err, response, body)
            print('body:', err, body)
        end)
    end)

    local fileHeader = flv.encodeFileHeader()
    stream:write(fileHeader)

    local lastTagSize = 0

    if (videoConfiguration) then
        local tagData = videoConfiguration
        local tagSize = #videoConfiguration

        -- metadata tag
        local header = flv.encodeTagHeader(0x09, tagSize, lastTagSize)
        stream:write(header)

        stream:write(tagData)
        lastTagSize = tagSize
    end

    if (body) then
        local tagData = body
        local tagSize = #body
        local tagTime = 0

        -- console.log(i, tagTime, tagSize);

        -- video tag
        local header = flv.encodeTagHeader(0x09, tagSize, lastTagSize, tagTime)
        stream:write(header)

        stream:write(tagData)
        lastTagSize = tagSize
    end

    stream:finish()
end

-- ////////////////////////////////////////////////////////////////////////////
-- RTMP

local function sendMetadataMessage(did, meta)
    local rtspSession = getRtmpSession(did)

    local metadata = {
        copyright = 'anyou',
        width = meta.width or 1280,
        height = meta.height or 720,
        framerate = 25,
        videocodecid = 7,
        --audiosamplerate = 8000,
        --audiocodecid = 10
    }

    local rtmpClient = rtspSession.rtmpClient
    if (rtmpClient) then
        rtmpClient.metadata = metadata
        rtmpClient:sendMetadataMessage()
    end
end

local function sendVideoMessage(did, frameBuffer, timestamp, isSyncPoint)
    local rtmpSession = getRtmpSession(did)
    if (isSyncPoint) then
        local parameterSets = rtmpSession.videoConfiguration
        saveSnapshot(did, parameterSets, frameBuffer, timestamp);
    end

    if (isSyncPoint) then
        if (rtmpSession.rtmpWaitSync) then
            rtmpSession.rtmpWaitSync = false
        end
    else
        if (rtmpSession.rtmpWaitSync) then
            return
        end
    end

    local rtmpClient = rtmpSession.rtmpClient
    if (not rtmpClient) then
        return

    elseif (not rtmpClient.isStartStreaming) then
        return
    end

    rtmpClient.videoConfiguration = rtmpSession.videoConfiguration
    rtmpClient:sendVideo(frameBuffer, timestamp, isSyncPoint)

    -- console.log('sendVideoMessage', did, isSyncPoint)
end

local function stopRtmpClient(did, error)
    local rtmpSession = getRtmpSession(did)
    if (rtmpSession.rtmpClient) then
        local rtmpClient = rtmpSession.rtmpClient
        rtmpSession.rtmpClient = nil
        rtmpSession.rtmpUrl = nil
        rtmpClient:close(error)
    end
end

local function closeRtmpClient(did, error)
    local rtmpSession = getRtmpSession(did)
    if (rtmpSession.rtmpClient) then
        local rtmpClient = rtmpSession.rtmpClient
        rtmpSession.rtmpClient = nil
        rtmpClient:close(error)
    end
end

local function createRtmpClient(did, urlString, options)
    local rtmpSession = getRtmpSession(did)
    if (rtmpSession.rtmpClient) then
        return
    end

    local rtmpClient = RTMPClient:new()
    if (options and options.rtmpIsPlay) then
        -- 拉流模式 (播放模式)
        rtmpClient.isPublish = false
    end

    console.log('connect', urlString)
    rtmpClient:connect(urlString)

    rtmpClient:on('close', function()
        console.log('close', rtmpClient.id)
    end)

    rtmpClient:on('error', function(error)
        console.log('error', error, rtmpClient.id)
    end)

    rtmpClient:on('connect', function()
        console.log('connect', rtmpClient.id)
    end)

    rtmpClient:on('state', function(state)
        console.log('rtmp state', rtmpClient:getStateString(state))

        if (state == client.STATE_CONNECTED) then
            rtmpClient:sendCreateStream()

        elseif (state == client.STATE_CREATE_STREAM) then
            if (rtmpClient.isPublish) then
                rtmpClient:sendPublish()
            else
                rtmpClient:sendPlay()
            end
        end
    end)

    rtmpClient:on('startStreaming', function()
        rtmpClient.isStartStreaming = true
        console.log('startStreaming', rtmpClient.id)

        sendMetadataMessage(did, rtmpSession.rtmpMediaInfo or {})
    end)

    rtmpClient:on('command', function(header, body)
        -- console.log('command', header, body)
    end)

    rtmpClient:on('metadata', function(header, body)
        console.log('metadata', header, body)
    end)

    -- video
    local lastTimestamp = 0

    rtmpClient:on('video', function(header, body, raw)
        --console.log('video', header.fmt, header.chunkStreamId, header.messageLength, header.timestamp)
        --console.printBuffer(raw)

        local interval = header.timestamp - lastTimestamp
        lastTimestamp = header.timestamp

        local ret = flv.decodeVideoTag(raw)
        if (ret.pps) then
            console.log('video', header.fmt, header.messageLength, interval,
                ret.frameType, ret.codecType, ret.packetType, ret.avcProfile, ret.profileCompatibility, ret.avcLevel)
            console.printBuffer(ret.pps)
            console.printBuffer(ret.sps)
        else
            console.log('video', header.fmt, header.messageLength, interval,
                ret.frameType, ret.codecType, ret.packetType, ret.timestamp, header.messageLength - ret.naluLength)
        end
    end)

    return rtmpClient
end

local function getRtmpSessionStatus(did)
    local rtmpSession = getRtmpSession(did)
    local status = { url = rtmpSession.rtmpUrl }
    local rtmpClient = rtmpSession.rtmpClient
    if (not rtmpClient) then
        return status
    end

    status.lastActiveTime = rtmpClient.lastActiveTime
    status.appName = rtmpClient.appName
    status.streamName = rtmpClient.streamName
    status.streamId = rtmpClient.streamId
    status.urlObject = rtmpClient.urlObject
    status.isPublish = rtmpClient.isPublish

    status.connected = rtmpClient.connected
    status.id = rtmpClient.id
    status.isStartStreaming = rtmpClient.isStartStreaming
    status.lastError = rtmpClient.lastError
    status.isNotDrain = rtmpClient.isNotDrain
    status.videoConfigurationSent = rtmpClient.videoConfigurationSent

    status.startTime = rtmpClient.startTime
    status.windowAckSize = rtmpClient.windowAckSize
    status.peerChunkSize = rtmpClient.peerChunkSize
    status.metadata = rtmpClient.metadata
    status.videoSamples = rtmpClient.videoSamples
    status.audioSamples = rtmpClient.audioSamples

    return status
end

function onRtmpSessionTimer(did)
    local rtmpSession = getRtmpSession(did)

    local now = process.now()

    if (not rtmpSession.rtmpClient) then
        local urlString = rtmpSession.rtmpUrl
        if (not urlString) then
            return
        end

        local rtmpClient = createRtmpClient(did, urlString)
        if (rtmpClient) then
            rtmpClient:on('startStreaming', function()
                rtmpSession.rtmpWaitSync = true
            end)

            rtmpSession.rtmpWaitSync = true
            rtmpSession.rtmpClient = rtmpClient
        end

    else
        local span = now - (rtmpSession.lastNotifyTime or 0)
        if (span > 1000 * 120) then
            return stopRtmpClient(did, 'play timeout')
        end

        local rtmpClient = rtmpSession.rtmpClient
        local rtmpState = rtmpClient.state
        -- console.log('rtmp state', rtmpState)

        if (rtmpState == client.STATE_STOPPED) then
            return closeRtmpClient(did, 'reboot')
        end

        local span = now - rtmpClient.lastActiveTime
        if (span > 1000 * 30) then
            return closeRtmpClient(did, 'rtmp active timeout')
        end
    end
end

local function getRtmpStatus()
    local sessions = {}
    for did, rtmpSession in pairs(exports.rtmpSessions) do
        sessions[did] = getRtmpSessionStatus(did, rtmpSession);
    end
    return sessions
end

local function startRtmpClient()
    local onRtmpTimer = function() 
        for did, rtmpSession in pairs(exports.rtmpSessions) do
            onRtmpSessionTimer(did, rtmpSession);
        end
    end
    
    exports.rtmpTimer = setInterval(1000 * 5, onRtmpTimer)
    onRtmpTimer()

    exports.rtmpResetTimer = setInterval(1000 * 3600, function()
        for did, rtmpSession in pairs(exports.rtmpSessions) do
            closeRtmpClient(did, 'rtmp reset')
        end
    end)
end

local function setRtmpMediaInfo(did, mediaInfo)
    local rtmpSession = getRtmpSession(did)
    console.log('setRtmpMediaInfo', did, mediaInfo)
    rtmpSession.rtmpMediaInfo = mediaInfo
end

local function setVideoConfiguration(did, videoConfiguration)
    local rtmpSession = getRtmpSession(did)
    if (not rtmpSession.videoConfiguration) then
        console.log('setVideoConfiguration', did, videoConfiguration)
    end
    rtmpSession.videoConfiguration = videoConfiguration
end

local function publishRtmpUrl(did, rtmpUrl)
    local now = process.now()

    local rtmpSession = getRtmpSession(did)
    rtmpSession.rtmpUrl = rtmpUrl;
    rtmpSession.lastNotifyTime = now;

    onRtmpSessionTimer(did);

    console.log('publishRtmpUrl', did, rtmpUrl)
end

exports.getRtmpSession = getRtmpSession
exports.getRtmpStatus = getRtmpStatus
exports.open = createRtmpClient
exports.publishRtmpUrl = publishRtmpUrl
exports.sendVideoMessage = sendVideoMessage
exports.setRtmpMediaInfo = setRtmpMediaInfo
exports.setVideoConfiguration = setVideoConfiguration
exports.startRtmpClient = startRtmpClient
exports.stopRtmpClient = stopRtmpClient

return exports
