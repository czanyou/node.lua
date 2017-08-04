local fs 	= require('fs')
local path 	= require('path')

local rpc = require('ext/rpc')

local handler = {
	test = function( self, ... )
		console.log('args: ', ...)

		return 3.14
	end
}

local server = rpc.server('test-rpc', handler, function(err, result)
	--console.log(err, result)
end)

