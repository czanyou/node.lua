local app   = require('app')
local util  = require('util')
local url 	= require('url')
local fs 	= require('fs')
local path 	= require('path')
local http  = require('http')
local json  = require('json')
local wot   = require('wot')

local rtsp 	= require('rtsp')
local rtmp  = require('rtmp')

local TAG = 'media.rtsp'

local flv = rtmp.flv

local NALU_TYPE_I   	= 5
local NALU_TYPE_SPS 	= 7
local NALU_TYPE_PPS 	= 8
local NALU_TYPE_P   	= 1

-- ////////////////////////////////////////////////////////////////////////////
-- RTSP

local exports = {}

exports.rtspSessions = {}

local function getRtspSession(did)
    return exports.rtspSessions and exports.rtspSessions[did]
end

local function getRtspSessionStatus(rtspSession)
    local status = {}

    status.url = rtspSession.rtspUrl
    local rtspClient = rtspSession.rtspClient
    if (not rtspClient) then
        return status
    end

    status.lastActiveTime = rtspClient.lastActiveTime
    status.urlObject = rtspClient.urlObject
    status.rtspState = rtspClient.rtspState
    status.sentRequests = rtspClient.sentRequests
    --status.mediaTracks = rtspClient.mediaTracks

    status.lastCSeq = rtspClient.lastCSeq
    status.lastConnectTime = rtspClient.lastConnectTime
    status.id = rtspClient.id

    status.audioSamples = rtspClient.audioSamples
    status.audioTrack = rtspClient.audioTrack
    status.audioTrackId = rtspClient.audioTrackId
    status.videoSamples = rtspClient.videoSamples
    status.videoTrack = rtspClient.videoTrack
    status.videoTrackId = rtspClient.videoTrackId

    local sps, pps, error = rtspClient:getParameterSets()
    if (sps) then
        status.sps = util.bin2hex(sps)
        status.pps = util.bin2hex(pps)
    else
        status.sps = error
    end

    return status
end

local function getRtspStatus()
    if (not exports.rtspSessions) then
        return
    end

    local rtspSessions = {}
    for did, rtspSession in pairs(exports.rtspSessions) do
        rtspSessions[did] = getRtspSessionStatus(rtspSession)
    end
    return rtspSessions
end

local function closeRtspClient(did)
    local rtspSession = getRtspSession(did)
    local rtspClient = rtspSession and rtspSession.rtspClient
    if (rtspClient) then
        rtspClient:close()
    end
end

local function createRtspClient(rtspSession)
    -- console.log(rtspSession)
    
    local lastState = 0
    local lastSample = nil
    local rtspUrl = rtspSession.rtspUrl
    local options = rtspSession.options
    local did = rtspSession.did

    local rtspClient = rtsp.openURL(rtspUrl)
    rtspClient.username = options.username or 'admin';
    rtspClient.password = options.password or 'admin123456';

	rtspClient:on('close', function(err)
        console.log(TAG, 'close', err, rtspClient.id)

        rtspClient.spsSent = false
	end)

	rtspClient:on('error', function(err)
        console.log(TAG, 'error', err, rtspClient.id)
    end)

    rtspClient:on('state', function(state)
        local stateString = rtspClient:getRtspStateString(state)
        console.log(TAG, 'rtsp state', stateString)

        if (state == rtsp.client.STATE_READY) then
            local rtmp = exports.rtmp
            if (not rtmp) then
                console.log('Empty rtmp')
            end
    
            local mediaInfo = {}
            local width, height = rtspClient:getVideoSize()
            mediaInfo.width  = width or 1280
            mediaInfo.height = height or 720
            if (rtmp) then
                rtmp.setRtmpMediaInfo(did, mediaInfo)
            end
		end

		lastState = state
    end)

    rtspClient:on('sample', function(sample)
        if (not sample.isVideo) then
            return
        end

        local rtmp = exports.rtmp
        if (not rtmp) then
            console.log('Empty rtmp')
        end

        local now = process.hrtime() / 1000000 -- in ms
        rtspSession.rtspLastActiveTime = now;

        if (not lastSample) then
            lastSample = {}
        end

        local buffer = sample.data[1]
        if (not buffer) then
            return
        end

        -- console.log('sample', buffer)

        -- NALU
        if (sample.isFragment) then
            for _, item in ipairs(sample.data) do
                table.insert(lastSample, item)
            end

            if (not sample.isEnd) then
                return
            end
        else
            for _, item in ipairs(sample.data) do
                table.insert(lastSample, item)
            end
        end

        if (rtspClient.startSampleTime == nil) then
            rtspClient.startSampleTime = now
        end

        local timestamp = now
        timestamp = math.floor(timestamp - rtspClient.startSampleTime)

        local naluData = table.concat(lastSample)
        local naluType = naluData:byte(1) & 0x1f

        --console.log('naluData', #naluData)
        lastSample = nil

        -- console.log('naluType', naluType)
        if (naluType == NALU_TYPE_SPS) then
            --console.log('naluType', naluType, #naluData)
            rtspClient.sps = naluData
            --console.printBuffer(naluData)

        elseif (naluType == NALU_TYPE_PPS) then
            --console.log('naluType', naluType, #naluData)
            rtspClient.pps = naluData
            --console.printBuffer(naluData)

        elseif (naluType == NALU_TYPE_I) then
            -- console.log('naluType', naluType, #naluData, timestamp)

            if (rtspClient.sps and rtspClient.pps) then
                local sps = rtspClient.sps
                local pps = rtspClient.pps
                local tagData = flv.encodeVideoConfiguration(sps, pps)

                -- console.log(encodeVideoConfiguration, tagData)   
                if (rtmp) then
                    rtmp.setVideoConfiguration(did, tagData)
                end
            end

            -- video tag (Key frame)
            if (naluData) then
                local videoHeader = flv.encodeAvcHeader(naluType, naluData, timestamp)
                if (rtmp) then
                    rtmp.sendVideoMessage(did, videoHeader .. naluData, timestamp, true)
                end
            end

        elseif (naluType == NALU_TYPE_P) then
            -- console.log('naluType', naluType, #naluData, timestamp)

            -- video tag
            local videoHeader = flv.encodeAvcHeader(naluType, naluData, timestamp)
            if (rtmp) then
                rtmp.sendVideoMessage(did, videoHeader .. naluData, timestamp, false)
            end
        end
    end)

    return rtspClient
end

local function onRtspSessionTimer(rtspSession)
    local rtspClient = rtspSession.rtspClient
    local urlString = rtspSession.rtspUrl
    local now = process.hrtime() / 1000000; -- in ms
    if (not urlString) then
        return
    end

    if (not rtspClient) then
        rtspSession.rtspClient = createRtspClient(rtspSession)
        rtspSession.rtspLastActiveTime = now
        return
    end

    -- check stopped
    local rtspState = rtspClient.rtspState
    -- console.log('rtsp state', rtspState)

    if (rtspState == rtsp.client.STATE_STOPPED) then
        console.log('RTSP timeout', rtspClient.id)
        rtspClient:close()

        rtspSession.rtspClient = createRtspClient(rtspSession)
        rtspSession.rtspLastActiveTime = now
        return
    end

    -- check timeout
    local span = now - rtspSession.rtspLastActiveTime

    if (span >= 1000 * 10) then
        console.log('RTSP stream timeout', rtspClient.id)
        rtspClient:close()

        rtspSession.rtspClient = createRtspClient(rtspSession)
        rtspSession.rtspLastActiveTime = now
        return
    end
end

local function startRtspClient(rtmp, options)
    if (not exports.rtspSessions) then
        exports.rtspSessions = {}
    end

    if (not rtmp) then
        console.log('Empty rtmp')
    end

    local did = options.did
    if (not did) then
        console.log('Empty did')
    end

    exports.rtmp = rtmp

    local onRtspTimer = function()
        for _, rtspSession in pairs(exports.rtspSessions) do
            onRtspSessionTimer(rtspSession)
        end
    end

    local rtspSession = {}
    rtspSession.did = did
    rtspSession.rtspUrl = options.url
    rtspSession.options = options
    rtspSession.rtspLastActiveTime = process.hrtime() / 1000000 -- in ms

    rtspSession.rtspTimer = setInterval(1000 * 3, onRtspTimer)
    onRtspTimer()

    rtspSession.timeoutTimer = setInterval(1000 * 3600, function()
        closeRtspClient(did, 'rtsp reset')
    end)

    exports.rtspSessions[did] = rtspSession
    return rtspSession
end

exports.startRtspClient = startRtspClient
exports.getRtspStatus = getRtspStatus

return exports
