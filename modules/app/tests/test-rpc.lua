local rpc   = require('app/rpc')
local tap    = require('ext/tap')

local handler = {
	test = function( self, arg1, arg2 )
		--console.log('args: ', arg1, arg2)

		assert(arg1 == 'a')
		assert(arg2 == 100)

		return 3.14
	end
}

local test = tap.test

test("Lua Remote Call", function ()
	os.remove('test-rpc')

	local server = rpc.server('test-rpc', handler, function(err, result)
		--console.log(err, result)
	end)

	setTimeout(100, function()
		rpc.call('test-rpc', 'test', {'a', 100}, function(err, result)
			server:close()

			if (err) then
				console.log('error: ', err)
				return
			end

			--console.log('result: ', result)
			assert(result == 3.14)
		end)

	end)

end)

tap.run()

