local tap 	    = require("ext/tap")
local utils     = require('utils')
local assert    = require('assert')
local Buffer    = require('buffer').Buffer

local Writable  = require('stream').Writable
local Readable  = require('stream').Readable


tap(function(test)
   	test("test write", function()

   		local stream = Writable:new()

   		local ret = stream:write('test', function()
   			--console.log('write')
   		end)

         assert.equal(ret,    true)

   		stream:close()

         -- 在流关闭后继续发送数据
    	   local ret = stream:write('test', function()
   			--console.log('write')
   		end)

         assert.equal(ret,    false)
   	end)

      test("test write with cork", function()
         local stream = Writable:new()

         function stream._write(self, chunk, callback)
             process.nextTick(callback)
         end

         stream:cork()

         local state = stream._writableState
         state.highWaterMark = 1024 * 16

         for i = 1, 15 do
            local data = string.rep('a', 1024)
            local ret = stream:write(data)
            assert.equal(ret,          true)
         end

         -- 所有数据都会被缓存在队列中
         assert.equal(state.corked,    1)
         assert.equal(state.needDrain, false)
         assert.equal(state.pendingCallbacks, 15)
         assert.equal(state.writing,   false)
         assert.equal(state.writelen,  0)
         assert.equal(state.length,    1024 *15)

         -- 一直到超过高水位
         local data = string.rep('a',  1024)
         local ret = stream:write(data)
         assert.equal(state.needDrain, true)
         assert.equal(ret,             false)

         stream:uncork()
         --console.log(state)

         -- 开始依次发送
         assert.equal(state.corked,    0)
         assert.equal(state.needDrain, true)
         assert.equal(state.pendingCallbacks, 16)
         assert.equal(state.writing,   true)
         assert.equal(state.writelen,  1024)
         assert.equal(state.length,    1024 *16)

         stream:close(function(err)
            console.log('on close')
            -- console.log(state)
            -- 全部发送完成
            assert.equal(state.finished,     true)
            assert.equal(state.prefinished,  true)
            assert.equal(state.length,       0)
            assert.equal(state.pendingCallbacks, 0)
         end)
       
         -- 马上关闭这个流，但所有缓存的数据会继续发送
         assert.equal(state.pendingCallbacks, 16)
         assert.equal(state.writing,   true)
         assert.equal(state.writelen,  1024)
         assert.equal(state.length,    1024 *16)
         assert.equal(state.ended,     true)
         assert.equal(state.finished,  false)
      
      end)


      test("test write2", function()
         local stream = Writable:new()
         local writeCallback = nil

         function stream._write(self, chunk, callback)
             writeCallback = callback
         end

         local state = stream._writableState
         state.highWaterMark = 1024 * 16

         local data = string.rep('a', 1024)
         stream:write(data)
         
         -- 第一个数据将直接通过 _write 发送
         assert.equal(state.corked,    0)
         assert.equal(state.needDrain, false)
         assert.equal(state.pendingCallbacks, 1)
         assert.equal(state.writing,   true)
         assert.equal(state.writelen,  1024)
         assert.equal(state.length,    1024)
         assert.equal(state.writePos,  1)

         local data = string.rep('a', 1024 * 2)
         stream:write(data)

         -- 第二个数据包会缓存到发送队列中
         assert.equal(state.needDrain, false)
         assert.equal(state.pendingCallbacks, 2)
         assert.equal(state.writing,   true)
         assert.equal(state.writelen,  1024)
         assert.equal(state.length,    1024 * 3)
         assert.equal(state.readPos,   1)
         assert.equal(state.writePos,  2)

         writeCallback()

         -- 前一个数据包发送完成后，下一数据会从缓存中提取并发送
         assert.equal(state.needDrain, false)
         assert.equal(state.pendingCallbacks, 1)
         assert.equal(state.writing,   true)
         assert.equal(state.writelen,  1024 * 2)
         assert.equal(state.length,    1024 * 2)
         assert.equal(state.readPos,   1)
         assert.equal(state.writePos,  1)

         writeCallback()

         -- 发送完毕
         assert.equal(state.needDrain, false)
         assert.equal(state.pendingCallbacks, 0)
         assert.equal(state.writing,   false)
         assert.equal(state.writelen,  0)
         assert.equal(state.length,    0)
         assert.equal(state.readPos,   1)
         assert.equal(state.writePos,  1)

         --console.log(state)
      end)

      test("test write drain", function()
         local stream = Writable:new()

         function stream._write(self, chunk, callback)
             process.nextTick(callback)
         end

         local state = stream._writableState
         state.highWaterMark = 1024 * 16

         stream:on('drain', function()
            --console.log(state)
            console.log('on drain')

            -- 当所有缓存的数据被排空时，会得到 drain 事件
            assert.equal(state.needDrain, false)
            assert.equal(state.pendingCallbacks, 0)
            assert.equal(state.writing,   false)
            assert.equal(state.writelen,  0)
            assert.equal(state.length,    0)
            assert.equal(state.writePos,  1)  
         end)

         -- 发送数据一直到超过高水位
         for i = 1, 16 do
            local data = string.rep('a', 1024)
            stream:write(data)
         end
      end)

      test("test write _writev", function()
         local stream = Writable:new()

         local writeCallback = nil

         function stream._writev(self, chunk, callback)
             writeCallback = callback
         end

         function stream._write(self, chunk, callback)
             writeCallback = callback
         end         

         local state = stream._writableState
         state.highWaterMark = 1024 * 16

         local count = 0

         -- 发送数据一直到超过高水位
         for i = 1, 16 do
            local data = string.rep('a', 1024)
            stream:write(data, function()
               count = count + 1
            end)
         end

         --console.log(state)
         -- 第一包通过 _write 发送
         assert.equal(state.needDrain, true)
         assert.equal(state.pendingCallbacks, 16)
         assert.equal(state.writing,   true)
         assert.equal(state.writelen,  1024)
         assert.equal(state.length,    1024 * 16)
         assert.equal(state.writePos,  16)  
         assert.equal(state.readPos,   1)  

         writeCallback()

         -- 剩下的包一次性通过 _writev 发送
         assert.equal(state.needDrain, true)
         assert.equal(state.pendingCallbacks, 16)
         assert.equal(state.writing,   true)
         assert.equal(state.writelen,  1024 * 15)
         assert.equal(state.length,    1024 * 15)
         assert.equal(state.writePos,  1)  
         assert.equal(state.readPos,   1)  
         assert.equal(count,           1) 

         writeCallback()

         -- 全部发送完毕
         assert.equal(state.needDrain, false)
         assert.equal(state.pendingCallbacks, 0)
         assert.equal(state.writing,   false)
         assert.equal(state.writelen,  0)
         assert.equal(state.length,    0)
         assert.equal(state.writePos,  1)  
         assert.equal(count,           16)      
         --console.log(state)
      end)


--[[
      test("test write2", function()
         local stream = Writable:new()

         function stream._write(self, chunk, callback)
             process.nextTick(callback)
         end

         for i = 1, 200000 do
            local data = string.rep('a', 1024)
            stream:write(data)
         end

      end)
--]]
--[[
      test("test write3", function()
         local stream = Writable:new()

         function stream._write(self, chunk, callback)
             process.nextTick(callback)
         end

         local index = 1
         
         stream:on('drain', function()
            while (index < 200000) do
               index = index + 1
               local data = string.rep('a', 1024)
            stream:write(data)
            end
         end)

         while (index < 200000) do
            index = index + 1
            local data = string.rep('a', 102)
            stream:write(data)
         end

      end)    
--]]
end)

