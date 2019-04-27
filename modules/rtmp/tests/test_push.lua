local net = require("net")
local util = require("util")
local rtmp = require("rtmp")
local client = require("rtmp/client")
local fs = require("fs")
local core  = require('core')

local videStreamIndex = 1
local tags = {}

function loadFlv()

    local filepath = 'test.flv'

    filepath = '/mnt/c/work/output2.flv'

    local fileData = fs.readFileSync(filepath)
    local tags = {}

    local index = 1
    index = rtmp.flv.parseFileHeader(fileData, index)

    -- metadata
    local tag = nil
    index, tag = rtmp.flv.parseTagHeader(fileData, index)

    local tagData = fileData:sub(index, index + tag.tagSize - 1);

    local meta = rtmp.amf0.parseArray(tagData)
    tags[#tags + 1] = tagData

    while (true) do
        -- video
        index = index + tag.tagSize
        if (index > #fileData - 8) then
            break
        end

        index, tag = rtmp.flv.parseTagHeader(fileData, index)
        --console.log(index, tag)

        local tagData = fileData:sub(index, index + tag.tagSize - 1);
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

tags = loadFlv()

local urlString = 'rtmp://iot.beaconice.cn:1935/live/t127?v=1234'

local RTMPClient = client.RTMPClient

local rtmpClient = RTMPClient:new()
rtmpClient:connect(urlString)

function sendMetadataMessage(metadata)
    local array = { '@setDataFrame', 'onMetaData', metadata }
    local options = { fmt = 0x00, chunkStreamId = 0x04 }
    local message = rtmp.encodeDataMessage(array, options)
    rtmpClient:sendData(message)
end

function sendVideStream(timestamp)
    local body = tags[videStreamIndex]

    if (videStreamIndex == 1) then
        local metaData = rtmp.amf0.parseArray(body, 1)
        sendMetadataMessage(metaData[2])

    elseif (videStreamIndex <= 100) then
        local options = { fmt = 0x00, chunkStreamId = 0x04, timestamp = timestamp }
        message = rtmp.encodeVideoMessage(body, options)

        rtmpClient:sendData(message)
        console.log('sendVideStream', #message)
    end

    videStreamIndex = videStreamIndex + 1
    if (videStreamIndex >= #tags) then
        videStreamIndex = 2
    end
end


rtmpClient:on('startStreaming', function()
    rtmpClient.timer = setInterval(40, function()
        local now = process.hrtime() // 1000000 - rtmpClient.startTime
        console.log(now)

        sendVideStream(now)
    end)
end)

-- ffmpeg -re -i test.flv -vcodec copy -acodec copy -f flv rtmp://iot.beaconice.cn:1935/hls/test
-- 
