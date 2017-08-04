local tap 	    = require("ext/tap")
local utils     = require('utils')
local assert    = require('assert')
local Buffer    = require('buffer').Buffer

local Writable  = require('stream').Writable
local Readable  = require('stream').Readable

local ReadStream = Readable:extend()

function ReadStream:initialize(options)
	Readable.initialize(self, options)

	--console.log(path)
end

tap(function(test)
    test("test read", function()
    	local stream = ReadStream:new('test')
    	--console.log('state', stream._readableState)

    	stream:on('end', function()
    		console.log('end')
    	end)


		function stream:_read(n)
			self.index = (self.index or 1) + 1
			if (self.index == 10) then
				console.log('_read end', n)
				--console.log('state', self._readableState)
				self:push(nil)
				return
			end

			self:push('10000000000')
		end


    	local ret = stream:read(0)
    	assert(ret == nil)

    	while (true) do
	    	local ret = stream:read()
	    	console.log('read:', ret)

	    	if (not ret) then
	    		break
	    	end
	    end

   end)


   test("test readable flowing", function()
    	local stream = ReadStream:new('test')
    	--console.log('state', stream._readableState)


		function stream:_read(n)
			--console.log('_read', n)

			self.index = (self.index or 1) + 1
			if (self.index == 10) then
				console.log('_read', n)
				--console.log('state', self._readableState)
				self:push(nil)
				return
			end

			local ret = self:push('10000000000')
			if (not ret) then
				console.log('_read', n, ret)
				--console.log('state', self._readableState)
			end
		end

    	stream:on('data', function(data)
    		console.log('data:', data)
    		assert(data)
    	end)

    	stream:on('end', function()
    		console.log('end')
    	end)
    end) 

    test("test readable.push(nil) with flowing", function()
    	local stream = ReadStream:new('test')

    	function stream:_read(n)
    		self.index = (self.index or 0) + 1
			if (self.index == 5) then
				self:push(nil)

				assert(self._readableState.ended)
				assert(not self._readableState.reading)
				--console.log(self._readableState)

				return
			end

			assert(self._readableState.sync)

    		-- body
    		setTimeout(100, function()
    			assert(not self._readableState.sync)
    			assert(self._readableState.reading)
    			self:push('10000000000' .. self.index)
    			console.log('reading', self._readableState.reading)
    			--assert(self._readableState.reading, self.index)
    		end)
    	end


    	setTimeout(200, function()
    		stream:pause()
    	end)

    	setTimeout(500, function()
    		stream:resume()
    	end)

    	stream:on('data', function(data)
    		console.log('data', data)
    		assert(data)
    	end)

    	stream:on('end', function()
    		console.log('end')
    	end)


    	stream:on('pause', function()
    		console.log('pause')
    	end)

    	stream:on('resume', function()
    		console.log('resume')
    	end)    	
    end) 


    test("test readable.push", function()
    	local stream = ReadStream:new('test') 
    	stream:on('error', function(error)
    		console.log('error', error)
    	end)

    	stream:on('end', function()
    		console.log('end')
    	end)

    	stream:on('readable', function()
    		console.log('readable')
    		local ret = stream:read()
    		console.log(ret)
    	end)

    	stream:push(1.0)
    	stream:push('1.0')

    	setTimeout(10, function()
    		stream:push(nil)

    		assert(stream._readableState.ended)
			assert(not stream._readableState.reading)
    	end)
    end)

    test("test readable.push", function()
    	local stream = ReadStream:new({objectMode = true}) 
    	assert(stream._readableState.objectMode)

    	stream:on('error', function(error)
    		console.log('error', error)
    	end)

    	stream:on('end', function()
    		console.log('end')
    	end)

    	stream:on('readable', function()
    		console.log('readable')
    		local ret = stream:read()
    		console.log(ret)
    	end)

    	stream:push(1.0)
    	stream:push('1.0')

    	setTimeout(10, function()
    		stream:push(nil)

    		assert(stream._readableState.ended)
			assert(not stream._readableState.reading)
    	end)

    end)

    test("test readable.push", function()
        local stream = ReadStream:new() 
        local state = stream._readableState
        state.highWaterMark = 1024 * 16

        stream._read = function(self, n)
            stream:push(string.rep('b', 100))
        end

        assert.equal(state.length, 0)
        assert.equal(state.readingMore, false)        
   
        stream:push(string.rep('a', 100))

        assert.equal(state.length, 100)
        assert.equal(state.readingMore, true)

        --console.log(state)
    end)

    --if (1) then return end

    test("test readable._read", function()
        local stream = ReadStream:new() 
        local state = stream._readableState
        state.highWaterMark = 1024 * 16

        stream._read = function(self, n)
            local data = string.rep('a', n)
            self:push(data)
        end

        local ret = stream:read(1024)
        --console.log(ret, state)

        -- 保证读缓存区一直在高水位
        assert.equal(state.length, 1024 * 16 - 1024)

        for i = 1, 100 do
            stream:read(1024)
            assert.ok(state.length >= 1024 * 16)
        end
    end)

    test("test readable._read", function()
        local stream = ReadStream:new() 
        local state = stream._readableState
        state.highWaterMark = 1024 * 16

        stream._read = function(self, n)
            process.nextTick(function()
                self:push(string.rep('a', n))
            end)
        end

        local ret = stream:read(1024)
        console.log(state.length)
        --console.log(ret, state)
        --assert.equal(state.length, 1024 * 16 - 1024)

        process.nextTick(function()
            -- 努力保证读缓存区一直在高水位
            assert.ok(state.length >= 1024 * 16)
            for i = 1, 10 do
                stream:read(1024)

                --console.log(state.length)
                --assert.ok(state.length >= 1024 * 16)
            end
        end)

        setTimeout(10, function()
            --console.log(state.length)
            -- 努力保证读缓存区一直在高水位
            assert.ok(state.length >= 1024 * 16)
        end)
    end)

    test("test readable.readable", function()
        local stream = ReadStream:new() 
        local state = stream._readableState
        state.highWaterMark = 1024 * 16

        stream._read = function(self, n)
            process.nextTick(function()
                self:push(string.rep('a', 100))
            end)
        end

        assert(not state.needReadable)
        assert(not state.readableListening)
        stream:on('readable', function()
            console.log(state.length)
            --assert.ok(state.length >= 1024 * 16)

            -- 在清空缓存区前，不再需要 readable 事件
            assert(not state.needReadable)
            local data = stream:read()

            -- 清空缓存区后，重新需要侦听 readable 事件
            if (state.ended) then
                assert(not state.needReadable)
            else
                assert(state.needReadable)
                stream:push(nil) -- 触发 EOF
            end

            --console.log(state)
        end)

        -- 需要侦听 readable 事件
        assert(state.needReadable)
        assert(state.readableListening)

        setTimeout(10, function()
            console.log('length', state.length)
            -- 努力保证读缓存区一直在高水位
            --assert.ok(state.length >= 1024 * 16)
        end)
    end)

    test("test readable.data & pause", function()
        local stream = ReadStream:new() 
        local state = stream._readableState
        state.highWaterMark = 1024 * 16

        stream._read = function(self, n)
            process.nextTick(function()
                self:push(string.rep('a', 100))
            end)
        end

        local total = 0

        -- 绑定 data 即进入流模式
        stream:on('data', function(data)
            assert(state.flowing)

            total = total + #data
            if (total > 1024 * 16) then
                -- 进入暂停模式
                stream:pause()

                assert(not state.flowing)
            end
        end)

        setTimeout(10, function()
            console.log('length', state.length)
        end)
    end)

    test("test readable.resume", function()
        local stream = ReadStream:new() 
        local state = stream._readableState
        state.highWaterMark = 1024 * 16

        local isPaused = false

        stream._read = function(self, n)
            process.nextTick(function()
                self:push(string.rep('a', 100))
            end)

            if (isPaused) then
                assert(state.length >= 0)
            else
                assert(state.length <= 0)
            end
        end

        assert(not state.flowing)
        assert(not state.resumeScheduled)

        -- 启动流模式，所有数据将会丢失
        stream:resume()
        assert(state.resumeScheduled)

        assert(state.flowing)
        --console.log(state)

        setTimeout(10, function()
            --console.log('length', state.length)

            -- 退出流模式
            stream:pause()
            isPaused = true

            assert(not state.flowing)
        end)
    end)

    test("test readable.unshift", function()
        local stream = ReadStream:new() 
        local state = stream._readableState
        state.highWaterMark = 1024 * 16

        -- 
        stream:push(string.rep('c', 100))
        stream:push(string.rep('d', 100))

        -- 把指定的数据插入到缓存区最前位置
        stream:unshift(string.rep('b', 100))
        assert.equal(state.length, 300)

        -- 重新读出刚刚插入的数据包
        local data = stream:read(100)
        assert.equal(data, string.rep('b', 100))
        assert.equal(state.length, 200)
    end)

    test("test readable.read", function()
        local stream = ReadStream:new() 
        local state = stream._readableState
        state.highWaterMark = 1024 * 16

        stream._read = function(self, n)
            self:push(string.rep('a', n))
        end

        --state.flowing = true

        -- 触发读但不消费数据
        local ret = stream:read(0)
        assert.equal(state.length, 1024 * 16)

        -- 再次触发读但不消费数据
        stream:read(0)
        assert.equal(state.length, 1024 * 16)

        -- 消费一些数据
        stream:read(1024)
        assert.equal(state.length, 1024 * 31)

        --console.log(state)
        assert(not state.needReadable)

        -- 消费所有缓存数据
        local ret = stream:read()
        console.log(#ret)

        assert.equal(state.length, 0)
        assert(state.needReadable)
        assert(state.readingMore)

        ret = stream:read()
        console.log(#ret)


        --console.log(state)
    end)

    test("test readable.read", function()
        local stream = ReadStream:new() 
        local state = stream._readableState
        state.highWaterMark = 1024 * 16

        stream._read = function(self, n)
            self:push(string.rep('a', n))
        end

        --state.flowing = true

        -- 触发读但不消费数据
        for i = 1, 1000 * 1000 do
            stream:read(1024)
        end

        --console.log(state)
    end)

end)

