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

local TAG = 'PUSHER'

local RTMPClient = client.RTMPClient

local flv = rtmp.flv

local exports = {}

local RtmpSession = {}
RtmpSession.rtmpClient    = nil
RtmpSession.rtmpTimer     = nil
RtmpSession.rtspClient    = nil
RtmpSession.rtspTimer     = nil
RtmpSession.videoConfiguration = nil
RtmpSession.mediaInfo     = {}

local NALU_TYPE_I   	= 5
local NALU_TYPE_SPS 	= 7
local NALU_TYPE_PPS 	= 8
local NALU_TYPE_P   	= 1

-- ////////////////////////////////////////////////////////////////////////////
-- RTMP

function sendMetadataMessage(meta)
    local metadata = {
        copyright = 'anyou',
        width = meta.width or 1280,
        height = meta.height or 720,
        framerate = 25,
        videocodecid = 7,
        --audiosamplerate = 8000,
        --audiocodecid = 10
    }

    local rtmpClient = RtmpSession.rtmpClient
    if (rtmpClient) then
        rtmpClient.metadata = metadata
        rtmpClient:sendMetadataMessage()
    end
end

function saveSnapshot(videoConfiguration, body, timestamp)
    local now = process.now()
    local span = now - (RtmpSession.lastSnapshotTime or 0)
    if (span < 3600 * 1000) then
        return
    end

    local did = RtmpSession.did
    if (not did) then
        return
    end

    RtmpSession.lastSnapshotTime = now;

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

function sendVideoMessage(body, timestamp, isSyncPoint)
    if (false) then return end

    if (isSyncPoint) then
        saveSnapshot(RtmpSession.videoConfiguration, body, timestamp);
    end

    local rtmpClient = RtmpSession.rtmpClient
    if (not rtmpClient) then
        return

    elseif (not rtmpClient.isStartStreaming) then
        return
    end

    rtmpClient.videoConfiguration = RtmpSession.videoConfiguration
    rtmpClient:sendVideo(body, timestamp, isSyncPoint)
end

function closeRtmpClient(error)
    if (RtmpSession.rtmpClient) then
        local rtmpClient = RtmpSession.rtmpClient
        RtmpSession.rtmpClient = nil
        rtmpClient:close(error)
    end
end

function createRtmpClient(urlString)
    if (RtmpSession.rtmpClient) then
        return
    end

    local rtmpClient = RTMPClient:new()
    if (RtmpSession.rtmpIsPlay) then
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

        sendMetadataMessage(RtmpSession.rtmpMediaInfo or {})
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

 function getRtmpStatus()
    local status = { url = RtmpSession.rtmpUrl }
    local rtmpClient = RtmpSession.rtmpClient
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

function onRtmpTimer()
    local session = getPushSession()

    local now = process.now()
    local rtmpPlayers = session.rtmpPlayers or 0

    if (not session.rtmpClient) then
        local span = now - (session.lastNotifyTime or 0)
        if (span > 1000 * 60) and (rtmpPlayers <= 0) then
            -- console.log('onRtmpTimer', span, rtmpPlayers);
            -- 没有正在播放的客户端
            return
        end

        local urlString = session.rtmpUrl
        if (not urlString) then
            return
        end

        local rtmpClient = createRtmpClient(urlString)
        if (rtmpClient) then
            rtmpClient:on('startStreaming', function()
                session.rtmpWaitSync = true
            end)

            session.rtmpWaitSync = true
            session.rtmpClient = rtmpClient
        end

    else
        local span = now - (session.lastNotifyTime or 0)
        if (span > 1000 * 120) then
            return closeRtmpClient('notify timeout')
        end

        local rtmpClient = session.rtmpClient
        local rtmpState = rtmpClient.state
        -- console.log('rtmp state', rtmpState)

        if (rtmpState == client.STATE_STOPPED) then
            return closeRtmpClient('reboot')
        end

        local span = now - rtmpClient.lastActiveTime
        if (span > 1000 * 30) then
            return closeRtmpClient('rtmp active timeout')
        end
    end
end

function startRtmpClient()
    local session = getPushSession()

    session.rtmpTimer = setInterval(1000 * 5, onRtmpTimer)
    onRtmpTimer()

    session.rtmpResetTimer = setInterval(1000 * 600, function()
        closeRtmpClient('rtmp reset')
    end)
end

function getPushSession()
    return RtmpSession
end

function setRtmpMediaInfo(mediaInfo)
    local session = getPushSession()
    session.rtmpMediaInfo = mediaInfo
    console.log('mediaInfo', mediaInfo)
end

-- ////////////////////////////////////////////////////////////////////////////
-- RTSP

function getRtspStatus()
    local status = {}

    status.url = RtmpSession.rtspUrl
    local rtspClient = RtmpSession.rtspClient
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

function closeRtspClient()
    local rtspClient = RtmpSession.rtspClient
    if (rtspClient) then
        rtspClient:close()
    end
end

function createRtspClient(rtspUrl)
    local lastState = 0
    local lastSample = nil

    local rtspClient = rtsp.openURL(rtspUrl)
    rtspClient.username = 'admin';
    rtspClient.password = 'admin123456';

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
            local mediaInfo = {}
            local width, height = rtspClient:getVideoSize()
            mediaInfo.width  = width or 1280
            mediaInfo.height = height or 720
            setRtmpMediaInfo(mediaInfo)
		end

		lastState = state
    end)

    rtspClient:on('sample', function(sample)
        if (not sample.isVideo) then
            return
        end

        local now = process.hrtime() / 1000000 -- in ms
        RtmpSession.rtspLastActiveTime = now;

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

        -- print('naluType', naluType)
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

            if (RtmpSession.rtmpWaitSync) then
                RtmpSession.rtmpWaitSync = false
            end

            if (rtspClient.sps and rtspClient.pps) then
                local sps = rtspClient.sps
                local pps = rtspClient.pps
                local tagData = flv.encodeVideoConfiguration(sps, pps)
                RtmpSession.videoConfiguration = tagData
            end

            -- video tag (Key frame)
            if (naluData) then
                local videoHeader = flv.encodeAvcHeader(naluType, naluData, timestamp)
                sendVideoMessage(videoHeader .. naluData, timestamp, true)
            end

        elseif (naluType == NALU_TYPE_P) then
            -- console.log('naluType', naluType, #naluData, timestamp)

            if (RtmpSession.rtmpWaitSync) then
                return
            end

            -- video tag
            local videoHeader = flv.encodeAvcHeader(naluType, naluData, timestamp)
            sendVideoMessage(videoHeader .. naluData, timestamp, false)
        end
    end)

    return rtspClient
end

function onRtspTimer()
    local rtspClient = RtmpSession.rtspClient
    local urlString = RtmpSession.rtspUrl
    local now = process.hrtime() / 1000000; -- in ms
    if (not urlString) then
        return
    end

    if (not rtspClient) then
        RtmpSession.rtspClient = createRtspClient(urlString)
        RtmpSession.rtspLastActiveTime = now
        return
    end

    -- check stopped
    local rtspState = rtspClient.rtspState
    -- console.log('rtsp state', rtspState)

    if (rtspState == rtsp.client.STATE_STOPPED) then
        console.log('RTSP timeout', rtspClient.id)
        rtspClient:close()

        RtmpSession.rtspClient = createRtspClient(urlString)
        RtmpSession.rtspLastActiveTime = now
        return
    end

    -- check timeout
    local span = now - RtmpSession.rtspLastActiveTime

    if (span >= 1000 * 10) then
        console.log('RTSP stream timeout', rtspClient.id)
        rtspClient:close()

        RtmpSession.rtspClient = createRtspClient(urlString)
        RtmpSession.rtspLastActiveTime = now
        return
    end
end

function startRtspClient(urlString)
    RtmpSession.rtspUrl = urlString
    RtmpSession.rtspLastActiveTime = process.hrtime() / 1000000 -- in ms

    RtmpSession.rtspTimer = setInterval(1000 * 3, onRtspTimer)
    onRtspTimer()

    RtmpSession.rtmpTimer = setInterval(1000 * 3600, function()
        closeRtspClient('rtsp reset')
    end)
end

-- ////////////////////////////////////////////////////////////////////////////
-- Web Server

function createHttpServer()
    local server = http.createServer(function(req, res)
        -- console.log(req.url, req.method)

        local result = {}
        result.rtmp = getRtmpStatus()
        result.rtsp = getRtspStatus()

        local body = json.stringify(result)
        res:setHeader("Content-Type", "application/json")
        res:setHeader("Content-Length", #body)
        res:finish(body)
    end)

    server:listen(8000, function()

    end)
end

-- ////////////////////////////////////////////////////////////////////////////
-- Notify

exports.lastGatewayStatus = {}
local cpuInfo = {}

function getMacAddress()
    local faces = os.networkInterfaces()
    if (faces == nil) then
    	return
    end

	local list = {}
    for k, v in pairs(faces) do
        if (k == 'lo') then
            goto continue
        end

        for _, item in ipairs(v) do
            if (item.family == 'inet') then
                list[#list + 1] = item
            end
        end

        ::continue::
    end

    if (#list <= 0) then
    	return
    end

    local item = list[1]
    if (not item.mac) then
    	return
    end

    return util.bin2hex(item.mac)
end

function getCpuUsage()
    local data = fs.readFileSync('/proc/stat')
    if (not data) then
        return 0
    end

    local list = string.split(data, '\n')
    local d = string.gmatch(list[1], "%d+")

    local totalCpuTime = 0;
    local x = {}
    local i = 1
    for w in d do
        totalCpuTime = totalCpuTime + w
        x[i] = w
        i = i +1
    end

    local totalCpuUsedTime = x[1] + x[2] + x[3] + x[6] + x[7] + x[8] + x[9] + x[10]

    local cpuUsedTime = totalCpuUsedTime - cpuInfo.used_time
    local cpuTotalTime = totalCpuTime - cpuInfo.total_time

    cpuInfo.used_time = math.floor(totalCpuUsedTime) --record
    cpuInfo.total_time = math.floor(totalCpuTime) --record

    if (cpuTotalTime == 0) then
        return 0
    end

    local cpuUserPercent = math.floor(cpuUsedTime / cpuTotalTime * 100)
    return cpuUserPercent
end

function onGatewayEventNotify(name, data)
    local event = {}

    event[name] = data

    local wotClient = RtmpSession.wotClient;
    if (wotClient) then
        wotClient:sendEvent(event)
        return
    end
end

function onGatewayDeviceNotify()
    local device = {}

    device.manufacturer = 'TDK'
    device.modelNumber = 'DT02'
    device.serialNumber = getMacAddress()
    device.firmwareVersion = '1.0'
    device.hardwareVersion = '1.0'

    local wotClient = RtmpSession.wotClient;
    if (wotClient) then
        wotClient:sendProperty({ device = device })
        return
    end
end

function onGatewayStatusNotify()
    local result = {}
    result.memoryFree = math.floor(os.freemem() / 1024)
    result.memoryTotal = math.floor(os.totalmem() / 1024)
    result.cpuUsage = getCpuUsage()

    local rtmpClient = RtmpSession.rtmpClient
    if (rtmpClient) then
        result.rtmpSamples = rtmpClient.videoSamples
        result.rtmpId = rtmpClient.id
    end

    local rtspClient = RtmpSession.rtspClient
    if (rtspClient) then
        result.rtspId = rtspClient.id
    end

    local wotClient = RtmpSession.wotClient;
    if (wotClient) then
        wotClient:sendStream(result)
        return
    end
end

-- ////////////////////////////////////////////////////////////////////////////
--

function exports.notify()
    cpuInfo.used_time = 0;
    cpuInfo.total_time = 0;

    setInterval(1000 * 15, function()
        onGatewayStatusNotify()
    end)

    setInterval(1000 * 3600, function()
        onGatewayDeviceNotify()
    end)
end

function exports.play(rtmpUrl)
    RtmpSession.rtmpIsPlay = true

    local urlString = rtmpUrl or 'rtmp://iot.beaconice.cn:1935/live/test'
    local rtmpClient = createRtmpClient(urlString)

    rtmpClient:on('startStreaming', function()
        rtmpClient.isStartStreaming = true
        console.log('startStreaming')
    end)
end

function exports.test()
    local urlString = 'rtmp://iot.beaconice.cn:1935/live/test'
    local rtmpClient = createRtmpClient(urlString)
end

function exports.start()
    exports.rtmp()
    exports.rtsp()
    exports.register()
end

function exports.rtmp()
    local config = exports.config()

    startRtmpClient();
end

function exports.rtsp()
    local config = exports.config()

    RtmpSession.did = config.did
    startRtspClient(config.rtsp);
    createHttpServer();
end

function exports.config()
    if (RtmpSession.config) then
        return RtmpSession.config
    end

    local filename = path.join(util.dirname(), '../config/config.json')
    local filedata = fs.readFileSync(filename)
    local config = json.parse(filedata)

    RtmpSession.config = config or {}

    if (not config.did) then
        config.did = getMacAddress();
    end

    -- console.log(RtmpSession)
    return config
end

-- 注册 WoT 客户端
function exports.register()
    local config = exports.config()
    local gateway = { id = config.did }
    console.log('config', config);

    local webThing = wot.produce(gateway)

    -- play action
    local play = { input = { type = 'object' } }
    webThing:addAction('play', play, function(input)
        console.log('play', 'input', input)

        local players = input and input.players
        local url = input and input.url
        local now = process.now()

        RtmpSession.players = players or 0;
        RtmpSession.rtmpUrl = url;
        RtmpSession.lastNotifyTime = now;

        onRtmpTimer();

        -- promise
        local promise = Promise.new()
        setTimeout(0, function()
            promise:resolve({ code = 0 })
        end)

        return promise
    end)

    -- stop action
    local stop = { input = { type = 'object' } }
    webThing:addAction('stop', stop, function(input)
        console.log('stop', input);

        closeRtmpClient('stoped');

        -- promise
        local promise = Promise.new()
        setTimeout(0, function()
            promise:resolve({ code = 0 })
        end)

        return promise
    end)

    -- ptz action
    local ptz = { input = { type = 'object'} }
    webThing:addAction('ptz', ptz, function(input)
        console.log('ptz', input);

        return { code = 0 }
    end)

    -- preset action
    local ptz = { input = { type = 'object'} }
    webThing:addAction('preset', ptz, function(input)
        console.log('preset', input);

        return { code = 0 }
    end)    

    -- play event
    local event = { type = 'object' }
    webThing:addEvent('play', event)

    -- properties
    webThing:addProperty('test', { type = 'number' })

    -- register
    local url = "mqtt://iot.beaconice.cn/"
    local wotClient = wot.register(url, webThing)
    wotClient:on('register', function(result)
        console.log('register', result)
    end)

    RtmpSession.did = config.did
    RtmpSession.wotClient = wotClient

    -- report stream
    exports.notify()
end

app(exports)
