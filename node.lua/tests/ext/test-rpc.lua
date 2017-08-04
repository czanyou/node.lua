local fs 	= require('fs')
local path 	= require('path')

local rpc = require('ext/rpc')

local handler = {
	test = function( self, ... )
		console.log('args: ', ...)

		return 3.14
	end
	
}

return require('ext/tap')(function (test)

	test("Lua Package Manager Help", function (print, p, expect, uv)
		os.remove('test-rpc')
		
		local server = rpc.server('test-rpc', handler, function(err, result)
			--console.log(err, result)
		end)

		setTimeout(100, function()
			rpc.call('test-rpc', 'test', {'a', 100}, function(err, result)
				if (err) then
					console.log('error: ', err) 
					server:close()
					return
				end

				console.log('result: ', result)
				server:close()
			end)

		end)

	end)
end)
