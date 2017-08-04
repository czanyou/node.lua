--[[

Copyright 2016 The Node.lua Authors. All Rights Reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS-IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

--]]
local buffer = require('buffer')
local core 	 = require('core')
local fs 	 = require('fs')
local utils  = require('utils')

-------------------------------------------------------------------------------

-- Stream Types
local STREAM_TYPE_AAC  	= 0x0F
local STREAM_TYPE_H264 	= 0x1B
local STREAM_TYPE_META  = 0x15

-- TS Defines
local TS_AUDIO_PID		= 0x0101
local TS_PACKET_SIZE 	= 188
local TS_PACKET_START	= 0x47 --
local TS_PAT_ID			= 0x0000
local TS_PAT_TABLE_ID	= 0x00
local TS_PAYLOAD_SIZE	= 184 -- TS header size = 4
local TS_PCR_PID		= 0x0100
local TS_PMT_PID 		= 0x1001
local TS_PMT_TABLE_ID	= 0x02
local TS_PTS_BASE 		= 63000
local TS_VIDEO_PID		= 0x0100

-------------------------------------------------------------------------------

local exports = { }

exports = { meta = exports }

exports.TS_PACKET_SIZE = TS_PACKET_SIZE

-------------------------------------------------------------------------------
-- StreamReader The class used to read and parse TS files
-- @event end    
-- @event error  
-- @event packet (packet, sampleTime, syncPoint, sps, pps, naluType)
-- @event start   

local StreamReader = core.Emitter:extend()
exports.StreamReader = StreamReader

function StreamReader:initialize()
	self.audioBuffer 	= {}
	self.audioId    	= 0
	self.isStarted  	= false
	self.pmtId 			= 0
	self.videoBuffer 	= {}
	self.videoId  		= 0
end

function StreamReader:close()
	if (#self.videoBuffer > 0) then
		self:_readVideoPESPacket()
	end	

	if (self.isStarted) then
		self.isStarted = false
		self.videoBuffer = {}
		self:emit('end')
	end
end

function StreamReader:fireError(error)
	console.log('error', error)
	self:emit('error', error)
end

function StreamReader:processPacket(packet)
	if (not self.isStarted) then
		self:fireError('processPacket: Invalid State')
		return -4
	end

	-- check packet
	if (packet == nil) then
		--self:fireError('processPacket: Packet is nil')
		return -1

	elseif (#packet ~= TS_PACKET_SIZE) then
		--self:fireError('processPacket: Invalid packet size')
		return -2

	elseif (packet:byte(1) ~= 0x47) then
		--self:fireError('processPacket: Invalid start code')
		return -3
	end

	-- pid is a 13-bit field starting at the last bit of TS[1]
	local value   = (packet:byte(2) << 8) + packet:byte(3)
	local pid 	  = value & 0x1fff
	local isStart = ((value & 0x4000) ~= 0)

	--console.log('StreamReader:processPacket', pid, isStart, self.pmtId, self.videoId, self.audioId)
	--console.log('processPacket', pid, isStart)

	-- pid
	if (pid == 0) then
		self:_parsePAT(packet)

	elseif (pid == self.pmtId) then
		self:_parsePMT(packet)

	elseif (pid == self.videoId) then
		-- start flags
		if (isStart) then
			-- console.log(string.format('pid: 0x%04X, start:', pid), isStart, packetIndex)
			if (#self.videoBuffer > 0) then
				self:_readVideoPESPacket() -- The next PES start tag is processed immediately before the previous PES packet
			end
		end

		self:_parseVideoPacket(packet, isStart)

	elseif (pid == self.audioId) then
		if (isStart) then
			-- console.log(string.format('pid: 0x%04X, start:', pid), isStart, packetIndex)
			if (#self.audioBuffer > 0) then
				self:_readAudioPESPacket() -- The next PES start tag is processed immediately before the previous PES packet
			end
		end

		self:_parseAudioPacket(packet, isStart)
	end

	return 0
end

function StreamReader:start(callback)
	if (not self.isStarted) then
		self.isStarted = true
		self:emit('start')
	end

	self.callback = callback
end

function StreamReader:_parseNaluType(chunk) 
	local state = 0
	local limit = (#chunk > 128) and 128 or #chunk
	local pps = nil
	local sps = nil
	local type = 0

	local lastPos  = 0
	local lastType = 0

	--console.log(state, limit)
	for i = 1, limit do
		local ch = chunk:byte(i)
		--console.log(i, state, ch)

		if (state == 0) then
			if (ch == 0x00) then state = 1 end

		elseif (state == 1) then
			if (ch == 0x00) then
				state = 2
			else 
				state = 0
			end

		elseif (state == 2) then
			if (ch == 0x00) then
				state = 3

			elseif (ch == 0x01) then
				state = 4

			else 
				state = 0
			end

		elseif (state == 3) then
			if (ch == 0x01) then
				state = 4
			else 
				state = 0
			end

		elseif (state == 4) then
			local naluType = ch & 0x1f
			--console.log('type:', naluType)
			state = 0

			if (lastType == 7) then
				sps = chunk:sub(lastPos, i - 5)

			elseif (lastType == 8) then
				pps = chunk:sub(lastPos, i - 5)
			end

			if (naluType == 5) then
				type = 5
				break;

			elseif (naluType == 1) then
				type = 1
				break;
			end

			lastPos  = i
			lastType = naluType
		end
	end

	--if (sps) then
	--	console.printBuffer(sps)
	--	console.printBuffer(pps)
	--end

	return type, sps, pps
end

function StreamReader:_parsePAT(packet)
	local offset = 6

	local value = (packet:byte(offset + 10) << 8) | packet:byte(offset + 11)
	self.pmtId = value & 0x1fff;
	--console.log('PMT', self.pmtId, string.format('0x%02x', self.pmtId))

end

function StreamReader:_parsePMT(packet)
	local offset = 6

	local value = (packet:byte(offset + 1) << 8) | packet:byte(offset + 2)
	local length = value & 0x0fff
	-- console.log('length', length, string.format('0x%04x', length))

	if (length < 17) then
		return
	end

	-- skip 9
	offset = offset + 12
	while (offset + 5) <= length + 5 do
		local codecId = packet:byte(offset)
		value = (packet:byte(offset + 1) << 8) | packet:byte(offset + 2)
		local streamId = value & 0x1fff

		--console.log('codecId', offset, length, codecId, string.format('0x%02x 0x%04x', codecId, streamId))	

		if (codecId == STREAM_TYPE_H264) then
			self.videoId = streamId

		elseif (codecId == STREAM_TYPE_AAC) then
			self.audioId = streamId
		end

		offset = offset + 5
	end
end

function StreamReader:_parsePTS(chunk, offset) 
	local pts = 0;

	--// hight int
	pts = (chunk:byte(offset + 0) & 0x0e);
	pts = pts << 29;
	
	--// low int
	pts = pts + ((chunk:byte(offset + 1) & 0xff) << 22);
	pts = pts + ((chunk:byte(offset + 2) & 0xfe) << 14);
	pts = pts + ((chunk:byte(offset + 3) & 0xff) << 7);
	pts = pts + ((chunk:byte(offset + 4) & 0xfe) >> 1);

	pts = (pts - TS_PTS_BASE) * 1000 / 90;
	return math.floor(pts);
end

function StreamReader:_parseAudioPacket(packet, isStart)
	local isAdaptationField = (packet:byte(4) & 0x20) ~= 0;

	local offset = 4 + 1 -- TS_HEADER_SIZE = 4
	local size   = TS_PAYLOAD_SIZE

	-- 有填充物
	if (isAdaptationField) then
		local stuffing = packet:byte(5) + 1;
		--console.log('stuffing', stuffing)

		if (stuffing > 0) then
			size   = size   - stuffing
			offset = offset + stuffing
		end
	end

	local data = packet:sub(offset, offset + size - 1)
	table.insert(self.audioBuffer, data)

	--print('audio', isStart, isAdaptationField)
	--self:emit('packet', sampleData, sampleTime, syncPoint, sps, pps, naluType)
end

function StreamReader:_parseVideoPacket(packet, isStart)
	local isAdaptationField = (packet:byte(4) & 0x20) ~= 0;

	local offset = 4 + 1 -- TS_HEADER_SIZE = 4
	local size   = TS_PAYLOAD_SIZE

	-- 有填充物
	if (isAdaptationField) then
		local stuffing = packet:byte(5) + 1;
		--console.log('stuffing', stuffing)

		if (stuffing > 0) then
			size   = size   - stuffing
			offset = offset + stuffing
		end
	end

	local data = packet:sub(offset, offset + size - 1)
	table.insert(self.videoBuffer, data)
end

function StreamReader:_readAudioPESPacket()
	local audioBuffer = self.audioBuffer
	self.audioBuffer = {}

	local offset = 1

	-- PES header
	local data = audioBuffer[1]
	local streamId = data:byte(offset + 3)
	if (streamId ~= 0xc0) then
		return
	end

	--console.printBuffer(data)

	local length = data:byte(offset + 8)
	if (length <= 0) then
		length = 10
	end

	--console.log('length', length)

	local sampleTime = self:_parsePTS(data, offset + 9)
	
	offset = offset + 8 + length;
	audioBuffer[1] = data:sub(offset + 1)

	-- packet
	local sampleData = table.concat(audioBuffer)
	local syncPoint = true

	--print(streamId, sampleTime, #sampleData)
	self:emit('audio', sampleData, sampleTime, syncPoint)
end

function StreamReader:_readVideoPESPacket()
	local videoBuffer = self.videoBuffer
	self.videoBuffer = {}

	local offset = 1

	-- PES header
	local data = videoBuffer[1]
	local streamId = data:byte(offset + 3)
	if (streamId ~= 0xe0) then
		return
	end

	local length = data:byte(offset + 8)
	if (length <= 0) then
		length = 10
	end

	local sampleTime = self:_parsePTS(data, offset + 9)
	
	offset = offset + 8 + length;
	offset = offset + 6 -- au
	videoBuffer[1] = data:sub(offset + 1)

	-- packet
	local sampleData = table.concat(videoBuffer)

	local naluType, sps, pps = self:_parseNaluType(sampleData)
	local syncPoint = (naluType == 5)

	self:emit('video', sampleData, sampleTime, syncPoint, sps, pps, naluType)
end

return exports
