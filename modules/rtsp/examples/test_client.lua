local utils = require('util')

local client = require('rtsp/client')
local RtspClient = client.RtspClient

local rtspClient = nil

local TAG = 'RTSPC'
local color = console.color

-- 测试 RTSP 客户端

local function test_rtsp_client(url, username, password)
    rtspClient = RtspClient:new()

	rtspClient:on('close', function(err)
		print(TAG, 'close', err)
	end)

	rtspClient:on('error', function(err)
		print(TAG, 'error', err)
    end)

    -- state
    local lastState = 0

    ---@param state integer
    local onStateChange = function(state)
		print(TAG, color('function') .. 'state = ' .. state, color())

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
        -- console.log('sample', sample)

        if (not sample.isVideo) then
            return
        end


        if (not lastSample) then
            lastSample = {}
        end

        local buffer = sample.data[1]
        if (not buffer) then
            return
        end

        local startCode = string.char(0x00, 0x00, 0x00, 0x01)

        if (not sample.isFragment) or (sample.isStart) then
            local naluType = buffer:byte(1) & 0x1f
            --print('naluType', naluType)
            if (naluType ~= 1) then
                -- console.log('sample: ', naluType, sample.sampleTime, sample.sequence)
            end

            table.insert(lastSample, startCode)
        end

        for _, item in ipairs(sample.data) do
            table.insert(lastSample, item)
        end

        if (sample.marker) then
            local sampleData = table.concat(lastSample)
            lastSample.sampleTime = sample.sampleTime
            lastSample.isVideo    = sample.isVideo

            -- TODO: lastSample
            console.log('sample: ', lastSample.isVideo, lastSample.sampleTime, #sampleData);
            -- console.log(sample);

            lastSample = nil
        end
    end

    rtspClient:on('sample', onSample)

    rtspClient:on('response', function(request, response)
        console.log('response', request, response)
    end)

    rtspClient:on('request', function(request)
        console.log('request', request)
    end)

    rtspClient.username = username;
    rtspClient.password = password;

    rtspClient:open(url)
end

-- Start RTSP client
local url = 'rtsp://192.168.1.64/live.mp4'
local username = 'admin';
local password = 'admin123456';

-- nvr
-- type 0: 主码流, 1: 子码流
-- id 通道号
--url = 'rtsp://192.168.31.108:554/type=1&id=1'

-- vcr
--
-- url = 'rtsp://192.168.31.108:554/id=1&type=0&pic=0&Disk=0&Part=0&Clus=6055&record=20200405173923_20200405235959&pos=Local'

-- local url = 'rtsp://iot.wotcloud.cn:9554/main'
url = 'rtsp://iot.wotcloud.cn:50000/subvideo'
username = 'admin';
password = '123456';

url = 'rtsp://iot.wotcloud.cn:10554/live.mp4'
password = 'admin123456';

url = 'rtsp://192.168.1.104/live.mp4'
password = 'abcdefg123456';

test_rtsp_client(url, username, password)
