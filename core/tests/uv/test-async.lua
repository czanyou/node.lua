local tap = require('util/tap')
local uv = require('luv')

local test = tap.test

-- [[

test("test async - pass async between threads", function(expect)
	local before = uv.uptime()
	local async = nil

	local asyncCallback = function (a, b, c)
		console.log('enter async notify callback')
		--console.log(a, b, c)
		assert(a == 'a')
		assert(b == true)
		assert(c == 250)

		uv.close(async)
		async = nil

		console.log('exit async notify callback')
	end

	async = uv.new_async(expect(asyncCallback))
	--console.log('async', async)

	local args = { 500, 'string', nil, false, 5, "helloworld", async }
	local unpack = table.unpack

	local threadCallback = function(num, s, null, bool, five, hw, async)
		local luv = require('luv')
		local init = require('init')

		assert(type(num) == "number")
		assert(type(s) == "string")
		assert(null == nil)
		assert(bool == false)
		assert(five == 5)
		assert(hw == 'helloworld')
		assert(type(async) == 'userdata')
		luv.sleep(1200)

		assert(luv.async_send(async, 'a', true, 250) == 0)

		luv.sleep(200)
		console.log('exit thread')
	end

	local thread = uv.new_thread(threadCallback, unpack(args))
	thread:join()

	local elapsed = (uv.uptime() - before) * 1000
	assert(elapsed >= 1000, "elapsed should be at least delay ")
end)

--]]
