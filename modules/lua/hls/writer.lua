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
local core 	 = require('core')
local utils  = require('utils')
local buffer = require('buffer')
local fs 	 = require('fs')

-------------------------------------------------------------------------------
-- 

-- Stream Types
local STREAM_TYPE_H264 	= 0x1B
local STREAM_TYPE_AAC  	= 0x0F
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

local meta 		= { }
local exports 	= { meta = meta }

exports.TS_PACKET_SIZE 	= TS_PACKET_SIZE
exports.FLAG_IS_SYNC 	= 0x01
exports.FLAG_IS_END		= 0x02

-------------------------------------------------------------------------------
-- crc32

local crc_table =
  { 0x00000000, 0x04c11db7,
	0x09823b6e, 0x0d4326d9, 0x130476dc, 0x17c56b6b, 0x1a864db2,
	0x1e475005, 0x2608edb8, 0x22c9f00f, 0x2f8ad6d6, 0x2b4bcb61,
	0x350c9b64, 0x31cd86d3, 0x3c8ea00a, 0x384fbdbd, 0x4c11db70,
	0x48d0c6c7, 0x4593e01e, 0x4152fda9, 0x5f15adac, 0x5bd4b01b,
	0x569796c2, 0x52568b75, 0x6a1936c8, 0x6ed82b7f, 0x639b0da6,
	0x675a1011, 0x791d4014, 0x7ddc5da3, 0x709f7b7a, 0x745e66cd,
	0x9823b6e0, 0x9ce2ab57, 0x91a18d8e, 0x95609039, 0x8b27c03c,
	0x8fe6dd8b, 0x82a5fb52, 0x8664e6e5, 0xbe2b5b58, 0xbaea46ef,
	0xb7a96036, 0xb3687d81, 0xad2f2d84, 0xa9ee3033, 0xa4ad16ea,
	0xa06c0b5d, 0xd4326d90, 0xd0f37027, 0xddb056fe, 0xd9714b49,
	0xc7361b4c, 0xc3f706fb, 0xceb42022, 0xca753d95, 0xf23a8028,
	0xf6fb9d9f, 0xfbb8bb46, 0xff79a6f1, 0xe13ef6f4, 0xe5ffeb43,
	0xe8bccd9a, 0xec7dd02d, 0x34867077, 0x30476dc0, 0x3d044b19,
	0x39c556ae, 0x278206ab, 0x23431b1c, 0x2e003dc5, 0x2ac12072,
	0x128e9dcf, 0x164f8078, 0x1b0ca6a1, 0x1fcdbb16, 0x018aeb13,
	0x054bf6a4, 0x0808d07d, 0x0cc9cdca, 0x7897ab07, 0x7c56b6b0,
	0x71159069, 0x75d48dde, 0x6b93dddb, 0x6f52c06c, 0x6211e6b5,
	0x66d0fb02, 0x5e9f46bf, 0x5a5e5b08, 0x571d7dd1, 0x53dc6066,
	0x4d9b3063, 0x495a2dd4, 0x44190b0d, 0x40d816ba, 0xaca5c697,
	0xa864db20, 0xa527fdf9, 0xa1e6e04e, 0xbfa1b04b, 0xbb60adfc,
	0xb6238b25, 0xb2e29692, 0x8aad2b2f, 0x8e6c3698, 0x832f1041,
	0x87ee0df6, 0x99a95df3, 0x9d684044, 0x902b669d, 0x94ea7b2a,
	0xe0b41de7, 0xe4750050, 0xe9362689, 0xedf73b3e, 0xf3b06b3b,
	0xf771768c, 0xfa325055, 0xfef34de2, 0xc6bcf05f, 0xc27dede8,
	0xcf3ecb31, 0xcbffd686, 0xd5b88683, 0xd1799b34, 0xdc3abded,
	0xd8fba05a, 0x690ce0ee, 0x6dcdfd59, 0x608edb80, 0x644fc637,
	0x7a089632, 0x7ec98b85, 0x738aad5c, 0x774bb0eb, 0x4f040d56,
	0x4bc510e1, 0x46863638, 0x42472b8f, 0x5c007b8a, 0x58c1663d,
	0x558240e4, 0x51435d53, 0x251d3b9e, 0x21dc2629, 0x2c9f00f0,
	0x285e1d47, 0x36194d42, 0x32d850f5, 0x3f9b762c, 0x3b5a6b9b,
	0x0315d626, 0x07d4cb91, 0x0a97ed48, 0x0e56f0ff, 0x1011a0fa,
	0x14d0bd4d, 0x19939b94, 0x1d528623, 0xf12f560e, 0xf5ee4bb9,
	0xf8ad6d60, 0xfc6c70d7, 0xe22b20d2, 0xe6ea3d65, 0xeba91bbc,
	0xef68060b, 0xd727bbb6, 0xd3e6a601, 0xdea580d8, 0xda649d6f,
	0xc423cd6a, 0xc0e2d0dd, 0xcda1f604, 0xc960ebb3, 0xbd3e8d7e,
	0xb9ff90c9, 0xb4bcb610, 0xb07daba7, 0xae3afba2, 0xaafbe615,
	0xa7b8c0cc, 0xa379dd7b, 0x9b3660c6, 0x9ff77d71, 0x92b45ba8,
	0x9675461f, 0x8832161a, 0x8cf30bad, 0x81b02d74, 0x857130c3,
	0x5d8a9099, 0x594b8d2e, 0x5408abf7, 0x50c9b640, 0x4e8ee645,
	0x4a4ffbf2, 0x470cdd2b, 0x43cdc09c, 0x7b827d21, 0x7f436096,
	0x7200464f, 0x76c15bf8, 0x68860bfd, 0x6c47164a, 0x61043093,
	0x65c52d24, 0x119b4be9, 0x155a565e, 0x18197087, 0x1cd86d30,
	0x029f3d35, 0x065e2082, 0x0b1d065b, 0x0fdc1bec, 0x3793a651,
	0x3352bbe6, 0x3e119d3f, 0x3ad08088, 0x2497d08d, 0x2056cd3a,
	0x2d15ebe3, 0x29d4f654, 0xc5a92679, 0xc1683bce, 0xcc2b1d17,
	0xc8ea00a0, 0xd6ad50a5, 0xd26c4d12, 0xdf2f6bcb, 0xdbee767c,
	0xe3a1cbc1, 0xe760d676, 0xea23f0af, 0xeee2ed18, 0xf0a5bd1d,
	0xf464a0aa, 0xf9278673, 0xfde69bc4, 0x89b8fd09, 0x8d79e0be,
	0x803ac667, 0x84fbdbd0, 0x9abc8bd5, 0x9e7d9662, 0x933eb0bb,
	0x97ffad0c, 0xafb010b1, 0xab710d06, 0xa6322bdf, 0xa2f33668,
	0xbcb4666d, 0xb8757bda, 0xb5365d03, 0xb1f740b4 };

function _mpegts_crc32(packet, offset, len)
	local crc = 0xffffffff;
	for i = 0, len - 1 do
		local value = packet[offset + i]
		local pos = ((crc >> 24) ~ value) & 0xff;
		crc = (crc << 8) ~ crc_table[pos + 1];
	end

	return crc;
end

-------------------------------------------------------------------------------
--- StreamWriter

local StreamWriter = core.Emitter:extend()
exports.StreamWriter = StreamWriter

function StreamWriter:initialize(options)
	self.isLastEnd				= true
	self.isStarted				= false
	self.packetCallback			= nil
	self.PATContinuityCounter 	= 0x00
	self.PESContinuityCounter 	= 0x0F
	self.PMTContinuityCounter 	= 0x00
	self.sendBuffer				= nil
	self.tempPacket				= nil

	--local source = debug.getinfo(1).short_src or ''
	--print('source', source)
end

function StreamWriter:close()
	if (not self.isStarted) then
		return
	end

	self.isLastEnd				= true
	self.isStarted				= false
	self.packetCallback			= nil	
	self.PATContinuityCounter 	= 0x00
	self.PESContinuityCounter 	= 0x0F
	self.PMTContinuityCounter 	= 0x00
	self.sendBuffer				= nil
	self.tempPacket				= nil

	self:emit('end')
end

function StreamWriter:start(callback)
	if (self.isStarted) then
		return
	end

	local bufferSize 			= TS_PACKET_SIZE * 1024 * 8

	self.isLastEnd				= true
	self.isStarted				= true
	self.packetCallback 		= callback
	self.sendBuffer 			= buffer.Buffer:new(bufferSize)
	self.tempPacket				= nil

	self:emit('start')
end

--[[

@param sampleTime
]]
function StreamWriter:writeSyncInfo(sampleTime)
	if (not self.isStarted) then
		return
	end

	if (sampleTime) then
		local flags = exports.FLAG_IS_SYNC -- syncPoint
		self:_writePAT(sampleTime, flags)
		self:_writePMT(sampleTime, 0)

	else
		self:_writePAT()
		self:_writePMT()		
	end
end


--[[

@param data
@param sampleTime  Presentation Time Stamp
@param isEnd
]]
function StreamWriter:writeAudio(data, sampleTime, isEnd)
	if (not self.isStarted) then
		return
	end

	if (not data) then
		return 
	end
	
	self:_writePESPacket(data, #data, sampleTime, isEnd, true)
end

function StreamWriter:writeVideo(data, sampleTime, isEnd)
	if (not self.isStarted) then
		return
	end

	if (not data) then
		return 
	end
	
	self:_writePESPacket(data, #data, sampleTime, isEnd, false)
end

function StreamWriter:_toPresentationTimeStamp(sampleTime)
	return math.floor(sampleTime * 90 / 1000) + TS_PTS_BASE
end


function StreamWriter:_writePAT(sampleTime, flags)
	local packet = buffer.Buffer:new(TS_PACKET_SIZE)
	local tableLength = 13
	local PMT_ID = 0x1001
	local PAT_TABLE_OFFSET = 6

	local pts = self:_toPresentationTimeStamp(sampleTime)

	packet[1] = TS_PACKET_START
	packet[2] = 0x40;	--// (0100 0000) 1: 传输误码指示符, 1: 起始指示符, 1: 优先传输
	packet[3] = 0x00;	--// 13: PID
	packet[4] = 0x10 | self.PATContinuityCounter; --//  2: 传输加扰, 2: 自适应控制 4: 连续计数器
	packet[5] = 0x00;	

	self.PATContinuityCounter = (self.PATContinuityCounter + 1) & 0x0F;

	--// PSI
	packet[6] = TS_PAT_TABLE_ID;	--// 8: 固定为0x00, 标志是该表是PAT
	packet[7] = 0xB0 | ((tableLength >> 8) & 0x0F);	--// 1: 段语法标志位，固定为1; 1: 0; 2: 保留 (1011 0000) 
	packet[8] = tableLength & 0xFF;	--// 12: 13, 表示这个字节后面有用的字节数，包括CRC32
	packet[9] = 0x00;	--// 
	packet[10] = 0x01;	--// 16: 该传输流的ID，区别于一个网络中其它多路复用的流
	packet[11] = 0xC1;	--// 2: 保留; 5: 范围0-31，表示PAT的版本号; 1: 发送的PAT是当前有效还是下一个PAT有效 (1100 0001) 
	packet[12] = 0x00;	--// 8: 分段的号码。PAT可能分为多段传输，第一段为00，以后每个分段加1，最多可能有256个分段
	packet[13] = 0x00;	--// 8: 最后一个分段的号码

	--// Programs 节目列表 (PAT)
	packet[14] = 0x00;  --//
	packet[15] = 0x01;  --// 16: 节目号
	packet[16] = 0xE0 | ((PMT_ID >> 8) & 0x1F);	--// 3: 保留位 (1110 0001) 
	packet[17] = PMT_ID & 0xFF; --// 13: 节目映射表的PID，节目号大于 0 时对应的 PID，每个节目对应一个
		--// 13: 网络信息表(NIT)的 PID,节目号为 0 时对应的 PID 为network_PID

	--// CRC 32
	local crc = _mpegts_crc32(packet, PAT_TABLE_OFFSET, (tableLength + 3) - 4);
	packet[18] = ((crc >> 24) & 0xff);
	packet[19] = ((crc >> 16) & 0xff);
	packet[20] = ((crc >> 8) & 0xff);
	packet[21] = ((crc) & 0xff);

	for i = 22, TS_PACKET_SIZE do
		packet[i] = 0xFF				  
	end

	local data = packet:toString(1, TS_PACKET_SIZE)
	self:_writeTSPacket(data, sampleTime, flags)
end

function StreamWriter:_writePCR(packet, offset, pcr)
	--// (33bit) program clock reference base
	local byte1 = ((pcr >> 25) & 0xff); --//
	local byte2 = ((pcr >> 17) & 0xff); --//
	local byte3 = ((pcr >> 9)  & 0xff); --//
	local byte4 = ((pcr >> 1)  & 0xff); --//

	--// p[i++] = ((pcr & 0x01) << 7) | 0x7E; --//(6bit) reserved
	local byte5 = 0x00;

	--// (9bit) Program clock reference extension
	local byte6 = 0x00; --//

	packet:write(string.char(byte1, byte2, byte3, byte4, byte5, byte6), offset)
	return 0;
end

function StreamWriter:_writePESHeader(packet, offset, pts, isAudio)
	local streamID = 0xE0
	if (isAudio) then
		streamID = 0xC0
	end

	local dts = pts

	packet:write(string.pack('>I2BBI2BBB', 0, 1, streamID, 0, 0x84, 0xC0, 0x0A), offset)

--[[
	--// Start Code
	packet[offset + 1] = 0x00;
	packet[offset + 2] = 0x00;
	packet[offset + 3] = 0x01;

	--// Stream ID
	packet[offset + 4] = streamID; -- // Stream ID, E0: Video; C0: Audio

	--// PES Length
	packet[offset + 5] = 0x00; --//
	packet[offset + 6] = 0x00; --// 16:

	--// Flags
	packet[offset + 7] = 0x84; --// (1000 0100) data_alignment
	--// 2: mpeg2 id, 0x20
	--// 2: pes scrambling control
	--// 1: pes priority
	--// 1: data alignement indicator
	--// 1: copyright
	--// 1: original or copy

	packet[offset + 8] = 0xC0; --// (1100 0000) PTS DTS
	--// 2: pts_dts flags
	--// 1: escr flags
	--// 1: es rate flag
	--// 1: dsm trick mode flag
	--// 1: additional copy info flag
	--// 1: pes crc flag
	--// 1: pes extention flags

	packet[offset + 9] = 0x0A; --// 8: Data Length
]]

	--// PTS (5 Bytes) 10
	local byte1 = (((pts >> 29) & 0xFE) | 0x31); --// 4: '0010' or '0011',
														--// 3: PTS, 1: marker
	local byte2 = ((pts  >> 22) & 0xff); --// 15: PTS
	local byte3 = (((pts >> 14) & 0xFE) | 0x01); --// 1: marker
	local byte4 = ((pts  >> 7 ) & 0xff); --// 15: PTS
	local byte5 = ((pts  << 1 ) & 0xFE | 0x01); --// 1: marker
	packet:write(string.char(byte1, byte2, byte3, byte4, byte5), offset + 9)

	--// DTS (5 Bytes) 15
	local byte1 = (((dts >> 29) & 0xFE) | 0x11); --// 4: '0010' or '0011',
														--// 3: PTS, 1: marker
	local byte2 = ((dts  >> 22) & 0xff); --// 15: PTS
	local byte3 = (((dts >> 14) & 0xFE) | 0x01); --// 1: marker
	local byte4 = ((dts  >> 7 ) & 0xff); --// 15: PTS
	local byte5 = ((dts  << 1 ) & 0xFE | 0x01); --// 1: marker
	packet:write(string.char(byte1, byte2, byte3, byte4, byte5), offset + 14)

	if (isAudio) then
		return 9 + 10
	end

	-- au header (6 Bytes)
	-- 0x00, 0x00, 0x00, 0x01, 0x09, 0x10, 0x00
	packet:write(string.pack('>BBBBBB', 0x00, 0x00, 0x00, 0x01, 0x09, 0x10), offset + 19)

	return 9 + 10 + 6
end

function StreamWriter:_writePESPacket(data, length, sampleTime, isEnd, isAudio)
	if (not data) or (length < 1) then
		return
	end

	local pts = self:_toPresentationTimeStamp(sampleTime)

	local isStart = self.isLastEnd
	--print('isStart', isStart, 'isEnd', isEnd, 'self.isLastEnd', self.isLastEnd)
	if (isEnd == nil) then
		isEnd = true
	end

	self.isLastEnd = isEnd

	local leftover = length
	local dataOffset = 0
	local pid = TS_VIDEO_PID
	if (isAudio) then
		pid = TS_AUDIO_PID
	end

	local pcr = pts

	local packet = buffer.Buffer:new(TS_PACKET_SIZE)
	packet:expand(TS_PACKET_SIZE)

	local meta = { pts = pts }

	-- ========================
	-- Start first packet

	-- PES Header
	local offset = 5
	local flags = 0

	if (isStart) then
		local size = 0	
		local headerSize = self:_writePESHeader(packet, offset, pts, isAudio)
		local pesSize = headerSize + leftover

		local isAdaptationField = false
		if (pesSize < TS_PAYLOAD_SIZE) then
			isAdaptationField = true
			meta.isEnd = true and isEnd
			flags = exports.FLAG_IS_END --  0x02 -- end
		end

		--- TS packet header
		self:_writeTSHeader(packet, isStart, pid, false)

		--- TS packet data
		if (pesSize < TS_PAYLOAD_SIZE) then
			size = leftover
		else
			size = TS_PAYLOAD_SIZE - headerSize
		end

		offset = offset + headerSize
		for i = offset + size, TS_PAYLOAD_SIZE do
			packet[i] = 0xff
		end
		--packet:putBytes(offset, data, dataOffset + 1, dataOffset + size)
		packet:write(data, offset, size, dataOffset + 1)

		--- 
		local packetData = packet:toString(1, TS_PACKET_SIZE)
		self:_writeTSPacket(packetData, sampleTime, flags)

		-- End first packet
		-- ========================

		dataOffset  = dataOffset + size;
		leftover    = leftover - size;

		--self.tempPacket				= nil
		--print('headerSize', headerSize, 'pesSize', pesSize, 'leftover', leftover)
	end

	--if (data) then return end

	-- 
	offset 		= 5
	while (leftover > 0) do
		local isAdaptationField = false
		if (leftover < TS_PAYLOAD_SIZE) then
			isAdaptationField = true
		end

		--// TS Packet Header
		self:_writeTSHeader(packet, false, pid, isAdaptationField)

		if (leftover <= TS_PAYLOAD_SIZE) then
			meta.isEnd = true and isEnd

			flags = exports.FLAG_IS_END -- 0x02 -- end
		end

		-- isAdaptationField
		local size = 0;
		if (leftover < TS_PAYLOAD_SIZE) then
			size = leftover
			local stuffing = self:_writeStuffing(packet, size, pcr)
			offset = offset + stuffing
		else
			size = TS_PAYLOAD_SIZE;
		end

		--packet:putBytes(offset, data, dataOffset + 1, dataOffset + size)
		packet:write(data, offset, size, dataOffset + 1)

		local sample = packet:toString(1, TS_PACKET_SIZE)
		self:_writeTSPacket(sample, sampleTime, flags)

		dataOffset  = dataOffset + size;
		leftover    = leftover - size;
	end
end

function StreamWriter:_writeTSHeader(packet, isStart, pid, isAdaptationField)
	local byte1 = TS_PACKET_START;
	local byte2 = ((isStart and 0x40 or 0x00) | ((pid >> 8) & 0x1f));
	local byte3 = (pid & 0xff);
	local byte4 = (0x10 | self.PESContinuityCounter);
	if (isAdaptationField) then
		byte4 = byte4 | 0x20
	end

	packet:write(string.char(byte1, byte2, byte3, byte4), 1)

	self.PESContinuityCounter = (self.PESContinuityCounter + 1) & 0x0F;
end

function StreamWriter:_writeStuffing(packet, size, pcr)
	local stuffing = TS_PAYLOAD_SIZE - size;
	local byte5, byte6

	if (stuffing > 0) then
		local value = (stuffing - 1); --// 长度
		packet:write(string.char(value), 5)
	end

	if (stuffing > 1) then
		packet:write(string.char(0x00), 6) --// 总是为 0x00
	end

	if (stuffing > 2) then
		for i = 0, stuffing - 3 do
			--packet:write(string.char(0xff), i + 7)
			--packet[i + 7] =  0xff;
		end
	end

	if (stuffing > 8) then
		packet:write(string.char(0x10), 6) --// flags: PCR present
		self:_writePCR(packet, 7, pcr); --// 6 Bytes
	end

	return stuffing
end

function StreamWriter:_writePMT(sampleTime, flags)
	local packet = buffer.Buffer:new(TS_PACKET_SIZE)

	local tableLength = 9 + 5 + 5 + 4; --// PMT 表数据内容长度, 不包括 PMT 表前 3 个字节
	local PMT_TABLE_OFFSET = 6
	local PMT_ID  = 0x1001
	local PCR_PID = 0x0100

	--// TS Packet Header (4 Bytes)
	packet[1]  = TS_PACKET_START;	--// 8 bit: 同步字符, 总是为 0x47
	packet[2]  = 0x40 | ((PMT_ID >> 8) & 0x1F);	--// 1 bit: 传输误码指示符, 1 bit: 起始指示符, 1 bit: 优先传输
	packet[3]  = PMT_ID & 0xFF;	--// 13 bit: PID
	packet[4]  = 0x10 | self.PMTContinuityCounter;	--// 2 bit: 传输加扰, 2 bit: 自适应控制, 4 bit: 连续计数器
	packet[5]  = 0x00;	--// 总是为 0x00
	self.PMTContinuityCounter = (self.PMTContinuityCounter + 1) & 0x0F;

	--// PMT Table
	packet[6]  = TS_PMT_TABLE_ID;	--// 8 bit: 固定为0x02, 标志是该表是PMT
	packet[7]  = 0xB0 | ((tableLength >> 8) & 0x0F);	--// 1 bit: 段语法标志位，固定为1; 1 bit: 0; 2 bit: 保留 (1011 0000) 
	packet[8]  = tableLength & 0xFF;	--// 12 bit: 表示这个字节后面有用的字节数，包括CRC32

	packet[9]  = 0x00;	--// 
	packet[10] = 0x01;	--// 16 bit: 指出该节目对应于可应用的 Program map PID
	packet[11] = 0xC1;	--// 2 bit: 保留; 5 bit: 指出TS流中Program map section的版本号
					--// 1 bit: 当该位置1时，当前传送的 Program map section 可用 (1100 0001) 
	packet[12] = 0x00;	--// 8 bit: 固定为0x00
	packet[13] = 0x00;	--// 8 bit: 固定为0x00

	packet[14] = 0xE0 | ((PCR_PID >> 8) & 0x1F);	--// 3 bit: 保留
	packet[15] = PCR_PID & 0xFF; --// 13 bit: 节目号 指明 TS 包的PID值
	packet[16] = 0xF0;	--// 4 bit: 保留位  
	packet[17] = 0x00;	--// 12 bit: 前两位bit为00。该域指出跟随其后对节目信息的描述的 byte 数

	--// 视频流的描述
	local index = 18

	packet[index + 0] = STREAM_TYPE_H264;	--// H.264 视频流
	packet[index + 1] = 0xE0 | ((TS_VIDEO_PID >> 8) & 0x1F);	--//
	packet[index + 2] = TS_VIDEO_PID & 0xFF;	--//
	packet[index + 3] = 0xF0;	--//
	packet[index + 4] = 0x00;	--// 

	index = index + 5
	packet[index + 0] = STREAM_TYPE_AAC;	--// H.264 视频流
	packet[index + 1] = 0xE0 | ((TS_AUDIO_PID >> 8) & 0x1F);	--//
	packet[index + 2] = TS_AUDIO_PID & 0xFF;	--//
	packet[index + 3] = 0xF0;	--//
	packet[index + 4] = 0x00;	--// 

	index = index + 5
	local crc = _mpegts_crc32(packet, PMT_TABLE_OFFSET, (tableLength + 3) - 4);
	packet[index + 0] = ((crc >> 24) & 0xff);
	packet[index + 1] = ((crc >> 16) & 0xff);
	packet[index + 2] = ((crc >> 8) & 0xff);
	packet[index + 3] = ((crc) & 0xff);

	index = index + 4
	for i = index, TS_PACKET_SIZE do
		packet[i] = 0xFF				  
	end

	local data = packet:toString(1, TS_PACKET_SIZE)
	self:_writeTSPacket(data, sampleTime, flags)
end

function StreamWriter:_writeTSPacket(packet, sampleTime, flags)
	if (self.packetCallback) then
		self.packetCallback(packet, sampleTime, flags)
	end
end

function exports.new_ts_writer(...)
	return StreamWriter:new(...)
end

return exports
