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

local meta = { }
meta.name        = "lnode/buffer"
meta.version     = "1.0.1-3"
meta.description = "A mutable buffer for lnode."
meta.tags        = { "lnode", "buffer" }

local core   = require('core')
local lutils = require('lutils')
local utils  = require('utils')

local exports = { meta = meta }

-------------------------------------------------------------------------------

local function _compliment8(value)
    return (value < 0x80) and value or (-0x100 + value)
end

local function _compliment16(value)
    return (value < 0x8000) and value or (-0x10000 + value)
end

local function _compliment32(value)
    return (value < 0x80000000) and value or (-0x100000000 + value)
end


-------------------------------------------------------------------------------
-- Buffer 是一个直接处理二进制数据的类
-- @param size Number 分配一个新的大小是 size 的缓存区. 
-- @param str String 分配一个新的 buffer，其中包含着给定的 str 字符串
-- 

local Buffer = core.Object:extend()
exports.Buffer = Buffer

--[[
    1 <= position <= limit <= length
]]
function Buffer:initialize(param)
    if (type(param) == "number") then
        self.buffer = lutils.new_buffer(param)

        self.buffer:position(1)
        self.buffer:limit(1)  -- 

    elseif (type(param) == "string") then
        self.buffer = lutils.new_buffer(#param)

        self.buffer:put_bytes(1, param, 1, #param)
        self.buffer:position(1)
        self.buffer:limit(#param + 1)

    else
        error("Input must be a string or number")
    end
end

function Buffer.meta:__concat(other)
    return tostring(self) .. tostring(other)
end

function Buffer.meta:__index(key)
    if type(key) == "number" then
        if key < 1 or key > self:length() then error("Index out of bounds") end

        local position = self:position() + key - 1
        return self.buffer:get_byte(position)
    end
    return Buffer[key]
end

function Buffer.meta:__ipairs()
    local index = 1
    return function()
        if index <= self:length() then
            index = index + 1
            return index, self.buffer.get_byte(index)
        end
    end
end

function Buffer.meta:__newindex(key, value)
    if type(key) == "number" then
        if key < 1 or key > self:length() then error("Index out of bounds") end

        local position = self:position() + key - 1
        self.buffer:put_byte(position, value)
        return
    end

    rawset(self, key, value)
end

function Buffer.meta:__tostring()
    return self.buffer:get_bytes(self:position(), self:limit() - self:position())
end

function Buffer:compress()
    if (self:isEmpty()) then
        return
    end

    local size = self:limit() - self:position()
    if (self:position() > 1) and (size > 0) then
        self.buffer:move(1, self:position(), size)

        self:position(1)
        self:limit(self:position() + size)
    end
end

function Buffer:concat(list, totalLength)
    -- TODO:
end

function Buffer:copy(targetBuffer, targetStart, sourceStart, sourceEnd)
    local length = sourceEnd - sourceStart + 1;
    return targetBuffer.buffer:copy(targetStart, self.buffer, sourceStart, length)
end

function Buffer:expand(size)
    if (size == 0) then
        return 0

    elseif (self:limit() + size < self:position()) then
        return 0        

    elseif (self:limit() + size > self:length() + 1) then
        return 0
    end

    self:limit(self:limit() + size)

    if (self:limit() == self:position()) then
        self:position(1)
        self:limit(1)
    end

    return size
end

function Buffer:fill(value, startPos, endPos)
    if (endPos < startPos) then
        return 
    end

    local position = self:position() + startPos - 1
    return self.buffer:fill(value, position, endPos - startPos + 1)
end

function Buffer:inspect()
    local parts = { }
    for i = 1, tonumber(self:length()) do
        parts[i] = bit.tohex(self[i], 2)
    end
    return "<Buffer " .. table.concat(parts, " ") .. ">"
end

function Buffer:isEmpty()
    return self:position() == self:limit()
end

function Buffer:length()
    local buffer = self.buffer
    if (not buffer) then
        return 0
    end

    return buffer:length()
end

function Buffer:limit(limit)
    local buffer = self.buffer
    if (not buffer) then
        return 1
    end

    if (not limit) then
        return buffer:limit() or 1
    end

    if (limit >= self:position()) and (limit <= self:length() + 1) then
        buffer:limit(limit)
    end
end

function Buffer:position(position)
    local buffer = self.buffer
    if (not buffer) then
        return 1
    end

    if (not position) then
        return buffer:position() or 1
    end

    if (position >= 1) and (position <= self:length()) and (position <= self:limit()) then
        buffer:position(position)
    end
end

function Buffer:put(offset, value)
    local position = self:limit() + offset
    return self.buffer:put_byte(position, value)
end

function Buffer:putBytes(data, offset, length)
    local position = self:limit()
    if (not offset) then
        offset = 1
    end

    if (not length) then
        length = #data + 1 - offset
    end

    local ret = self.buffer:put_bytes(position, data, offset, length)
    if (ret == length) then
        self:limit(self:limit() + length)
    end

    return ret
end

function Buffer:read(offset)
    return _compliment8(self[offset])
end

function Buffer:readInt8(offset)
    return _compliment8(self[offset])
end

function Buffer:readInt16BE(offset)
    return _compliment16(self:readUInt16BE(offset))
end

function Buffer:readInt16LE(offset)
    return _compliment16(self:readUInt16LE(offset))
end

function Buffer:readInt32BE(offset)
    return _compliment32(self:readUInt32BE(offset))
end

function Buffer:readInt32LE(offset)
    return _compliment32(self:readUInt32LE(offset))
end

function Buffer:readUInt8(offset)
    return self[offset]
end

function Buffer:readUInt16BE(offset)
    return (self[offset] << 8) + self[offset + 1]
end

function Buffer:readUInt16LE(offset)
    return (self[offset + 1] << 8) + self[offset]
end

function Buffer:readUInt32BE(offset)
    return self[offset] * 0x1000000 +
    (self[offset + 1] << 16) +
    (self[offset + 2] << 8) +
    self[offset + 3]
end

function Buffer:readUInt32LE(offset)
    return self[offset + 3] * 0x1000000 +
    (self[offset + 2] << 16) +
    (self[offset + 1] << 8) +
    self[offset]
end

function Buffer:size()
    return self:limit() - self:position()
end

function Buffer:skip(size)
    if (size == 0) then
        return 0

    elseif (self:position() + size < 1) then
        return 0

    elseif (self:position() + size > self:limit()) then
        return 0
    end

    self:position(self:position() + size)

    if (self:limit() == self:position()) then
        self:position(1)
        self:limit(1)
    end

    return size
end

function Buffer:slice(startPos, endPos)
    -- TODO: 
end

function Buffer:toString(i, j)
    local offset    = i and i or 1
    local position  = self:position() + offset - 1
    local size      = j and (j - i + 1) or (self:limit() - position)
    return self.buffer:get_bytes(position, size)
end

function Buffer:write(data, offset, length, sourceStart)
    local position = self:position()
    if (offset) then
        position = position + offset - 1
    end

    if (not sourceStart) then
        sourceStart = 1
    end

    if (not length) then
        length = #data
    end

    local ret = self.buffer:put_bytes(position, data, sourceStart, length)
    if (ret == length) then
        self:limit(self:limit() + length)
    end
    return ret
end

return exports
