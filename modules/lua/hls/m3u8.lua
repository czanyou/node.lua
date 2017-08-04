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
local utils = require('utils')
local core  = require('core')

local exports = { }

-------------------------------------------------------------------------------
-- PlayList used to read and write M3U8 class
-- @event error
-- @event item Called when adding a new segment
-- @event remove Called when deleting one of the oldest segments (live stream only)

local PlayList = core.Emitter:extend()
exports.PlayList = PlayList

function PlayList:initialize()
    self.isEndList      = false
    self.maxSegment     = 3
    self.playItems      = {}
    self.properties     = {}
    self.streamItems    = {}
end

-- Add a slice
-- @param path {String}
-- @param duration {Number}
function PlayList:addItem(path, duration)
    if (not duration) or (not path) then
        return self
    end

    local item = { duration = duration, path = path }
    table.insert(self.playItems, item)

    if (not self.isEndList) then
        while (#self.playItems > self.maxSegment) do
            self:removeItem(1)
        end
    end

    self:setTargetDuration(self:getMaxDuration())

    self:emit('item', item)
    return self
end

function PlayList:get(key)
    return self.properties[key]
end

-- Returns the serial number of the first tile
function PlayList:getMediaSequence()
    return self:get('EXT-X-MEDIA-SEQUENCE')
end

-- Returns the length of the longest fragment in the current list
function PlayList:getMaxDuration()
    local maxDuration = 3.0
    for k, v in ipairs(self.playItems) do
        if (maxDuration < v.duration) then
            maxDuration = v.duration
        end
    end

    return math.floor(maxDuration + 0.5)
end

function PlayList:init()
    -- #EXTM3U
    -- #EXT-X-VERSION: 3
    -- #EXT-X-TARGETDURATION: 8
    -- #EXT-X-MEDIA-SEQUENCE: 2680

    local headers = self.properties
    headers['EXT-X-VERSION']        = 3
    headers['EXT-X-TARGETDURATION'] = 10    -- The maximum duration of each fragment TS
    headers['EXT-X-MEDIA-SEQUENCE'] = 1     -- The serial number of the first TS fragment
end

-- 解析指定的列表
function PlayList:parse(listData)
    if (not listData) then
        return
    end

    local lines = listData:split('\n')

    local playItem = nil
    local streamItem = nil

    for key,line in pairs(lines) do
    	-- console.log(key, line, #line, line:byte(1))

    	if (#line <= 0) then

    	elseif (line:byte(1) == 35) then -- 35: '#'
    		if (line == '#EXTM3U') then
                -- start

    		elseif (line == '#EXT-X-ENDLIST') then
                -- end
                self.isEndList = true
    			break;
    		end

    		local a, offset, tag, value = line:find("^#([^:]+):%s*([^\r\n]+)", 1)
    		--console.log(a, offset, tag, value)

    		if (tag and value) then
    			if (tag == 'EXTINF') then
                    local tokens = value:split(',')
    				playItem = {}
    				playItem.duration = tokens[1] or 0
    				table.insert(self.playItems, playItem)

                elseif (tag == 'EXT-X-STREAM-INF') then
                    streamItem = {}
                    streamItem.attributes = self:parseAttributes(value)
                    table.insert(self.streamItems, streamItem)

                elseif (playItem) then
                    playItem[tag] = self:parseAttributes(value)

                elseif (streamItem) then
                    streamItem[tag] = self:parseAttributes(value)

    			else
    				self.properties[tag] = value
    			end
    		end

        elseif (streamItem) then
            if (not streamItem.path) then
                streamItem.path = line:trim()
            end

    	elseif (playItem) then
    		if (not playItem.path) then
    			playItem.path = line:trim()
    		end
    	end

    end

    return self
end

function PlayList:parseAttributes(value)
    local tokens = value:split(",")

    return tokens
end

-- Removes a slice from the list header
function PlayList:removeItem(index)
    index = index or 1
    if (#self.playItems > 0) then
        local ret = table.remove(self.playItems, index)
        self:setMediaSequence(self:getMediaSequence() + 1)

        self:emit('remove', ret)
    end
end

function PlayList:set(key, value)
    if (key) then
        self.properties[key] = value
    end
end

-- Set whether there is an END flag or not to indicate that it is a real-time stream
function PlayList:setEndList(isEndList)
    self.isEndList = not not isEndList
end

-- Sets the serial number of the first tile
function PlayList:setMediaSequence(sequence)
    self:set('EXT-X-MEDIA-SEQUENCE', sequence)
end

function PlayList:setTargetDuration(duration)
    self:set('EXT-X-TARGETDURATION', duration)
end

function PlayList:toString()
    local endLine = '\r\n'
    local buffer = utils.StringBuffer:new()
    buffer:append('#EXTM3U'):append(endLine) -- M3u file header, must be placed on the first line

    -- headers
    for k, v in pairs(self.properties) do
        if (not tonumber(k)) then
            buffer:append('#'):append(k):append(':'):append(v):append(endLine)
        end
    end

    buffer:append(endLine)

    -- items
    -- extra info，Information about the fragment TS, such as duration, bandwidth, and so on
    for k,item in ipairs(self.playItems) do
        buffer:append('#EXTINF:'):append(item.duration):append(','):append(endLine)
        buffer:append(item.path):append(endLine)
    end

    -- end
    -- #EXT-X-ALLOW-CACHE          Whether to allow the cache
    -- #EXT-X-ENDLIST              M3u8 End of file
    if (self.isEndList) then
        buffer:append('#EXT-X-ENDLIST'):append(endLine)
    end

    buffer:append(endLine)
    return buffer:toString()
end

-------------------------------------------------------------------------------
-- exports

function exports.newList(...)
    local playList = PlayList:new()
	playList:init()
    return playList
end

function exports.parse(...)
    local playList = PlayList:new()
	local ret = playList:parse(...)
    return playList, ret
end

return exports
