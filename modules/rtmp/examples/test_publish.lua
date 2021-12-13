local rtmp = require("rtmp")
local client = require("rtmp/client")
local fs = require('fs')

local videStreamIndex = 1
local videoTags = {}
local rtmpClient = nil

local function loadFlvFile()

    local filepath = 'test.flv'
    -- filepath = '/mnt/c/work/output2.flv'

    local fileData, err = fs.readFileSync(filepath)
    if (not fileData) then
        console.log('readFileSync', err)
        return
    end

    local tags = {}

    local index = 1
    index = rtmp.flv.parseFileHeader(fileData, index)

    -- metadata
    local tag = nil
    index, tag = rtmp.flv.parseTagHeader(fileData, index)

    local tagData = fileData:sub(index, index + tag.tagSize - 1);

    -- local meta = rtmp.amf0.parseArray(tagData)
    tags[#tags + 1] = tagData

    while (true) do
        -- video
        index = index + tag.tagSize
        if (index > #fileData - 8) then
            break
        end

        index, tag = rtmp.flv.parseTagHeader(fileData, index)
        --console.log(index, tag)

        tagData = fileData:sub(index, index + tag.tagSize - 1);
        if (not tagData) then
            break
        end

        if (tag.tagType == 0x09) then
            -- printVideoPacket(tagData)
            tags[#tags + 1] = tagData
        end
    end

    return tags
end

local function sendMetadataMessage(metadata)
    console.log('sendMetadataMessage', metadata)

    local array = { '@setDataFrame', 'onMetaData', metadata }
    local options = { fmt = 0x00, chunkStreamId = 0x04 }
    local message = rtmp.encodeDataMessage(array, options)
    rtmpClient:sendData(message)
end

local function sendVideStream(timestamp)
    -- console.log('sendVideStream', timestamp)

    local body = videoTags[videStreamIndex]

    if (videStreamIndex == 1) then
        local metaData = rtmp.amf0.parseArray(body, 1)
        sendMetadataMessage(metaData[2])

    elseif (videStreamIndex <= 100) then
        local options = { fmt = 0x00, chunkStreamId = 0x04, timestamp = timestamp }
        local message = rtmp.encodeVideoMessage(body, options)

        rtmpClient:sendData(message)
        -- console.log('sendVideStream', #message)
    end

    videStreamIndex = videStreamIndex + 1
    if (videStreamIndex >= #videoTags) then
        videStreamIndex = 2
    end
end

local function onStartStreaming()
    console.log('startStreaming')

    rtmpClient.timer = setInterval(40, function()
        local now = process.hrtime() // 1000000 - rtmpClient.startTime
        -- console.log(now)

        sendVideStream(now)
    end)
end

local function startClient()
    console.log('start rtmp clent...')

    videoTags = loadFlvFile()
    console.log('tags', videoTags and #videoTags)

    local urlString = 'rtmp://iot.wotcloud.cn/vod/t128?v=1234'

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

startClient()

-- ffmpeg -re -i test.flv -vcodec copy -acodec copy -f flv rtmp://iot.wotcloud.cn:1935/hls/test
--
