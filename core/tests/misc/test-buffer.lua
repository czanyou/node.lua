--[[

Copyright 2014 The Luvit Authors. All Rights Reserved.

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
local tap 	    = require('ext/tap')
local assert    = require('assert')
local core      = require('core')
local buffer    = require('buffer')

local Buffer    = buffer.Buffer

local test = tap.test

test("buffer test alloc", function()
	-- without fill
	local buf = Buffer.alloc(5)
	assert.equal(buf:length(), 5)
	assert.equal(buf:size(), 5)
	assert.equal(buf:read(1), 0)
	assert.equal(buf:read(5), 0)

	-- with fill
	local buf = Buffer.alloc(5, 'a')
	assert.equal(buf:length(), 5)
	assert.equal(buf:size(), 5)
	assert.equal(buf:read(1), 0x61)
	assert.equal(buf:read(5), 0x61)

	-- _index
	assert.equal(buf[1], 0x61)
	assert.equal(buf[5], 0x61)

	-- _newindex
	buf[5] = 0x62
	assert.equal(buf[5], 0x62)
end)

test("buffer test new", function()
	-- new
	local text = "abcd1234"
	local buf = Buffer:new(text)

	assert.equal(buf:toString(), text)
	console.log(buf)
end)

test("buffer test from", function()

	-- from array
	local buf = Buffer.from({1, -2, 55, 78})
	assert.equal(buf[1], 1)
	assert.equal(buf[2], 254)
	assert.equal(buf[3], 55)
	assert.equal(buf[4], 78)
	assert.equal(buf:size(), 4)

	-- from string
	local buf = Buffer.from('abcd')
	assert.equal(buf[1], 0x61)
	assert.equal(buf[2], 0x62)
	assert.equal(buf[3], 0x63)
	assert.equal(buf[4], 0x64)
	assert.equal(buf:size(), 4)
	--console.log(buf:inspect())

	local abcd = Buffer.from('abcd')
	local buf = Buffer.from(abcd)
	assert.equal(buf[1], 0x61)
	assert.equal(buf[2], 0x62)
	assert.equal(buf[3], 0x63)
	assert.equal(buf[4], 0x64)
	assert.equal(buf:size(), 4)   
end)

test("buffer test read/write 8", function()
	-- read
	local buf = Buffer.from({1, -2, 3, 4})
	assert.equal(buf:readInt8 (1), 1)
	assert.equal(buf:readUInt8(1), 1)
	assert.equal(buf:readInt8 (2), -2)
	assert.equal(buf:readUInt8(2), 254)

	-- write
	buf:writeInt8(-3, 3)
	assert.equal(buf:readInt8 (3), -3)
	assert.equal(buf:readUInt8(3), 253)  

	-- write
	buf:writeUInt8(0x8F, 4)
	assert.equal(buf:readInt8 (4), -113)
	assert.equal(buf:readUInt8(4), 256 - 113)               
end)

test("buffer test read/write 16", function()
	local buf = Buffer.from({1, 2, 3, 4})

	-- write BE
	buf:writeInt16BE(0x1082, 1);
	assert.equal(buf:readUInt8(1), 0x10)
	assert.equal(buf:readUInt8(2), 0x82)
	assert.equal(buf:readInt16BE(1), 0x1082)

	-- write LE
	buf:writeInt16LE(0x1082, 1);
	assert.equal(buf:readUInt8(2), 0x10)
	assert.equal(buf:readUInt8(1), 0x82)
	assert.equal(buf:readInt16LE(1), 0x1082)

	-- write BE
	buf:writeUInt16BE(0x8F02, 1);
	assert.equal(buf:readUInt8(1), 0x8F)
	assert.equal(buf:readUInt8(2), 0x02)  
	assert.equal(buf:readUInt16BE(1), 0x8F02)

	-- write LE
	buf:writeUInt16LE(0x8F02, 1);
	assert.equal(buf:readUInt8(2), 0x8F)
	assert.equal(buf:readUInt8(1), 0x02)
	assert.equal(buf:readUInt16LE(1), 0x8F02)
end)

test("buffer test read/write 32", function()
	local buf = Buffer.from({1, -2, 3, 4})

	-- write BE
	buf:writeInt32BE(0x10028304, 1);
	assert.equal(buf:readUInt8(1), 0x10)
	assert.equal(buf:readUInt8(2), 0x02)
	assert.equal(buf:readUInt8(3), 0x83)
	assert.equal(buf:readUInt8(4), 0x04)
	assert.equal(buf:readInt32BE(1), 0x10028304)

	-- write LE
	buf:writeInt32LE(0x10020304, 1);
	assert.equal(buf:readInt8(4), 0x10)
	assert.equal(buf:readInt8(3), 0x02)
	assert.equal(buf:readInt8(2), 0x03)
	assert.equal(buf:readInt8(1), 0x04)
	assert.equal(buf:readInt32LE(1), 0x10020304)

	-- write BE
	buf:writeUInt32BE(0x8F020304, 1);
	assert.equal(buf:readUInt8(1), 0x8F)
	assert.equal(buf:readUInt8(2), 0x02)  
	assert.equal(buf:readUInt8(3), 0x03)
	assert.equal(buf:readUInt8(4), 0x04)
	assert.equal(buf:readUInt32BE(1), 0x8F020304)

	-- write LE
	buf:writeUInt32LE(0x8F020304, 1);
	assert.equal(buf:readUInt8(4), 0x8F)
	assert.equal(buf:readUInt8(3), 0x02)
	assert.equal(buf:readUInt8(2), 0x03)
	assert.equal(buf:readUInt8(1), 0x04)
	assert.equal(buf:readUInt32LE(1), 0x8F020304)
end)

test("buffer test", function()

	local buf = Buffer:new(4)
	buf:expand(4)
	buf[1] = 0xFB
	buf[2] = 0x04
	buf[3] = 0x23
	buf[4] = 0x42
	
	-- read 8
	assert(buf:readUInt8(1) == 0xFB)
	assert(buf:readUInt8(2) == 0x04)
	assert(buf:readUInt8(3) == 0x23)
	assert(buf:readUInt8(4) == 0x42)

	assert(buf:readInt8(1)  == -0x05)
	assert(buf:readInt8(2)  == 0x04)
	assert(buf:readInt8(3)  == 0x23)
	assert(buf:readInt8(4)  == 0x42)
	
	-- read 16
	assert(buf:readUInt16BE(1) == 0xFB04)
	assert(buf:readUInt16LE(1) == 0x04FB)
	assert(buf:readUInt16BE(2) == 0x0423)
	assert(buf:readUInt16LE(2) == 0x2304)
	assert(buf:readUInt16BE(3) == 0x2342)
	assert(buf:readUInt16LE(3) == 0x4223)

	-- read 32
	assert(buf:readUInt32BE(1) == 0xFB042342)
	assert(buf:readUInt32LE(1) == 0x422304FB)
	assert(buf:readInt32BE(1)  == -0x04FBDCBE)
	assert(buf:readInt32LE(1)  == 0x422304FB)
end)

test("buffer compare test", function()
	-- abcd == abcd
	local buf2 = Buffer:new('abcd')
	local buf1 = Buffer:new('abcd')
	assert.equal(buf1:compare(buf2), 0)

	-- bcdeg > abcd
	local buf1 = Buffer:new('bcdeg')
	local buf2 = Buffer:new('abcd')
	assert.equal(buf1:compare(buf2), -1)

	-- bcdeg < cdeffgg
	local buf1 = Buffer:new('bcdeg')
	local buf2 = Buffer:new('cdeffgg')
	assert.equal(buf1:compare(buf2), 1)

	-- abcd == abcde
	local buf2 = Buffer:new('abcd')
	local buf1 = Buffer:new('abcde')
	assert.equal(buf1:compare(buf2), 0)      

	-- abcde == abcd
	local buf2 = Buffer:new('abcde')
	local buf1 = Buffer:new('abcd')
	assert.equal(buf1:compare(buf2), 0)     
end)

test("buffer equals test", function()
	-- abcd == abcd
	local buf2 = Buffer:new('abcd')
	local buf1 = Buffer:new('abcd')
	assert.equal(buf1:equals(buf2), true)

	-- abcd ~= abcde
	local buf1 = Buffer:new('abcd')
	local buf2 = Buffer:new('abcde')
	assert.equal(buf1:equals(buf2), false)

	-- abcde ~= abcd
	local buf1 = Buffer:new('abcde')
	local buf2 = Buffer:new('abcd')
	assert.equal(buf1:equals(buf2), false)
end)

test("buffer toString test", function()
	local buf2 = Buffer:new('abcd')
	assert.equal(tostring(buf2), 'abcd')
	assert(buf2:toString(1, 2) == 'ab')
	assert(buf2:toString(2, 3) == 'bc')
	assert(buf2:toString(3) == 'cd')
	assert(buf2:toString() == 'abcd')
end)

test("buffer fill test", function()
	local buf3 = Buffer:new('abcd1234')
	assert.equal(buf3:toString(), 'abcd1234')

	buf3:fill(68, 4, 6)
	assert.equal(buf3:toString(), 'abcDDD34')

	buf3:fill(69, 4, 4)
	assert(buf3:toString() == 'abcEDD34')

	buf3:fill(70, 4, 3)
	assert(buf3:toString() == 'abcEDD34')
end)

	test("buffer skip/expand test", function()
	local buf3 = Buffer:new(32)

	buf3:expand(8)
	buf3:fill(68, 1, 8)
	
	--console.log('buf3', buf3, buf3:toString())
	assert(buf3:toString() == 'DDDDDDDD')

	buf3:skip(4)
	assert(buf3:toString() == 'DDDD')

	buf3:skip(5)
	assert(buf3:toString() == 'DDDD')

	buf3:skip(4)
	--
	--print(buf3:position(), buf3:limit())
	assert(buf3:toString() == nil)
	assert(buf3:position() == 1)
	--print(buf3:position(), buf3:limit(), buf3.length)

	buf3:expand(32)
	--print(buf3:position(), buf3:limit())
	buf3:fill(68, 1, 32)   
	buf3:skip(24)
	assert(buf3:limit() == 33)
	assert(buf3:toString() == 'DDDDDDDD')

	buf3:expand(1)
	assert(buf3:limit() == 33)
	--print(buf3:toString())

end) 

test("buffer position test", function()
	local buf = Buffer:new(32)
	buf:limit(buf:length() + 1)
	assert(buf:position() == 1)

	buf:position(8)
	assert(buf:position() == 8)

	buf:position(32)
	assert(buf:position() == 32)

	buf:position(33)
	assert(buf:position() == 32)       
end)  

test("buffer limit test", function()
	local buf = Buffer:new(32)
	assert(buf:limit() == 1)

	buf:limit(8)
	assert(buf:limit() == 8)

	buf:limit(32)
	assert(buf:limit() == 32)

	buf:limit(33)
	assert(buf:limit() == 33)

	buf:limit(34)
	assert(buf:limit() == 33)
end)

test("buffer put_bytes test", function()
	local buf = Buffer:new(32)
	assert(buf:limit() == 1)
	
	buf:expand(4)
	buf:fill(68, 1, 4)
	assert.equal(buf:toString(), 'DDDD')

	buf:putBytes("1234567890", 1, 4)
	assert.equal(buf:toString(), 'DDDD1234')

	buf:putBytes("1234567890", 4, 6)
	assert.equal(buf:toString(), 'DDDD1234456789')

	buf:putBytes("1234567890", 6)
	assert.equal(buf:toString(), 'DDDD123445678967890')

end)

test("buffer copy test", function()
	local buf1 = Buffer:new(32)
	local buf2 = Buffer:new(32)

	buf1:expand(16)
	buf1:fill(68, 1, 16)    -- ABCDEFGHIJKLMNOP
	for i = 1,16 do
		buf1[i] = 64 + i
	end

	buf2:expand(16)         -- EEEEEEEEEEEEEEEE
	buf2:fill(69, 1, 16)  

	local ret = buf1:copy(buf2, 3, 4, 11) -- EEDDDDDDDDEEEEEE
	assert.equal(ret, 8) -- 11 - 4 + 1
	assert.equal(buf2:toString(), 'EEDEFGHIJKEEEEEE')

	local ret = buf1:copy(buf2, 4, 4) -- EEDDEFGHIJKLMNOP
	assert.equal(ret, 13) -- 16 - 4 + 1
	assert.equal(buf2:toString(), 'EEDDEFGHIJKLMNOP')

	local ret = buf1:copy(buf2, 1) -- ABCDEFGHIJKLMNOP
	assert.equal(ret, 16) -- 16 - 1 + 1
	assert.equal(buf2:toString(), 'ABCDEFGHIJKLMNOP')

	local ret = buf1:copy(buf2) -- ABCDEFGHIJKLMNOP
	assert.equal(ret, 16) -- 16 - 1 + 1
	assert.equal(buf2:toString(), 'ABCDEFGHIJKLMNOP')

end)

test("buffer compress test", function()
	local buf = Buffer:new(32)
	assert.equal(buf:limit(), 1)
	assert.equal(buf:position(), 1)

	-- fill 32
	buf:expand(32)
	assert.equal(buf:limit(), 33)
	buf:fill(68, 1, 32)   
	buf:fill(69, 9, 32)
	assert.equal(buf:toString(), 'DDDDDDDDEEEEEEEEEEEEEEEEEEEEEEEE')

	-- skip 4
	buf:skip(4)
	assert.equal(buf:limit(), 33)
	assert.equal(buf:position(), 5)
	assert.equal(buf:size(), 28)
	assert.equal(buf:toString(), 'DDDDEEEEEEEEEEEEEEEEEEEEEEEE')

	-- compress
	buf:compress()
	buf:compress()
	assert.equal(buf:limit(), 29)
	assert.equal(buf:position(), 1)
	assert.equal(buf:size(), 28)
	assert.equal(buf:toString(), 'DDDDEEEEEEEEEEEEEEEEEEEEEEEE')
end)


test("buffer test isBuffer", function()
	local buf = buffer.Buffer:new('abcd')
	assert(Buffer.isBuffer(buf))

	assert(not Buffer.isBuffer('aaa'))
	assert(Buffer.isBuffer(Buffer:new(1)))
	assert(not Buffer.isBuffer(core.Object:new(1)))        

	assert(core.instanceof(buf, buffer.Buffer))
	assert(core.instanceof(buf, core.Object))
end)

test("buffer test concat", function()
	local buf1 = Buffer.from('abcd')
	local buf2 = Buffer.from('1234')
	
	local buf = buf1 .. buf2
	console.log(buf)

	local buf = buf1 .. "5678"
	console.log(buf)

	local buf = 'ABCD' .. buf2
	console.log(buf)        
end)

test("buffer test concat", function()
	local buf1 = Buffer.from('abcd')
	local buf2 = Buffer.from('1234')
	
	assert.equal(Buffer.compare(buf1, buf2), -1)
	assert.equal(Buffer.compare(buf1, "5678"), -1)
	assert.equal(Buffer.compare('ABCD', buf2), -1)

	assert.equal(Buffer.compare(Buffer.from('abcd'), Buffer.from('abcd')), 0)
	assert.equal(Buffer.compare(Buffer.from('hijk'), Buffer.from('abcd')),-1)
	assert.equal(Buffer.compare(Buffer.from('abcd'), Buffer.from('hijk')), 1)               
end)

test("buffer test ipairs", function()
	local buf1 = Buffer.from('abcd')
	
	for index,value in ipairs(buf1) do
		console.log(index, value)
	end
end)    

test("buffer test concat", function()
	local buf1 = Buffer.from('abcd')
	local buf2 = Buffer.from('1234')

	local buf = Buffer.concat({buf1, buf2})
	print(buf:inspect(), buf:size(), buf:length())

	assert.equal(buf:toString(), "abcd1234")
end)

test("buffer test indexOf", function()
	local buf1 = Buffer.from('abcdefgbcdefg')
	local buf2 = Buffer.from('cde')

	assert.equal(buf1:indexOf('cde'), 3)
	assert.equal(buf1:indexOf('abc'), 1)
	assert.equal(buf1:indexOf('123'), -1)
end)

test("buffer test lastIndexOf", function()
	local buf1 = Buffer.from('abcdefgbcdefg')
	local buf2 = Buffer.from('cde')

	assert.equal(buf1:lastIndexOf('cde'), 9)
	assert.equal(buf1:lastIndexOf('abc'), 1)
	assert.equal(buf1:lastIndexOf('123'), -1)
end)    

test("buffer test includes", function()
	local buf1 = Buffer.from('abcdefg')
	local buf2 = Buffer.from('cde')

	assert.equal(buf1:includes('cde'), true)
	assert.equal(buf1:includes('abc'), true)
	assert.equal(buf1:includes('123'), false)
end)

tap.run()
