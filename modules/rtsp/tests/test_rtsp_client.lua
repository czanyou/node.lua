local utils = require('util')
local url 	= require('url')
local fs 	= require('fs')
local path 	= require('path')
local core 	= require('core')

local client = require('rtsp/client')
local RtspClient = client.RtspClient

local rtspClient = nil

local TAG = 'RTSPC'
local color = console.color

function test_rtsp_client()
    rtspClient = RtspClient:new()

	rtspClient:on('close', function(err)
		print(TAG, 'close', err)
	end)

	rtspClient:on('error', function(err)
		print(TAG, 'error', err)
    end)
    
    local lastState = 0

    rtspClient:on('state', function(state)
		print(TAG, color('function') .. 'state = ' .. state, color())

		if (state == client.STATE_READY) then
            console.log(rtspClient.mediaTracks);
            console.log(rtspClient.isMpegTSMode);
		end

		lastState = state
    end)

    local lastSample = nil;
    
    rtspClient:on('sample', function(sample)
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
            lastSample.sampleTime   = sample.sampleTime
            lastSample.isVideo    = sample.isVideo

            -- TODO: lastSample
            console.log('sample: ', lastSample.isVideo, lastSample.sampleTime, #sampleData);

            lastSample = nil
        end
    end)

    local url = 'rtsp://192.168.31.64/live.mp4'

    rtspClient.username = 'admin';
    rtspClient.password = 'admin123456';
    rtspClient:open(url)
end

test_rtsp_client()

