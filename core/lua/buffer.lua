--[[

Copyright 2016-2020 The Node.lua Authors. All Rights Reserved.

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
local meta = {
    description = "A mutable buffer for lnode."
}

local core   = require('core')
local lutils = require('lutils')

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

---@class Buffer
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

        self.buffer:position(1)
        self.buffer:limit(#param + 1)
        self.buffer:put_bytes(1, param, 1, #param)

    else
        error("Input must be a string or number")
    end
end

function Buffer.meta:__concat(other)
    --console.log('__concat', tostring(self))
    return tostring(self) .. tostring(other)
end

function Buffer.meta:__index(key)
    if type(key) == "number" then
        if key < 1 or key > self:size() then return nil end
        return self.buffer:get_byte(key)
    end

    return Buffer[key]
end

function Buffer.meta:__ipairs()
    local index = 0
    return function()
        if index < self:size() then
            index = index + 1
            return index, self.buffer.get_byte(index)
        end
    end
end

function Buffer.meta:__newindex(key, value)
    if type(key) == "number" then
        if key < 1 or key > self:size() then error("Index out of bounds") end
        self.buffer:put_byte(key , value)
        return
    end

    rawset(self, key, value)
end

function Buffer.meta:__tostring()
    return self.buffer:get_bytes(1, self:size())
end


function Buffer:compare(target, targetStart, targetEnd, sourceStart, sourceEnd )
    if (target.buffer == nil) then
        return -1

    elseif (self.buffer == nil) then
        return -1
    end

    local ret = target.buffer:compare(targetStart or 0, targetEnd or 0, self.buffer, sourceStart or 0, sourceEnd or 0)
    if (ret < 0) then
        return -1
    elseif (ret > 0) then
        return 1
    else
        return 0
    end
end

function Buffer:compress()
    return self.buffer:compress()
end

function Buffer:copy(target, targetStart, sourceStart, sourceEnd)
    return target.buffer:copy(targetStart or 0, self.buffer, sourceStart or 0, sourceEnd or 0)
end

function Buffer:equals(otherBuffer)
    if (otherBuffer:size() ~= self:size()) then
        return false
    end

    return self:compare(otherBuffer) == 0;
end

function Buffer:expand(size)
    if (size == 0) then
        return 0
    end

    return self.buffer:expand(size)
end

function Buffer:fill(value, offset, endPos)
    if (endPos < offset) then
        return
    end

    if (type(value) == 'string') then
        value = value:byte(1)
    else
        value = tonumber(value)
    end

    --local position = self:position() + offset - 1
    return self.buffer:fill(value or 0, offset, endPos)
end

function Buffer:includes(value, offset)
    return self.buffer:index_of(value, offset) > 0
end

function Buffer:indexOf(value, offset)
   return self.buffer:index_of(value, offset)
end

function Buffer:lastIndexOf(value, offset)
    return self.buffer:last_index_of(value, offset)
end

function Buffer:inspect()
    local parts = { }
    for i = 1, tonumber(self:size()) do
        parts[i] = string.format("%02X", self[i])
    end
    return "<Buffer " .. table.concat(parts, " ") .. ">"
end

function Buffer:isEmpty()
    return (self:size() <= 0)
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

    else
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

    else
        buffer:position(position)
    end
end

function Buffer:put(offset, value)
    return self.buffer:put_byte(offset, value)
end

function Buffer:putBytes(data, offset, length)
    local position = self:size() + 1

    if (not offset) then
        offset = 1
    end

    if (not length) then
        length = #data + 1 - offset
    end

    local ret = self:expand(length)
    if (ret > 0) then
        self.buffer:put_bytes(position, data, offset, length)
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
    return self.buffer:size()
end

function Buffer:skip(size)
    if (size == 0) then
        return 0
    end

    return self.buffer:skip(size)
end

function Buffer:slice(startPos, endPos)
    -- TODO:
end

function Buffer:toString(offset, endPos)
    offset = tonumber(offset) or 1
    if (offset < 1) then
        offset = 1
    end

    endPos = tonumber(endPos) or 0
    if (endPos < 1) then
        endPos = self:size()
    end

    if (endPos < offset) then
        return
    end

    local size = endPos - offset + 1
    --console.log(offset, endPos, size)
    return self.buffer:get_bytes(offset, size)
end

function Buffer:write(data, offset, length, sourceStart)
    if (not sourceStart) then
        sourceStart = 1
    end

    if (not length) then
        length = #data
    end

    return self.buffer:put_bytes(offset, data, sourceStart, length)
end

function Buffer:writeInt8(value, offset)
    return self.buffer:put_byte(offset, value)
end

function Buffer:writeUInt8(value, offset)
    return self.buffer:put_byte(offset, value)
end

function Buffer:writeInt16BE(value, offset)
    self.buffer:put_byte(offset,     value >> 8)
    self.buffer:put_byte(offset + 1, value)
end

function Buffer:writeInt16LE(value, offset)
    self.buffer:put_byte(offset + 1, value >> 8)
    self.buffer:put_byte(offset,     value)
end

function Buffer:writeUInt16BE(value, offset)
    self.buffer:put_byte(offset,     value >> 8)
    self.buffer:put_byte(offset + 1, value)
end

function Buffer:writeUInt16LE(value, offset)
    self.buffer:put_byte(offset + 1, value >> 8)
    self.buffer:put_byte(offset,     value)
end

function Buffer:writeInt32BE(value, offset)
    self.buffer:put_byte(offset,     value >> 24)
    self.buffer:put_byte(offset + 1, value >> 16)
    self.buffer:put_byte(offset + 2, value >> 8)
    self.buffer:put_byte(offset + 3, value)
end

function Buffer:writeInt32LE(value, offset)
    self.buffer:put_byte(offset + 3, value >> 24)
    self.buffer:put_byte(offset + 2, value >> 16)
    self.buffer:put_byte(offset + 1, value >> 8)
    self.buffer:put_byte(offset,     value)
end

function Buffer:writeUInt32BE(value, offset)
    self.buffer:put_byte(offset,     value >> 24)
    self.buffer:put_byte(offset + 1, value >> 16)
    self.buffer:put_byte(offset + 2, value >> 8)
    self.buffer:put_byte(offset + 3, value)
end

function Buffer:writeUInt32LE(value, offset)
    self.buffer:put_byte(offset + 3, value >> 24)
    self.buffer:put_byte(offset + 2, value >> 16)
    self.buffer:put_byte(offset + 1, value >> 8)
    self.buffer:put_byte(offset,     value)
end

---------------------------------------------------------------

-- Allocates a new Buffer of size bytes. If fill is undefined, the Buffer will be zero-filled.
-- size <integer> The desired length of the new Buffer.
-- fill <string> | <Buffer> | <integer> A value to pre-fill the new Buffer with. Default: 0
function Buffer.alloc(size, fill)
    local buffer = Buffer:new(tonumber(size))
    buffer:limit(size + 1)
    buffer:fill(fill, 1, size)
    return buffer
end

-- Allocates a new Buffer using an array of octets.
function Buffer.from(array)
    local buffer = nil
    local arrayType = type(array)
    if (arrayType == 'string') then
        local size = #array

        buffer = Buffer:new(tonumber(size))
        buffer:limit(size + 1)

        for i = 1, size do
            buffer[i] = array:byte(i)
        end

    elseif (arrayType == 'table') then
        local size = Buffer.isBuffer(array) and array:size() or #array

        buffer = Buffer:new(tonumber(size))
        buffer:limit(size + 1)

        for i = 1, size do
            buffer[i] = array[i]
        end
    end

    return buffer
end

function Buffer.concat(list)
    local total = 0
    for _, item in ipairs(list) do
        total = total + item:size()
    end

    local newBuffer = Buffer:new(total)
    for _, item in ipairs(list) do
        newBuffer:putBytes(item:toString())
    end

    return newBuffer
end

function Buffer.isBuffer(obj)
    return core.instanceof(obj, exports.Buffer)
end

return exports
