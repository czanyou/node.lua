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
local utils 	= require('utils')
local core  	= require('core')
local fs    	= require('fs')
local path  	= require('path')
local lwriter   = require('media/wrtier')

local m3u8  	= require('hls/m3u8')

local exports 	= { }

exports.sources 	= {}
exports.basePath 	= '/tmp/live'
exports.baseUrl 	= '/live'

-------------------------------------------------------------------------------
-- Segmenter

local Segmenter = core.Emitter:extend()
exports.Segmenter = Segmenter

function Segmenter:initialize(options)
	options = options or {}

	self._startPts 		= 0
	self._lastPts 		= 0
	self._duration  	= 0
	self._sequence		= 1
	self._segment_fd	= 0
	self._maxDuration	= (options.duration or 3) * 1000000

	self._m3u8Data		= nil
	self.uid 			= options.uid or 'test'

	self.lastSegmenter  = nil

	-- play list
	local playList = m3u8.newList()
	playList:setTargetDuration(1)
	playList:setMediaSequence(1)

	local basePath  = options.basePath or exports.basePath
	local baseUrl   = options.baseUrl  or exports.baseUrl

	self.playList 	= playList
	self._m3u8Data	= playList:toString()
	self.basePath   = path.join(basePath, self.uid)
	self.baseUrl    = path.join(baseUrl,  self.uid)

	-- stream writer
	self.writer 	= lwriter.new()

	fs.mkdirpSync(self.basePath, '0777')
end

function Segmenter:close()
	self:endSegment()

	self._startPts 		= 0
	self._lastPts 		= 0
	self._duration  	= 0
	self._sequence		= 1
	self._segment_fd	= 0
	self._maxDuration	= 3 * 1000000

	self._m3u8Data		= nil
end

function Segmenter:endSegment()
	--console.log('endSegment', self._duration)
	-- last segment
	if (self._segment_fd <= 0) then
		return
	end	

	self.writer:close()

	local duration = self._duration / 1000000
	local pathname = self.baseUrl .. '/' .. self._segment
	--console.log('end', duration, pathname)

	self.playList:addItem(pathname, duration)

	local m3u8file = path.join(self.basePath, 'live.m3u8')
	fs.writeFile(m3u8file, self.playList:toString(), function()
		-- console.log('write m3u8 end');
	end)

	self:emit('segment', pathname, duration)

	self._duration = 0

	-- 
	fs.close(self._segment_fd)
	self._segment_fd = 0

	self.lastSegmenter = path.join(self.basePath, self._segment)
end

function Segmenter:getPlayList(path)
	return self._m3u8Data
end

function Segmenter:newSegment()
	if (self._segment_fd > 0) then
		self:endSegment()
	end

	--local 

	-- next segment
	self._sequence 	 = self._sequence + 1

	local sequence = (self._sequence % 9) + 1
	self._segment 	 = 'segment' .. sequence .. '.ts'

	local filename = path.join(self.basePath, self._segment)
	fs.open(filename, 'w', 438, function(err, fd)
		if (err) then
			return
		end

		self._segment_fd = fd

		self.writer:start(function(packet)
			-- print('packet', #packet)
			if (self._segment_fd > 0) then
				fs.write(self._segment_fd, -1, packet)
			end
		end)
	end)
end

-- @param pts 单位为秒
function Segmenter:push(sampleData, sampleTime, syncPoint)
	if (self._startPts <= 0) then
		self._startPts  = sampleTime
		self._lastPts	= 0
	end
	sampleTime = sampleTime - self._startPts
	self._duration = sampleTime - self._lastPts

	if (syncPoint) then
		if (self._duration >= self._maxDuration) then
			self:newSegment()
			self._lastPts = sampleTime
		end
	end

	if (not self._segment) then
		self:newSegment()
	end

	local flags = 0
	if (syncPoint) then
		flags = flags | lwriter.FLAG_IS_SYNC
	end

	self.writer:write(sampleData, sampleTime, flags)
end

function Segmenter:start()
	
end

function Segmenter:stop()
	self:endSegment()
end

-------------------------------------------------------------------------------
-- exports

function exports.newSegmenter(options)
	return Segmenter:new(options)
end

setmetatable(exports, {
	__call = function(self, ...) 
		return self:newSegmenter(...)
	end
})

return exports

