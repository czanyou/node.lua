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
local core = require('core')

local meta 		= { }
local exports 	= { meta = meta }

exports.RTP_MAX_SIZE 	= 1450
exports.RTP_PACKET_HEAD	= 0x80

-- 返回指定的布尔值;不执行任何实际的转换。
-- 如下的值会被认为是 false:
-- nil 值, 数值中的 0, 空字符串
local function toboolean(value)
	if (value == nil) or (value == false) then
		return false

	elseif (value == 0) or (value == '') then
		return false
		
	else
		return true
	end
end

-------------------------------------------------------------------------------
-- RtpSession

-- 这个类主要用来解析和生成 RTP 包

local RtpSession = core.Object:extend()
exports.RtpSession = RtpSession

function RtpSession:initialize()
	self.payload = 96 -- payload >= 96 表示自定义类型
	self.rtpSsrc = 0x33445566
end

function RtpSession:decode(packet, offset)
	if (not offset) or (offset < 1) then
		offset = 1
	end

	-- parse packet header
	local total = #packet
	local sample = self:decodeHeader(packet, offset)
	if (not sample) then
		return
	end

	-- parse packet data
	offset = offset + 12
	local data = {}

	if (total >= offset + 1) then
		local fu1, fu2 = string.unpack(">BB", packet, offset)

		local nalType = fu1 & 0x1f -- H.264 NALU type
		if (nalType == 28) then -- fragment unit mode
			offset = offset + 2 -- skip fu header
			sample.isFragment 	= true
			sample.isStart  	= toboolean(fu2 & 0x80)
			sample.isEnd    	= toboolean(fu2 & 0x40)

			if (sample.isStart) then
				local nalHeader = (fu1 & 0x60) | (fu2 & 0x1f)
				--print('nalHeader', nalHeader, fu1, fu2)

				table.insert(data, string.char(nalHeader))
			end

			table.insert(data, packet:sub(offset, total))

		elseif (nalType == 24) then -- 组合包类型
			sample.isSTAP = true

			offset = offset + 1 -- skip fu header

			local leftover = total - offset + 1
			while (leftover > 3) do
				local ret, length = pcall(string.unpack, ">I2", packet, offset)
				if (not ret or length <= 0) then
					break
				end

				offset 	  = offset + 2 -- skip fu header
				leftover  = leftover - 2

				table.insert(data, packet:sub(offset, offset + length - 1))

				offset    = offset   + length
				leftover  = leftover - length
			end

		else -- 单一 NAL 单元模式
			table.insert(data, packet:sub(offset, total))
		end
	end

	sample.data = data
	return sample
end

--[[

]]
function RtpSession:decodeHeader(packet, offset)
	local head, payload, sequence, ssrc, rtpTime = string.unpack(">BBI2I4I4", packet, offset)

	local buffer = {}
	buffer.payload 		= payload & 0x7F
	buffer.marker  		= toboolean(payload & 0x80)
	buffer.sequence 	= sequence
	buffer.rtpTime  	= rtpTime
	buffer.sampleTime  	= math.floor(rtpTime / 90)
	
	return buffer
end

--[[
把指定的流编码成 RTP 包
@param data
@param timestamp，单位为毫秒 (1/1000)
]]
function RtpSession:encode(data, timestamp)
	local list = {}

	local kRtpMaxSize   = exports.RTP_MAX_SIZE
	local kFuHeaderSize	= 2;
	local kFuStartBit	= 0x80;
	local kFuEndBit		= 0x40;
	local kFuNaluType	= 28;

	local total 	= #data
	local offset 	= 1
	local leftover 	= total
	local isStart 	= true
	local isEnd 	= false

	local startSize = self:getNaluStartLength(data) + 1
	offset   = offset   + startSize
	leftover = leftover - startSize

	local nalHeader = data:byte(startSize)
	local isMaker = false

	while (leftover > 0) do
		local size = math.min(kRtpMaxSize, leftover)
		if (size == leftover) then
			isEnd = true
		end

		if (isEnd) then
			isMaker = true
		end	

		-- fu header
		local fu1 = (nalHeader & 0x60) | kFuNaluType
		local fu2 = (nalHeader & 0x1f) 

		if (isStart) then
			fu2 = fu2 | kFuStartBit
		end

		if (isEnd) then
			fu2 = fu2 | kFuEndBit
		end	

		-- packet
		local packet = {}
		table.insert(packet, self:encodeHeader(timestamp, isMaker))
		table.insert(packet, string.pack(">BB", fu1, fu2))
		table.insert(packet, data:sub(offset, offset + size - 1))
		table.insert(list, packet)
		
		-- 
		offset   = offset   + size
		leftover = leftover - size
		isStart  = false
	end

	return list
end

--[[
@param timestamp 时间戳，单位为毫秒 (1/1000)
@param isMaker 指出是否是一帧的最后一个包
]]
function RtpSession:encodeHeader(timestamp, isMaker)
	local rtpHead 	= exports.RTP_PACKET_HEAD or 0x80	-- 16 bits
	local payload 	= (self.payload  or 0) & 0x7F 		-- 0 ~ 6 bit
	local sequence  = (self.sequence or 0) & 0xFFFF 	-- 16 bits
	local rtpSsrc 	= (self.rtpSsrc  or 0x11223344) 	-- 32 bits
	local rtpTime 	= ((timestamp or 0) * 90) & 0xFFFFFFFF 	-- ms to 90kHz

	if (isMaker) then
		payload = payload | 0x80 -- maker flag
	end

	self.sequence = (sequence + 1) & 0xFFFF
	return string.pack(">BBI2I4I4", rtpHead, payload, sequence, rtpSsrc, rtpTime)
end

--[[
把指定的 TS 流编码成 RTP 包
@param packets 包含 TS 包的列表
@param timestamp，单位为毫秒 (1/1000)
@param isMaker 指出是否是一帧的最后一个包
]]
function RtpSession:encodeTS(packets, timestamp, isMaker)
	local rtpPacket = {}
	table.insert(rtpPacket, self:encodeHeader(timestamp, isMaker))
	for k, packet in pairs(packets) do
		table.insert(rtpPacket, packet)
	end

	return rtpPacket
end

function RtpSession:getNaluStartLength(data)
	if (data == nil or type(data) ~= 'string') then
		return 0
	end

	if (data:byte(1) ~= 0x00) then
		return 0

	elseif (data:byte(2) ~= 0x00) then	
		return 0
	end

	if (data:byte(3) == 0x01) then
		return 3

	elseif (data:byte(3) == 0x00) then
		if (data:byte(4) == 0x01) then
			return 4
		end
	end

	return 0
end

-------------------------------------------------------------------------------
-- exports

function exports.newSession()
	return RtpSession:new()
end

return exports
