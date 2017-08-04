local fs      = require('fs')
local thread  = require('thread')
local utils   = require('utils')

local client  = require('rtsp/client')
local reader  = require('hls/reader')
local writer  = require('hls/writer')
local queue   = require('media/queue')

local TS_PACKET_SIZE 	= 188
local NALU_START_CODE 	= string.char(0x00, 0x00, 0x00, 0x01)

local TAG = 'rtspClient'

-- 一个简单的 RTSP 客户端

local tsReader, tsWriter, stream, videoFramerate, videoQueue


videoQueue	= queue.MediaQueue:new()

local function createTSWriter(filename)
	if (filename) then
        print('save record to: ' .. filename)
        stream = fs.createWriteStream(filename)
    end

    tsWriter = writer.StreamWriter:new()
    tsWriter:start(function(packet, sampleTime, flags)
        if (stream) then
            stream:write(packet)
        end
    end) 

    tsWriter:writeSyncInfo(0)
end

local lastSampleTime = nil

local function onVideoSample(sampleFragment, sampleTime, flags)
    if (not videoQueue:push(sampleFragment, sampleTime, flags)) then
    	return
    end

	local sample = videoQueue:pop()
	if (not sample) then
		return
	end

	-- 根据帧率添加时间戳
	local framerate = videoFramerate
	if (framerate) then
	    if (not lastSampleTime) then
			lastSampleTime = 0
		end

		sampleTime = lastSampleTime
		lastSampleTime = lastSampleTime + 1000 / framerate
	end

	local data = table.concat(sample)
	if (tsWriter) then
        print("write", #data, sample.isSyncPoint, sampleTime)
        tsWriter:write(data, sampleTime * 1000)
    end
end

local function createTSReader()
	-- TS reader
	tsReader = reader.StreamReader:new()
	tsReader:start()
	tsReader:on('packet', function(sampleData, sampleTime, syncPoint)
		--console.log(#sampleData, sampleTime, syncPoint, sps, pps, naluType)
		local flags = 0x02
		if (syncPoint) then
			flags = flags | 0x01
		end
		onVideoSample(sampleData, sampleTime, flags)
	end)
end

local function onTSPacket(rtpInfo, data, offset)
	local leftover = #data - offset + 1
	while (leftover >= TS_PACKET_SIZE) do

		local packet = data:sub(offset, offset + TS_PACKET_SIZE - 1)
		tsReader:processPacket(packet)

		offset   = offset   + TS_PACKET_SIZE
		leftover = leftover - TS_PACKET_SIZE
	end
end

local waitSyncPoint = true

-- 收到一个数据分片
local function onSampleFragment(sampleFragment)
	if (not sampleFragment.isVideo) then
		return
	end

	local buffer = sampleFragment.data[1]
	if (not buffer) or (#buffer < 1) then
		return
	end

	local sampleTime = sampleFragment.sampleTime

	-- H.264 NALU Header
	if (not sampleFragment.isFragment) or (sampleFragment.isStart) then
		local naluType = buffer:byte(1) & 0x1f
		if (naluType ~= 1) then
			console.log('sample: ', naluType, sampleTime, sampleFragment.sequence)
		end

		local flags = 0x00
		if (naluType == 5) then
			waitSyncPoint = true
			flags = 0x01
		end

		onVideoSample(NALU_START_CODE, sampleTime, flags)
	end

	-- H.264 NALU data
	local flags = 0x00
	local data = sampleFragment.data
	local count = #data
	for index = 1, count do
		local item = data[index]
		if (index == count) and (sampleFragment.marker) then
			flags = 0x02 -- End of H.264 sample
		end

		onVideoSample(item, sampleTime, flags)
	end
end

local function createRtspClient(url)
	local rtspClient = client.openURL(url)
	rtspClient:on('error', function(error)
		print(TAG, 'error', error)
	end)

	rtspClient:on('close', function(error)
		print(TAG, 'close', error)
	end)

	rtspClient:on('connect', function()
		print(TAG, 'connect')
	end)

	rtspClient:on('state', function(state)
		print(TAG, 'state', state)
	end)	

	rtspClient:on('response', function(request, response)
		print(TAG, 'response' .. ' ' .. request.method .. ' ' .. response.statusCode)
	end)

	rtspClient:on('describe', function(describe)
		print(TAG, 'describe', describe)

		console.log(rtspClient.videoTrack)

		videoFramerate = rtspClient.videoTrack.framerate
		if (videoFramerate == 0) then
			videoFramerate = nil
		end
	end)		

	rtspClient:on('ts', function(rtpInfo, data, offset)
		onTSPacket(rtpInfo, data, offset)
	end)

	rtspClient:on('sample', function(sample)
		onSampleFragment(sample)
	end)

	waitSyncPoint = true
end

local function main()

	local filename = "test.ts"

	createTSReader()
    createTSWriter(filename)

	--local url = "rtsp://127.0.0.1:5540/hd.ts"
	--local url = "rtsp://192.168.77.101/642.ts"
	local url = "rtsp://wowzaec2demo.streamlock.net/vod/mp4:BigBuckBunny_115k.mov"
	local url = "rtsp://218.204.223.237:554/live/1/67A7572844E51A64/f68g2mj7wjua3la7.sdp"
	createRtspClient(url)
end

main()

