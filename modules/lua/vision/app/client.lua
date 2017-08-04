local fs      = require('fs')
local thread  = require('thread')
local utils   = require('utils')
local core 	  = require('core')

local client  = require('rtsp/client')
local reader  = require('hls/reader')
local writer  = require('hls/writer')
local queue   = require('media/queue')

local TS_PACKET_SIZE 	= 188
local TAG 				= 'rtspClient'
local NALU_START_CODE 	= string.char(0x00, 0x00, 0x00, 0x01)

-- 一个简单的 RTSP 客户端

local exports = {}

-------------------------------------------------------------------------------
-- Client

local Client = core.Emitter:extend()
exports.Client = Client

function Client:initialize()
	self.videoQueue		= queue.MediaQueue:new()
	self:createTSReader()
	self.waitSyncPoint 	= true
end

-- 关闭指定的 RTSP
function Client:close()
    if (self.rtspClient) then
        self.rtspClient:close()
        self.rtspClient = nil
    end

    if (self.tsReader) then
        self.tsReader = nil
    end

    self.lastSample = nil
    self.waitSyncPoint 	= true
end

-- 向指定的客户端发送控制命令
function Client:control(...)

    return 1
end

function Client:createTSReader()
	-- TS reader
	self.tsReader = reader.StreamReader:new()
	self.tsReader:start()
	self.tsReader:on('packet', function(sampleData, sampleTime, syncPoint)
		--console.log(#sampleData, sampleTime, syncPoint, sps, pps, naluType)
		local flags = 0x02
		if (syncPoint) then
			flags = flags | 0x01
		end
		self:onVideoSample(sampleData, sampleTime, flags)
	end)
end

function Client:getState()
    if (self.rtspClient) then
        return self.rtspClient.rtspState
    end

    return nil
end

-- 收到一个数据分片
function Client:onSampleFragment(sampleFragment)
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

		local flags = 0x00
		if (naluType == 5) then
			self.waitSyncPoint = true
			flags = 0x01
		end

		self:onVideoSample(NALU_START_CODE, sampleTime, flags)
	end

	-- H.264 NALU data
	local flags = 0x00
	local data = sampleFragment.data
	local count = #data
	for index = 1, count do
		local fragmentData = data[index]
		if (index == count) and (sampleFragment.marker) then
			flags = 0x02 -- End of H.264 sample
		end

		self:onVideoSample(fragmentData, sampleTime, flags)
	end
end

function Client:onTSPacket(rtpInfo, data, offset)
	local leftover = #data - offset + 1
	while (leftover >= TS_PACKET_SIZE) do

		local packet = data:sub(offset, offset + TS_PACKET_SIZE - 1)
		self.tsReader:processPacket(packet)

		offset   = offset   + TS_PACKET_SIZE
		leftover = leftover - TS_PACKET_SIZE
	end
end

function Client:onVideoSample(sampleFragment, sampleTime, flags)
	assert(sampleFragment, 'sampleFragment is nil')

	if (not self.videoQueue:push(sampleFragment, sampleTime, flags)) then
    	return
    end

	local sample = self.videoQueue:pop()
	if (not sample) then
		return
	end

	-- 根据帧率添加时间戳
	local framerate = self.videoFramerate
	if (framerate) then
	    if (not self.lastSampleTime) then
			self.lastSampleTime = 0
		end

		sampleTime = self.lastSampleTime
		self.lastSampleTime = self.lastSampleTime + 1000 / framerate

		sampleTime = sampleTime * 1000
	end

    if (self.callback) then
    	local flags = 0
    	local sampleData = table.concat(sample)
    	if (sample.isSyncPoint) then
    		flags = flags | 0x01
    	end
        self.callback('sample', sampleData, sampleTime, flags)
    end
end

local function createRtspClient(url)
	local playerClient = Client:new()

	local rtspClient = client.openURL(url)
	playerClient.rtspClient = rtspClient

	local emit = function (...)
		if (playerClient.callback) then
	        playerClient.callback(...)
	    end
	end

	rtspClient:on('error', function(error)
	    emit('error', error)
	end)

	rtspClient:on('close', function(error)
		emit('close', error)
	end)

	rtspClient:on('connect', function()
		emit('connect')
	end)

	rtspClient:on('state', function(state)
		emit('state', state)
	end)	

	rtspClient:on('response', function(request, response)
		emit('response', request.method, response.statusCode)
	end)

	rtspClient:on('describe', function(describe)
		emit('describe', describe)
		--console.log(rtspClient.videoTrack)

		playerClient.videoFramerate = rtspClient.videoTrack.framerate
		if (playerClient.videoFramerate == 0) then
			playerClient.videoFramerate = nil
		end
	end)

	rtspClient:on('ts', function(rtpInfo, data, offset)
		--print('ts', rtpInfo)
		playerClient:onTSPacket(rtpInfo, data, offset)
	end)

	rtspClient:on('sample', function(sample)
		playerClient:onSampleFragment(sample)
	end)

	return playerClient
end

-- 创建一个新的客户端，并打开指定的 URL 地址
-- @param url {String} RTSP URL 地址
-- @param callback {Function}
-- @return {Object}
function exports.open(url, callback)
    local playerClient = createRtspClient(url)
    playerClient.url = url
    playerClient.callback = callback

    return playerClient
end

return exports

