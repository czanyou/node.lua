local fs 	= require('fs')
local path 	= require('path')

local rpc = require('ext/rpc')

rpc.call('test-rpc', 'test', {'a', 100}, function(err, result)
	if (err) then
		console.log('error: ', err) 
		return
	end

	console.log('result: ', result)
end)
