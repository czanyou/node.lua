local init 	= require('init')
local utils = require('utils')
local url 	= require('url')
local fs 	= require('fs')
local path  = require('path')
local timer = require('timer')
local assert = require("assert")

local rtp 	= require('rtsp/rtp')
local sdp 	= require('rtsp/sdp')
local rtsp 	= require('rtsp/message')

local camera = require('media/camera')

local rtpSession = nil

local basePath = utils.dirname()


local function test_mock()


end

-------------------------------------------------------------------------------

local ts_reader    = nil
local ts_start_pts = 0
local ts_last_pts  = 0

local function _on_ts_reader_packet(sampleData, sampleTime, syncPoint)
	if (ts_start_pts <= 0) then
		ts_start_pts = sampleTime
	end

	local pts = sampleTime - ts_start_pts
	local duration = pts - ts_last_pts
	ts_last_pts = pts

	--console.log('ts----', syncPoint, naluType, pts, duration, #sampleData)
end

local function _on_ts_reader(ts_packet, sampleTime, flags)
	if (not ts_reader) then
		local hls_reader = require('hls/reader')

		ts_reader = hls_reader.StreamReader:new()

		ts_reader:on('packet', _on_ts_reader_packet)

		ts_reader:on('end', function()
			print('ts reader end');
		end)

		ts_reader:on('start', function()
			print('ts reader start');
		end)

		ts_reader:start()
	end

	if (flags > 0) then
		--print('_on_ts_reader', #ts_packet, sampleTime, flags)
	end

	ts_reader:processPacket(ts_packet)
end

-------------------------------------------------------------------------------

local packetIndex = 0

local function _on_rtp_session(rtp_packet)
	if (not rtpSession) then
		rtpSession = rtp.RtpSession:new()
		rtp.RTP_MAX_SIZE = 1450
	end

	local info = rtpSession:decodeHeader(rtp_packet)

	local offset = 13
	local limit  = #rtp_packet

	local sampleTime = info.sampleTime * 1000
	local flags = 0

	if (packetIndex == 0) then
		local code, pid = string.unpack('>BI2', rtp_packet, offset)

		pid = pid & 0x1fff
		--print('_on_rtp_session', code, pid)
		if (pid == 0) then
			flags = 0x01
		end
	end

	while (offset <= limit) do
		if (info.marker) and ((offset + 188) > limit) then
			flags = flags + 0x02
		end

		--console.log('_on_rtp_session', offset, limit)
		_on_ts_reader(rtp_packet:sub(offset, offset + 188 - 1), sampleTime, flags)

		offset = offset + 188
		flags = 0
	end

	packetIndex = packetIndex + 1

	if (info.marker) then
		packetIndex = 0
	end
end

-------------------------------------------------------------------------------

local function _on_send_packet(rtp_packet)
	_on_rtp_session(rtp_packet)
	return true
end

-------------------------------------------------------------------------------
-- MediaSession

local mediaSession = nil

local function _on_media_session(ts_packet, sampleTime, flags)
	if (not mediaSession) then
		local session = require('media/session')
		mediaSession = session.newMediaSession()

		local ret, err = mediaSession:readStart(_on_send_packet)

		if (err) then
			print('_on_media_session', err)
		end
	end

	mediaSession:writePacket(ts_packet, sampleTime, flags)
end

-------------------------------------------------------------------------------
-- StreamWriter

local writer = nil
local packetCount = 0

local function _on_ts_packet(ts_packet, sampleTime, flags)
	packetCount = packetCount + 1
	if (flags == 2) then
		--print('_on_ts_packet', #ts_packet, type(ts_packet), sampleTime, flags, packetCount)
		packetCount = 0
	end

	_on_media_session(ts_packet, sampleTime, flags)
end

local function _on_hls_writer(sampleData, sampleTime, syncPoint)

	if (not writer) then
		local hls_writer = require('hls/writer')
		writer = hls_writer.StreamWriter:new()

		writer:on('end', function()
			print('writer end');
		end)

		writer:on('start', function()
			print('writer start');
		end)

		writer:start(_on_ts_packet)
	end

	--console.log('writer', syncPoint, sampleTime, #sampleData)
	local flags = 0
	if (syncPoint) then
		writer:writeSyncInfo(sampleTime)
	end

	writer:write(sampleData, sampleTime, true)
end

-------------------------------------------------------------------------------
-- StreamReader

local function test_hls_reader()
	local hls_reader = require('hls/reader')

	local startPts = 0
	local lastPts  = 0
	local duration = 0
	local syncCount = 0

	local reader = hls_reader.StreamReader:new()
	reader:on('packet', function(sampleData, sampleTime, syncPoint)
		if (startPts <= 0) then
			startPts = sampleTime
		end

		syncCount = syncCount + 1

		local pts = sampleTime - startPts
		duration = pts - lastPts
		lastPts = pts

		console.log('reader', syncPoint, 'nalu', naluType, 'pts', pts, 'duration', duration, #sampleData)

		_on_hls_writer(sampleData, pts, syncPoint)
	end)

	reader:on('end', function()
		print('reader end');
	end)

	reader:on('start', function()
		print('reader start');
	end)

	--local filename = path.join(basePath, '/tmp/hd.ts')
	local filename = path.join(basePath, '/../../examples/641.ts')
	local source = fs.openSync(filename, 'r', 438)
	console.log(filename, source)

	assert.ok(source)
	assert.ok(source > 0)

	reader:start()

	-- loop through TS packets
	while true do
		-- read a TS packet
		local chunk = fs.readSync(source, hls_reader.TS_PACKET_SIZE)
		local ret = reader:processPacket(chunk)
		--console.log(ret, #chunk)
		if (ret < 0) then
			break
		end

		if (syncCount > 100) then
			break
		end
	end
	reader:close()

	fs.closeSync(source)
	source = 0
end

-------------------------------------------------------------------------------

test_hls_reader()
test_mock()

if (writer) then
	writer:close()
	writer = nil
end

run_loop()
