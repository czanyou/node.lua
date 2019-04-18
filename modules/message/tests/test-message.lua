local lmessage 	= require('lmessage')
local thread  	= require('thread')
local uv   		= require('uv')
local tap   	= require('ext/tap')

-- console.log(lmessage)

local main = nil

main = lmessage.new_queue('main', 100, function(...)
	console.log('main message', ...)
	setTimeout(50, function()
		main:stop()
	end)

	local threadQueue, err = lmessage.get_queue('thread')
	threadQueue:send('message from main thread')
	threadQueue:close()

end)

print('main:refs()', main:refs())

-- [[
setTimeout(100, function()
	main:stop()

	print('main:refs()', main:refs())

end)
--]]

-- [[

thread.start(function()
	print("start thread")
	local lmessage = require('lmessage')
	local thread   = require('thread')
	--console.log(lmessage)

	local main, err = lmessage.get_queue('main')

	local threadQueue 
	threadQueue = lmessage.new_queue('thread', 100, function(...)
		console.log('thread message', ...)
		--threadQueue:close()

		print("test")
		--console.log("refs", threadQueue:refs())
	end)

	print('main:refs()', main:refs())

	--console.log('thread', queue, err)
	main:send('message from thread')
	main:close()
	main = nil

	--print('main:refs()', main:refs())
end)

--]]
