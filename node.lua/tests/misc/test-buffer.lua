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
local tap 	    = require("ext/tap")
local utils     = require('utils')
local assert    = require('assert')
local Buffer    = require('buffer').Buffer

tap(function(test)
    test("buffer test", function()

        local buf = Buffer:new(4)

        buf[1] = 0xFB
        buf[2] = 0x04
        buf[3] = 0x23
        buf[4] = 0x42
        buf:expand(4)

        assert(buf:readUInt8(1) == 0xFB)
        assert(buf:readUInt8(2) == 0x04)
        assert(buf:readUInt8(3) == 0x23)
        assert(buf:readUInt8(4) == 0x42)

        assert(buf:readInt8(1)  == -0x05)
        assert(buf:readInt8(2)  == 0x04)
        assert(buf:readInt8(3)  == 0x23)
        assert(buf:readInt8(4)  == 0x42)
        
        assert(buf:readUInt16BE(1) == 0xFB04)
        assert(buf:readUInt16LE(1) == 0x04FB)
        assert(buf:readUInt16BE(2) == 0x0423)
        assert(buf:readUInt16LE(2) == 0x2304)
        assert(buf:readUInt16BE(3) == 0x2342)
        assert(buf:readUInt16LE(3) == 0x4223)
        assert(buf:readUInt32BE(1) == 0xFB042342)
        assert(buf:readUInt32LE(1) == 0x422304FB)
        assert(buf:readInt32BE(1)  == -0x04FBDCBE)
        assert(buf:readInt32LE(1)  == 0x422304FB)
    end)

    test("buffer toString test", function()
        local buf2 = Buffer:new('abcd')
        --console.log(buf2, tostring(buf2), 'abcd')
        console.log(buf2, buf2.buffer:position(), buf2.buffer:limit(), buf2.buffer:length())
        --console.log(buf2:toString(1, 2), 'ab')

        assert.equal(tostring(buf2), 'abcd')
        assert(buf2:toString(1, 2) == 'ab')
        assert(buf2:toString(2, 3) == 'bc')
        assert(buf2:toString(3) == 'cd')
        assert(buf2:toString() == 'abcd')
    end)

    test("buffer fill test", function()
        local buf3 = Buffer:new('abcd1234')
        buf3:fill(68, 4, 6)
        assert(buf3:toString() == 'abcDDD34')

        buf3:fill(69, 4, 4)
        assert(buf3:toString() == 'abcEDD34')

        buf3:fill(70, 4, 3)
        assert(buf3:toString() == 'abcEDD34') 
    end)

     test("buffer write test", function()
        local buf3 = Buffer:new(32)
        buf3:fill(68, 1, 8)
        buf3:expand(8)
       
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
        buf:fill(68, 1, 32) 
        buf:expand(4)
        --print(buf:toString())
        assert.equal(buf:toString(), 'DDDD')

        buf:putBytes("1234567890", 1, 4)
        --print(buf:toString())
        assert.equal(buf:toString(), 'DDDD1234')

        buf:putBytes("1234567890", 4, 6)
        --print(buf:toString())
        assert.equal(buf:toString(), 'DDDD1234456789')

        buf:putBytes("1234567890", 6)
        --print(buf:toString())
        assert.equal(buf:toString(), 'DDDD123445678967890')

    end)

    test("buffer copy test", function()
        local buf1 = Buffer:new(32)
        local buf2 = Buffer:new(32)

        buf1:fill(68, 1, 32)   
        buf1:fill(70, 8, 32) 
        buf1:expand(32)

        buf2:fill(69, 1, 32)  
        buf2:expand(32)

        local ret = buf1:copy(buf2, 3, 4, 11)
        assert.equal(ret, 8)
        --print('ret', ret)

        ret = buf1:copy(buf2, 1, 1, 34)
        assert.equal(ret, 0)
        --print('ret', ret) -- -1

        --print(buf1:toString())
        --print(buf2:toString())

        assert.equal(buf1:toString(), 'DDDDDDDFFFFFFFFFFFFFFFFFFFFFFFFF')
        assert.equal(buf2:toString(), 'EEDDDDFFFFEEEEEEEEEEEEEEEEEEEEEE')
    end)

    test("buffer compress test", function()
        local buf = Buffer:new(32)

        assert.equal(buf:limit(), 1)
        assert.equal(buf:position(), 1)

        buf:fill(68, 1, 32)   
        buf:fill(69, 9, 32) 

        buf:expand(32)
        buf:skip(4)

        assert.equal(buf:limit(), 33)
        assert.equal(buf:position(), 5)

        buf:compress()
        buf:compress()

        assert.equal(buf:limit(), 29)
        assert.equal(buf:position(), 1)

        assert.equal(buf:toString(), 'DDDDEEEEEEEEEEEEEEEEEEEEEEEE')
        --print(buf:toString())
    end)
end)
