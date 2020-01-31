local tap = require('ext/tap')
local test = tap.test

test("test thread create", function(expect, uv)
	local delay = 1000
	local before = uv.uptime()
	local thread = uv.new_thread(function(delay)
		require('luv').sleep(delay)
	end, delay)

	uv.thread_join(thread)

	local elapsed = (uv.uptime() - before) * 1000
	--p({ delay = delay, elapsed = elapsed })
	assert(elapsed >= delay, "elapsed should be at least delay ")
end)

test("test thread create with arguments", function(expect, uv)
	local before = uv.uptime()
	local args = { 500, 'string', nil, false, 5, "helloworld" }

	uv.new_thread(function(num,s,null,bool,five,hw)
		assert(type(num) == "number")
		assert(type(s) == "string")
		assert(null == nil)
		assert(bool == false)
		assert(five == 5)
		assert(hw == 'helloworld')
		require('luv').sleep(1000)
	end, table.unpack(args)):join()

	local elapsed = (uv.uptime() - before) * 1000
	assert(elapsed >= 100, "elapsed should be at least delay ")
end)


test("test thread sleep msecs in main thread", function(expect, uv)
	local delay = 1000
	local before = uv.uptime()
	uv.sleep(delay)
	local now = uv.uptime()
	local elapsed = (now - before) * 1000

	p({ delay = delay, elapsed = elapsed })
	assert(elapsed >= delay, "elapsed should be at least delay ")
end)

tap.run()
