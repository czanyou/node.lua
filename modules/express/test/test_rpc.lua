local rpc 	= require('ext/rpc')
local path  = require('path')


local handler = {}

function handler:test(a, b)
	--print(a, b)
	return (a or 1) * (b or 1)
end

function handler:printf(a, b, c, ...)
	print('printf', a, b, c, ...)
end

local server = rpc.server('rpc', handler)

setTimeout(100, function()
	local url = 'rpc' -- "http://127.0.0.1:9001"
	rpc.call(url, 'test', { 10, 12 }, function(err, result)
		console.log(err, result)
	end)

	local client = rpc.bind(url, 'test', 'printf')


	client.test()

	client.test(1)

	client.test(1, 2)
	client.printf(1, 2, 3, function(err, result)

	end)

	client.test(12, 20, function(err, result)
		console.log(err, result)

		server:close()
	end)

end)

