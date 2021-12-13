local rtmp = require("rtmp")

local client = require("rtmp/client")
local rtsp = require('rtsp/client')

local RtspClient = rtsp.RtspClient
local videStreamIndex = 1
local rtmpClient = nil

local function sendMetadataMessage()
    local metadata = {
        audiocodecid = 10,
        audiosamplerate = 44100,
        copyright = 'EasyRTMP',
        framerate = 20,
        height = 576,
        videocodecid = 7,
        width = 320
    }

    console.log('sendMetadataMessage', metadata)

    local array = { '@setDataFrame', 'onMetaData', metadata }
    local options = { fmt = 0x00, chunkStreamId = 0x04 }
    local message = rtmp.encodeDataMessage(array, options)
    rtmpClient:sendData(message)
end

---@param naluData string - H.264 NALU data
---@param timestamp integer - in ms
---@param isSyncPoint boolean
local function sendVideoSample(naluData, timestamp, isSyncPoint)
    if (not naluData) then
        return
    end

    if (not rtmpClient) or (not rtmpClient.isStartStreaming) then
        return
    end

    console.log('sendVideoSample', timestamp, isSyncPoint)
    rtmpClient:sendVideo(naluData, timestamp, isSyncPoint)
end

---@param naluData string - H.264 NALU Data
---@param timestamp integer - in ms
local function onAvcVideoSample(naluData, timestamp)
    local NALU_TYPE_I   	= 5
    local NALU_TYPE_SPS 	= 7
    local NALU_TYPE_PPS 	= 8
    local NALU_TYPE_P   	= 1

    local naluType = naluData:byte(1) & 0x1f

    -- console.log('naluData', naluType, #naluData, sample.isFragment, sample.isEnd)

    -- console.log('naluType', naluType)
    if (naluType == NALU_TYPE_SPS) then
        --console.log('naluType', naluType, #naluData)
        rtmpClient.sps = naluData
        --console.printBuffer(naluData)

    elseif (naluType == NALU_TYPE_PPS) then
        -- console.log('naluType', naluType, #naluData)
        rtmpClient.pps = naluData
        -- console.printBuffer(naluData)

    elseif (naluType == NALU_TYPE_I) then
        -- console.log('naluType', naluType, #naluData, timestamp)

        if (rtmpClient.sps and rtmpClient.pps) then
            local sps = rtmpClient.sps
            local pps = rtmpClient.pps
 
            console.log('encodeVideoConfiguration', sps, pps)
            rtmpClient.videoParameterSets = { sps = sps, pps = pps }
        end

        -- video tag (Key frame)
        sendVideoSample(naluData, timestamp, true)

    elseif (naluType == NALU_TYPE_P) then
        sendVideoSample(naluData, timestamp, false)
    end
end

local rtspClient

local function startRtspClient()
    rtspClient = RtspClient:new()

	rtspClient:on('close', function(err)
		print('rtsp.close', err)
	end)

	rtspClient:on('error', function(err)
		print('rtsp.error', err)
    end)

    -- state
    local lastState = 0

    ---@param state integer
    local onStateChange = function(state)
		print('state = ' .. state)

		if (state == client.STATE_READY) then
            console.log('mediaTracks', rtspClient.mediaTracks);
            console.log('isMpegTSMode', rtspClient.isMpegTSMode);
		end

		lastState = state
    end

    rtspClient:on('state', onStateChange)

    -- sample
    local lastSample = nil;

    ---@param sample MediaSample
    local onSample = function(sample)
        if (not sample) or (not sample.isVideo) then
            return

        elseif (not sample.data) or (not sample.data[1]) then
            return
        end

        if (not lastSample) then
            lastSample = {}
        end

        -- NALU data
        for _, item in ipairs(sample.data) do
            table.insert(lastSample, item)
        end

        if (sample.isFragment) then
            if (not sample.isEnd) then
                return
            end
        end

        local naluData = table.concat(lastSample)

        -- timestamp
        local now = process.hrtime() / 1000000 -- in ms

        if (rtspClient.startSampleTime == nil) then
            rtspClient.startSampleTime = now
        end

        local timestamp = now
        timestamp = math.floor(timestamp - rtspClient.startSampleTime)

        onAvcVideoSample(naluData, timestamp)
        lastSample = nil
    end

    rtspClient:on('sample', onSample)

    -- open camera
    local url = 'rtsp://192.168.1.64/live.mp4'
    rtspClient.username = 'admin';
    rtspClient.password = 'admin123456';

    -- nvr
    -- type 0: 主码流, 1: 子码流
    -- id 通道号
    -- url = 'rtsp://192.168.31.108:554/type=1&id=1'

    -- vcr
    --
    -- url = 'rtsp://192.168.31.108:554/id=1&type=0&pic=0&Disk=0&Part=0&Clus=6055&record=20200405173923_20200405235959&pos=Local'

    url = 'rtsp://iot.wotcloud.cn:10554/live.mp4'
    rtspClient.password = 'admin123456';
    rtspClient:open(url)
end

local function onStartStreaming()
    console.log('startStreaming')

    startRtspClient()
end

local function startRtmpClient()
    console.log('start rtmp clent...')

    local urlString = 'rtmp://iot.wotcloud.cn/live/test'

    local RTMPClient = client.RTMPClient

    rtmpClient = RTMPClient:new()
    rtmpClient:connect(urlString)

    rtmpClient:on('startStreaming', onStartStreaming)
    rtmpClient:on('close', function()
        console.log('close')
    end)

    rtmpClient:on('error', function(error)
        console.log('error', error)
    end)

    rtmpClient:on('connect', function()
        console.log('connect')
    end)

    rtmpClient:on('request', function(...)
        console.log('request', ...)
    end)

    rtmpClient:on('response', function(header, body)
        console.log('response', body)
    end)

    rtmpClient:on('state', function(state)
        console.log('state', rtmpClient:getStateString(state))

        if (state == client.STATE_CONNECTED) then
            rtmpClient:sendCreateStream()

        elseif (state == client.STATE_CREATE_STREAM) then
            rtmpClient:sendPublish()
        end
    end)
end

startRtmpClient()

-- ffmpeg -re -i test.flv -vcodec copy -acodec copy -f flv rtmp://iot.wotcloud.cn:1935/hls/test
--
