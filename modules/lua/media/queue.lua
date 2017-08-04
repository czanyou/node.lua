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
local core 	= require('core')
local utils = require('utils')

local meta 		= { }
local exports 	= { meta = meta }

local MAX_QUEUE_SIZE 	= 10
local FLAG_IS_SYNC 		= 0x01
local FLAG_IS_END 		= 0x02

exports.MAX_QUEUE_SIZE 	= MAX_QUEUE_SIZE
exports.FLAG_IS_SYNC 	= FLAG_IS_SYNC
exports.FLAG_IS_END 	= FLAG_IS_END

-------------------------------------------------------------------------------
-- MediaQueue

local MediaQueue = core.Emitter:extend()
exports.MediaQueue = MediaQueue

function MediaQueue:initialize(maxSize)
	self.currentSample	= nil   -- current sample
	self.waitSync  	 	= true	-- wait sync point
	self.maxQueueSize   = maxSize or MAX_QUEUE_SIZE

	self._sampleQueue   = {}	-- sample queue	
end

--[[
当碰到流的同步点
主要对队列长度进行检测，如果长度过长则自动采取丢帧措施，防止队列无限制的增长，
减少内存占用以及加大媒体流延时
]]
function MediaQueue:onSyncPoint()
	if (#self._sampleQueue >= self.maxQueueSize) then
		self._sampleQueue = {}
	end
end

--[[
从队列中取出完整的一帧，如果没有则返回 nil
]]
function MediaQueue:pop()
	if (#self._sampleQueue > 0) then 
		local sample = self._sampleQueue[1]
		table.remove(self._sampleQueue, 1)
		return sample
	end

	return nil
end

--[[
往队列中写媒体数据
@param sampleData 字节数组，媒体数据，暂时只接受 188 字节长的 TS 包
@param sampleTime 整数, 媒体时间戳, 单位为 1 / 1,000,000 秒
@param flags 整数, 媒体数据标记, 具体定义有为 0x01: 同步点(关键帧), 0x02: 帧结束标记
@return 返回 true 表示新增加了完整的一帧，否则表示这一帧数据还没有接收完全.
]]
function MediaQueue:push(sampleData, sampleTime, flags)
	assert(sampleData, 'sampleData is nil')

	-----------------------------------------------------------
	-- sample info

	local isSyncPoint = false
	local isEnd = false
	if (flags) then
		isSyncPoint = ((flags & FLAG_IS_SYNC) ~= 0)
		isEnd  		= ((flags & FLAG_IS_END) ~= 0)
	end

	-----------------------------------------------------------
	-- start a new sample

	local currentSample = self.currentSample
	if (not currentSample) then
		currentSample = {}
		self.currentSample = currentSample

		currentSample.sampleTime = sampleTime or 0
	end

	-----------------------------------------------------------
	-- sync point

	if (isSyncPoint) then
		currentSample.isSyncPoint = true
	end

	-----------------------------------------------------------
	-- sample data	

	table.insert(currentSample, sampleData)

	-----------------------------------------------------------
	-- sample end

	if (isEnd) then

	    -- wait sync point
	    -- 当还没有收到关键帧则丢弃收到的任何帧 (因为非关键帧必须有关键帧参考才能正确解码)
		if (self.waitSync) then
			if (not currentSample.isSyncPoint) then
				self.currentSample = nil
				return
			end

			self.waitSync = false
		end

		-- sync point
		if (currentSample.isSyncPoint) then
			self:onSyncPoint()
		end

		-- push the new sample to the queue
		table.insert(self._sampleQueue, currentSample)
		self.currentSample = nil

		return true
	end
end

-------------------------------------------------------------------------------

function exports.newMediaQueue(...)
	return MediaQueue:new(...)
end

return exports

